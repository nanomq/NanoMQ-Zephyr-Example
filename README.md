# NanoMQ on Zephyr: examples

Three example applications that run the NanoMQ MQTT broker on Zephyr RTOS:

| Example | Target | Network |
| --- | --- | --- |
| [`examples/nanomq_zephyr_qemu_x86`](examples/nanomq_zephyr_qemu_x86/) | `qemu_x86` simulation | QEMU SLIRP user-mode networking |
| [`examples/nanomq_zephyr_esp32s3`](examples/nanomq_zephyr_esp32s3/) | ESP32-S3 hardware | Wi-Fi STA + DHCP, data plane in PSRAM |
| [`examples/nanomq_zephyr_stm32_art-pi`](examples/nanomq_zephyr_stm32_art-pi/) | ART-Pi (STM32H750XBH6) hardware | Wi-Fi STA + DHCP on the on-board AP6212, data plane in SDRAM |

Each example builds the NanoMQ broker core (`nanomq/`) and NanoNNG (the `nng/`
fork with the Zephyr platform layer) for one target, with the same application
source and the same CMake dependency walk. They differ in board support and in
the network layer.

NanoMQ itself is not here. The port's narrative — why the broker core was
adapted to Zephyr, what the platform layer answers, which framework traps came
up — is written up in nanomq's own documentation:

* [NanoMQ on Zephyr RTOS: Running an MQTT Broker Directly on an MCU](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md) ([中文](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-zephyr.md))
* [Porting the Broker to the ART-Pi (STM32H750)](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-art-pi.md) ([中文](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/zh_CN/tutorial/port-to-art-pi.md))

This repository is the operational side: the applications, their board
support, their flashing tools and the acceptance suite.

## Repository layout

| Path | What it holds |
| --- | --- |
| `examples/<example>/` | One application per target, plus its own README with the full build, flash and console procedure |
| `examples/cmake/nanomq_dependency.cmake` | Resolves the nanomq checkout (`NANOMQ_ROOT`, `NNG_ROOT`) and fails with a hint when it is missing |
| `examples/cmake/nanonng_external.cmake` | Cross-compiles NanoNNG for Zephyr with `ExternalProject` |
| `scripts/fetch-nanomq.sh` | Fetches the pinned nanomq revision into `extern/nanomq` |
| `nanomq.ref` | The pinned revision: `REPO`, `REF`, the nng submodule commit, and the date the pair was verified |
| `extern/nanomq` | The fetched dependency (git-ignored) |
| `GLOSSARY.md` | The vocabulary these docs and commits use |
| `docs/adr/` | Decisions about this repository, with the alternatives that were rejected |

## 1. Clone into a west workspace

**This repository has to sit inside a Zephyr west workspace.** `west build`
resolves the workspace from the application directory, so a clone outside one
cannot build; `examples/nanomq_zephyr_stm32_art-pi/tools/flash.sh` says so
explicitly rather than failing inside west.

```sh
cd ~/zephyrproject                                            # your west workspace
git clone https://github.com/nanomq/NanoMQ-Zephyr-Example.git
```

## 2. Fetch the nanomq dependency

The examples compile the broker core and NanoNNG out of a nanomq checkout, so
fetch it once before the first build:

```sh
cd ~/zephyrproject/NanoMQ-Zephyr-Example
scripts/fetch-nanomq.sh
```

The script clones `extern/nanomq` (git-ignored) and checks out the revision in
[`nanomq.ref`](nanomq.ref) — nanomq `c8507485` with nng `98cd115e` at the time
of writing, verified 2026-10-13. It initializes only the `nng` submodule; the
other nanomq submodules serve features the examples switch off.

* `scripts/fetch-nanomq.sh --ref <ref>` checks out something else, for an
  experiment.
* `west build … -DNANOMQ_ROOT=/path/to/nanomq` builds against any checkout you
  already have — a worktree with edited nng sources, say — and skips the
  script entirely.

To bump the pin later, change `REF` in `nanomq.ref`, re-run the script, re-run
the functional suite, and update `VERIFIED`.

## 3. Environment

