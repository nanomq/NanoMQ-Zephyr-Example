# The nanomq dependency is pinned to a commit, not a branch

The examples compile the NanoMQ broker core and the NanoNNG fork out of a
nanomq checkout. Following a branch there — `zephyr-rtos`, the branch the port
is published on — would mean the same example commit builds different code from
one day to the next, and can stop building without a change here. The board
bring-up records in nanomq's tutorials and in the example READMEs name the
revision they were taken with, which only means something if the revision is
written down.

`nanomq.ref` records it: REF (the nanomq commit), NNG (the nng submodule commit
REF resolves to) and VERIFIED (the date the pair passed the functional suite).
`scripts/fetch-nanomq.sh` reads REPO and REF from that file, clones nanomq into
`extern/nanomq` and checks out the commit, submodules included. The current
pair is nanomq `c8507485` with nng `98cd115e`, verified 2026-10-13.

## Considered Options

- **Track the `zephyr-rtos` branch** — always the newest port work, no bump
  commits here. Rejected: reproducibility, and a nanomq change would be able to
  break the examples' build without any commit in this repository.
- **Track a nanomq tag** — a published, meaningful name. Rejected: the Zephyr
  port has no release tags yet, and a tag would still have to be verified
  before it is usable.
- **Clone at build time (CMake `ExternalProject`/`FetchContent`)** — one step
  for the user. Rejected: it puts a network dependency inside `west build`,
  makes offline builds and repeated builds worse, and hides which revision the
  image was made from.
- **Pin a commit in `nanomq.ref`, fetch it with an explicit script** (chosen).

## Consequences

- A fresh clone of this repository has no nanomq until
  `scripts/fetch-nanomq.sh` runs; the CMake walk fails with a message naming the
  script rather than a missing-header error.
- Bumping REF is a deliberate commit here, and it should carry a re-run of the
  functional suite and an update to VERIFIED.
- `scripts/fetch-nanomq.sh --ref <ref>` checks out something else for an
  experiment, and `-DNANOMQ_ROOT=<path>` builds against any checkout — the
  bring-up workflow keeps using a worktree with edited nng sources.
- The board bring-up records (the ART-Pi article in nanomq's tutorials, the
  example READMEs) have to name the revision they were verified against, or
  they stop being checkable.
