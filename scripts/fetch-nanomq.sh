#!/bin/bash
# Fetch the nanomq checkout the examples build against.
#
# The examples compile the NanoMQ broker core and the NanoNNG fork straight out
# of a nanomq checkout: nng is nanomq's submodule, not a separate dependency.
# This script clones nanomq into extern/nanomq (git-ignored) and checks out the
# revision pinned in nanomq.ref, so a fresh clone of this repository builds the
# same nanomq revision everywhere.
#
# Usage: scripts/fetch-nanomq.sh [--ref REF] [--repo URL] [--dir DIR] [--force]
#
#   --ref REF     ref to check out (default: REF in nanomq.ref)
#   --repo URL    nanomq remote  (default: REPO in nanomq.ref)
#   --dir DIR     checkout target (default: <repo>/extern/nanomq)
#   --force       re-clone even if DIR already holds a checkout
#
# An existing checkout is updated to the requested ref; local modifications are
# left alone and git refuses the checkout if they conflict.  To build against a
# checkout of your own instead (a worktree where you edited the nng sources,
# say), skip this script and pass -DNANOMQ_ROOT=/path/to/nanomq to west build.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
ref_file=$repo/nanomq.ref

# Defaults come from nanomq.ref: REPO=<url>, REF=<git ref>.
if [ ! -f "$ref_file" ]; then
    echo "fetch-nanomq.sh: $ref_file is missing" >&2
    exit 1
fi
repo_url=$(sed -n 's/^REPO=//p' "$ref_file" | tail -1)
ref=$(sed -n 's/^REF=//p' "$ref_file" | tail -1)
if [ -z "$repo_url" ] || [ -z "$ref" ]; then
    echo "fetch-nanomq.sh: $ref_file must define REPO=<url> and REF=<ref>" >&2
    exit 1
fi
dir=$repo/extern/nanomq
force=0

while [ $# -gt 0 ]; do
    case "$1" in
        --ref)   ref=$2; shift 2 ;;
        --repo)  repo_url=$2; shift 2 ;;
        --dir)   dir=$2; shift 2 ;;
        --force) force=1; shift ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "fetch-nanomq.sh: unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [ "$force" = 1 ] && [ -e "$dir" ]; then
    echo "+ removing existing $dir"
    rm -rf "$dir"
fi

if [ ! -d "$dir/.git" ]; then
    echo "+ git clone $repo_url $dir"
    mkdir -p "$(dirname "$dir")"
    git clone --no-checkout "$repo_url" "$dir"
    git -C "$dir" remote set-url origin "$repo_url"
else
    echo "+ using existing checkout $dir"
    git -C "$dir" remote set-url origin "$repo_url"
fi

echo "+ git fetch origin"
git -C "$dir" fetch --no-tags origin

# The pinned REF is a commit, so it is not necessarily reachable as a ref name;
# fetch it explicitly when the plain fetch did not bring it in.
if ! git -C "$dir" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
    echo "+ git fetch origin $ref"
    git -C "$dir" fetch --no-tags origin "$ref"
fi

echo "+ git checkout $ref"
git -C "$dir" checkout --detach "$ref"

# nng is nanomq's submodule and carries the Zephyr platform layer the examples
# compile, so it is the only one that has to be there.  The others are for
# nanomq features the examples switch off (l8w8jwt for TLS, nftp-codec for the
# CLI) or that nng itself keeps optional (msquic for QUIC, a large clone).
echo "+ git submodule update --init nng"
git -C "$dir" submodule update --init nng

echo
echo "nanomq $(git -C "$dir" describe --always --dirty) at $dir"
echo "nng    $(git -C "$dir/nng" describe --always --dirty 2>/dev/null || echo 'missing')"
echo
echo "Build with:  west build -b <board> examples/<example>"
