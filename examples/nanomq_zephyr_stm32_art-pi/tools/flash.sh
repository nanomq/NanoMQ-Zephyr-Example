#!/bin/bash
# Build and program the ART-Pi example image into the board's QSPI flash.
#
# Usage: tools/flash.sh [VARIANT] [--no-build] [--dry-run] [--build-dir DIR]
#
# --no-build programs the last build instead of rebuilding; --dry-run loads the
# flash algorithm and reports the plan without writing anything (it still
# builds first unless --no-build is given as well).
#
# VARIANT selects the network layer (default: --wifi, the configuration this
# demo is verified with):
#   --wifi   Wi-Fi STA on the on-board AP6212  (wifi.conf + art_pi_wifi.overlay)
#   --eth    on-board Ethernet PHY             (eth.conf, no extra overlay)
#   --usb    USB-ECM device port               (usb.conf + art_pi_usb.overlay)
#
# Picking the wrong one is the easiest way to get a board that looks broken:
# the Ethernet and USB variants need a cable to their far end (and the
# bring-up board has none), so they sit at "eth: still no link" /
# "usb: no carrier" forever, while only --wifi reaches the LAN on its own.
#
# The repository has to sit inside a west workspace — west resolves the
# workspace from the application directory, so a clone outside one cannot
# build.  Clone NanoMQ-Zephyr-Example into your workspace (for example
# ~/zephyrproject/NanoMQ-Zephyr-Example) and run this script from anywhere.
#
# Requires the Zephyr venv to be active (it provides west and pyocd), e.g.
#   source ~/zephyr-venv/bin/activate
#   export ZEPHYR_SDK_INSTALL_DIR=$HOME/zephyr-sdk-1.0.1
#
# local.conf (git-ignored: REST credentials, Wi-Fi SSID/PSK) is included when
# it exists.  The image is written over SWD with tools/artpi_flash.py; see
# that file and the README for why the QSPI (not the internal flash) is the
# target.
#
# NOTE: the first flash overwrites the factory RT-Thread application in QSPI
# slot0.  It is rebuildable from the ART-Pi SDK (projects/art_pi_factory).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
example=$(dirname "$here")
repo=$(cd "$example/../.." && pwd)
build_dir=${BUILD_DIR:-$repo/build/nanomq_zephyr_stm32_art-pi}

# west build walks up from the application directory looking for .west, so a
# repository outside the workspace fails deep inside west with a confusing
# error.  Say what is wrong instead.
workspace=""
probe=$repo
while [ "$probe" != "/" ]; do
    if [ -d "$probe/.west" ]; then workspace=$probe; break; fi
    probe=$(dirname "$probe")
done
if [ -z "$workspace" ]; then
    echo "flash.sh: $repo is not inside a west workspace (no .west in any parent)." >&2
    echo "          Clone NanoMQ-Zephyr-Example into your Zephyr workspace, e.g." >&2
    echo "            ~/zephyrproject/NanoMQ-Zephyr-Example" >&2
    exit 3
fi

dry_run=0
do_build=1
variant=wifi
while [ $# -gt 0 ]; do
    case "$1" in
        --wifi|--eth|--usb) variant=${1#--} ;;
        --dry-run)   dry_run=1 ;;
        --no-build)  do_build=0 ;;
        --build-dir) build_dir=$2; shift ;;
        -h|--help)   sed -n '2,35p' "$0"; exit 0 ;;
        *) echo "flash.sh: unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

confs=""
overlay=""
case "$variant" in
    wifi) confs="$example/wifi.conf";  overlay="$example/boards/art_pi_wifi.overlay" ;;
    eth)  confs="$example/eth.conf" ;;
    usb)  confs="$example/usb.conf";   overlay="$example/boards/art_pi_usb.overlay" ;;
esac

if [ "$do_build" = 1 ]; then
    extra_conf=""
    [ -f "$example/local.conf" ] && extra_conf="$example/local.conf"
    [ -n "$confs" ] && extra_conf="${extra_conf:+$extra_conf;}$confs"

    build_args=(west build -b art_pi -d "$build_dir" "$example")
    build_args+=(--)
    if [ -n "$extra_conf" ]; then
        build_args+=(-DEXTRA_CONF_FILE="$extra_conf")
    fi
    # Always pass it, even empty for --eth: CMake caches -D values in the
    # build directory, so omitting the argument would let the previous
    # variant's overlay stay in effect (and both the Wi-Fi and USB overlays
    # disable the Ethernet nodes, which leaves --eth with no interface).
    build_args+=(-DEXTRA_DTC_OVERLAY_FILE="$overlay")
    echo "+ variant: $variant"
    echo "+ ${build_args[*]}"
    (cd "$workspace" && "${build_args[@]}")
fi

flash_args=("--elf" "$build_dir/zephyr/zephyr.elf")
[ "$dry_run" = 1 ] && flash_args+=("--dry-run")

echo "+ python3 $here/artpi_flash.py ${flash_args[*]}"
exec python3 "$here/artpi_flash.py" "${flash_args[@]}"