The full setup, with the versions used for validation, is in the
[port tutorial](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md#environment-setup).
In short:

* **Zephyr 4.4+ west workspace with its Python virtual environment** (provides
  `west` and Zephyr's Python dependencies), and **Zephyr SDK 1.0.x**:

  ```sh
  source ~/zephyr-venv/bin/activate              # wherever your venv lives
  export ZEPHYR_SDK_INSTALL_DIR=$HOME/zephyr-sdk-1.0.1
  ```

* **For the ESP32-S3 example only**, an ESP-IDF environment for `esptool` and
  the HAL blobs; `west blobs fetch hal_espressif` once, or Wi-Fi silently
  disappears. The compiler still comes from the Zephyr SDK.
* **For the ART-Pi example**, three out-of-tree patches and
  `west blobs fetch hal_infineon`; see [its README](examples/nanomq_zephyr_stm32_art-pi/README.md).
* **For `qemu_x86`**, a two-line patch to Zephyr's e1000 driver. It is
  **required**: without it the broker starts and prints its banner, but no
  client can connect, because the emulated adapter drops broadcast frames. The
  diff is in [the qemu README](examples/nanomq_zephyr_qemu_x86/README.md) and
  in the port tutorial; apply it to the `zephyr/` tree of your workspace.

## 4. Build and run

Run everything from the repository root (`~/zephyrproject/NanoMQ-Zephyr-Example`),
which is inside the workspace. Each example's README carries the full procedure;
the short version:

### qemu_x86 — the fast one

```sh
west build -b qemu_x86 -d build/nanomq_zephyr_qemu_x86 examples/nanomq_zephyr_qemu_x86
west build -d build/nanomq_zephyr_qemu_x86 -t run      # serial console on stdio
```

`-t run` forwards the broker's ports to `127.0.0.1` and occupies the terminal.
For background runs with the console in a file, [the qemu README](examples/nanomq_zephyr_qemu_x86/README.md)
has the explicit `qemu-system-i386` line and the cleanup command for leftover
instances. Start here when you develop: a build-and-run cycle takes seconds.

### ESP32-S3

```sh
cp examples/nanomq_zephyr_esp32s3/local.conf.example \
   examples/nanomq_zephyr_esp32s3/local.conf        # SSID, PSK, REST credentials
west build -b esp32s3_devkitc/esp32s3/procpu -d build/esp32s3_nanomq \
    examples/nanomq_zephyr_esp32s3 -- -DEXTRA_CONF_FILE=local.conf
west flash -d build/esp32s3_nanomq --runner esp32 --esp-device /dev/ttyUSB0
```

### ART-Pi

```sh
cp examples/nanomq_zephyr_stm32_art-pi/local.conf.example \
   examples/nanomq_zephyr_stm32_art-pi/local.conf     # SSID, PSK, REST credentials
examples/nanomq_zephyr_stm32_art-pi/tools/flash.sh --wifi
examples/nanomq_zephyr_stm32_art-pi/tools/console.sh
```

`flash.sh` builds and programs in one step (the image lives in the QSPI window,
behind the board's factory bootloader, so a bare `west build` is not enough),
and `--wifi` is the verified variant.

## 5. Ports and services

All three examples expose the same services:

| Service | Port | ESP32-S3 | qemu_x86 | ART-Pi | Authentication / encryption |
| --- | --- | --- | --- | --- | --- |
| MQTT over TCP | 1883 | Supported | Supported | Supported | None, no TLS |
| REST API | 8081 | Supported | Supported | Supported | Basic auth, credentials configured by you, no TLS |
| MQTT over WebSocket | 8083 | Supported | Supported | Supported | None, no TLS; path `/mqtt` |

The REST listener starts only when `CONFIG_BROKER_REST_USER` and
`CONFIG_BROKER_REST_PASS` are set to credentials of your own: both default to
the empty string, and the published `admin` / `public` pair is refused. Leave
them unset and the port stays closed — the suite then reports its `rest_get`
group as SKIP rather than failing.

## 6. Security

The default configuration assumes a controlled experimental network: all three
examples bind MQTT, WebSocket and REST to every interface, MQTT has no
authentication, TLS is not compiled into the port, and REST's Basic auth over
plain HTTP is Base64, not encryption.

Before using any example outside an experimental network, restrict the listening
addresses, set your own REST credentials, and put the management interface
behind a trusted network or a TLS proxy. **Do not expose the default
configuration to the public internet.** The tutorial's
[Security Considerations](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md#security-considerations)
section has the details.

## 7. Functional testing

`examples/nanomq_zephyr_qemu_x86/function_test.py` is the acceptance suite for
all three examples: it starts and drives a QEMU instance by itself, and takes
`--addr <board-ip> --no-manage` against hardware that is already running.

```sh
python3 examples/nanomq_zephyr_qemu_x86/function_test.py                   # all groups
python3 examples/nanomq_zephyr_qemu_x86/function_test.py --list            # what is in there
python3 examples/nanomq_zephyr_qemu_x86/function_test.py --no-manage --addr 192.168.1.8
```

`--no-manage --addr <board-ip>` also re-tunes the suite for a real network: a
non-loopback address implies `--time-scale 4 --retry 2`, which the
localhost-tuned sleeps need. The ART-Pi example's
`tools/verify.sh <board-ip>` wraps the three acceptance gates (`mqtt_v311`,
`mqtt_v5`, `rest_get`) around that, with `--full` for the remaining groups. The
[tutorial](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md#functional-testing)
lists the Python dependencies the suite needs.

## 8. What this port does not have

The Zephyr port is not an equivalent replacement for general NanoMQ. The
broker's peripheral features are compiled in and controlled at runtime, but
several capabilities are unavailable or unverified on this platform:

| Capability | Status | Future plan |
| --- | --- | --- |
| Filesystem (configuration, logs, persistent sessions) | Nothing is written to disk; `$SYS` reflects runtime state only | **Supported**: mount Zephyr's fs subsystem |
| SQLite persistence | Not included (`NNG_ENABLE_SQLITE=OFF`) | **Supported**: with the filesystem |
| Parquet | Not included (`SUPP_PARQUET` undefined) | **Supported**: as above |
| TLS | Not included (`NNG_ENABLE_TLS=OFF`), so no MQTTS / WSS / HTTPS | **Supported**: Zephyr ships mbedTLS and the `tls_credentials` subsystem |
| MQTT authentication (password / ACL) | Not wired up; any client connects | **Supported**: configuration wiring plus validation |
| Rule engine | No switch path in the embedded configuration | **Supported**: a matter of configuration |
| IPC transport (`nanomq ctl`) | Off; Zephyr has only anonymous `socketpair` | **Pending platform support** |
| QUIC | Not included (depends on msquic) | **Not planned** |

Two more limits are worth knowing: the thread budget is fixed (taskq 2, poller
1, expire 1, with `CONFIG_POSIX_THREAD_THREADS_MAX=16` and 16 KB stacks), and
the broker's `process.c` cannot be compiled on Zephyr — each example provides
the same symbol stub in its place. The port is based on NanoMQ 0.25.6, that is
upstream `master`, and reads its configuration from built-in defaults plus
startup code rather than from `nanomq.conf`.

## 9. Comparing the examples

|  | `examples/nanomq_zephyr_esp32s3` | `examples/nanomq_zephyr_stm32_art-pi` | `examples/nanomq_zephyr_qemu_x86` |
| --- | --- | --- | --- |
| **Target platform** | ESP32-S3 hardware | ART-Pi (STM32H750XBH6) hardware | `qemu_x86` |
| **Hardware requirement** | ESP32-S3 development board | ART-Pi development board | None |
| **Network** | Wi-Fi STA + DHCP | Wi-Fi STA + DHCP, on the on-board AP6212 | QEMU SLIRP user-mode networking |
| **Memory / storage** | 16 MB flash + octal PSRAM (data plane in PSRAM) | 8 MB QSPI flash, executed in place + 32 MB SDRAM (data plane in SDRAM) | 31 MB simulated RAM, no persistent storage |
| **Additional prerequisite** | Wi-Fi credentials, ESP-IDF for flashing, Espressif blobs | Wi-Fi credentials, three out-of-tree patches, Infineon blobs | Zephyr e1000 driver patch |
| **Typical use** | Real-world evaluation and hardware testing | Real-world evaluation on ARM; a reference for board bring-up | Quick verification during development |

For development, `qemu_x86` is the one to start with. For real-world
evaluation, use the board you have: the ESP32-S3 is the longer-established
target, and the ART-Pi shows the same port on an ARM Cortex-M7 with a different
flash layout, radio path and bring-up traps of its own.

## Links

* [The port tutorial](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-zephyr.md) and [the ART-Pi article](https://github.com/nanomq/nanomq/blob/zephyr-rtos/docs/en_US/tutorial/port-to-art-pi.md), in nanomq's docs
* [nanomq/NanoNNG](https://github.com/nanomq/NanoNNG) — the nng fork with the Zephyr platform layer
* [Decisions about this repository](docs/adr/) and [the vocabulary](GLOSSARY.md)
* [NanoMQ community discussions](https://github.com/nanomq/nanomq/discussions)

## License

[MIT](LICENSE)
