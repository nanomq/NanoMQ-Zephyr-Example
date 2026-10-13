# Glossary

The vocabulary of this repository and of the NanoMQ-on-Zephyr port it ships.
Use these words in commits, issue titles, READMEs and ADRs; the _Avoid_ lines
name what they replace.

## Language

**Example**:
One of the three applications under `examples/` that builds the NanoMQ broker
core plus NanoNNG for one Zephyr target: `nanomq_zephyr_qemu_x86`
(simulation), `nanomq_zephyr_esp32s3`, `nanomq_zephyr_stm32_art-pi`.
_Avoid_: "demo" for the application, and `demo/` for the directory — it is
`examples/`.

**Example family**:
The three examples taken together. They share one application source, one
dependency walk in CMake, and one functional suite.

**nanomq checkout**:
The nanomq revision the examples compile against: `extern/nanomq`, cloned by
`scripts/fetch-nanomq.sh` and pinned in `nanomq.ref`. It holds the broker core
(`nanomq/`) and the NanoNNG fork as its `nng/` submodule.
_Avoid_: "the nanomq repository" when the local build dependency is meant.

**Pinned revision**:
The commit recorded in `nanomq.ref` — REF, the nng submodule commit it resolves
to (NNG), and the date the pair passed the functional suite (VERIFIED). Bumped
deliberately, never by following a branch.
_Avoid_: "latest", "HEAD" as a build input.

**NanoNNG**:
The nng fork the port builds from, held as nanomq's `nng/` submodule. It owns
the Zephyr platform layer (`src/platform/zephyr/`) and the nanolib sources.
_Avoid_: bare "nng" when the fork's Zephyr layer is the subject.

**Broker port**:
The whole `__ZEPHYR__` platform effort that lets the NanoMQ core run on Zephyr
RTOS. Its narrative lives in nanomq's `docs/{en_US,zh_CN}/tutorial/`.
_Avoid_: "the Zephyr port" for one example.

**Acceptance tier**:
How far an example is proven: buildable, board-verified, or at functional
parity with the functional suite.

**West workspace**:
The Zephyr source tree (`zephyr/`, `modules/`, `.west/`) this repository has to
live inside — west resolves the workspace from the application directory, so a
clone outside one cannot build.

**Functional suite**:
`examples/nanomq_zephyr_qemu_x86/function_test.py`, the client-side test suite
that also drives hardware boards through `--addr`. The acceptance gate for any
example.

**ART-Pi**:
The Ruiside (RT-Thread team) STM32H750XBH6 board that is the hardware target of
the ART-Pi example.
_Avoid_: "RT-Thread ART-Pi" when the RTOS is what is meant.

**ART-Pi factory bootloader**:
The Ruiside/RT-Thread first stage shipped in the ART-Pi's internal flash: it
maps the QSPI flash and jumps to the vector table at 0x90000000.
_Avoid_: "the bootloader" (ambiguous with MCUboot or a Zephyr first stage).

**Broker heap**:
The memory NanoNNG's allocator serves the broker's data plane from — on the
ART-Pi, a `k_heap` over the SDRAM region, not the internal SRAM.
_Avoid_: "the heap" (ambiguous with the kernel heap and the libc arena).

**Wi-Fi link supervisor**:
The ART-Pi example's thread that watches the Wi-Fi join state after the bounded
boot-time association and re-associates (then re-requests a lease) when the
link is gone.
_Avoid_: "watchdog" (that is the hardware timer, and it resets the board).

## Relationships

- The **example family** has three members: qemu_x86 (simulation), ESP32-S3,
  and ART-Pi.
- Each **example** claims one **acceptance tier**.
- Every **example** compiles the **nanomq checkout** and its **NanoNNG**
  submodule; the **pinned revision** fixes which one.
- An **example** only builds inside a **west workspace**.
- The ART-Pi **example** starts through the **ART-Pi factory bootloader**.
- The **broker heap** lives in SDRAM; the kernel heap and the libc arena stay
  in internal SRAM.
- The ART-Pi **Wi-Fi link supervisor** polls the driver's join state; it does
  not depend on the driver's disconnect event, which only an explicit
  disconnect raises.

## Example dialogue

> **Dev:** "Does the ART-Pi example need RT-Thread?"
> **Domain expert:** "No — ART-Pi is the board. The application is an
> **example**, same as the ESP32-S3 sibling."

> **Dev:** "Should I `git pull` nanomq before building?"
> **Domain expert:** "No. `scripts/fetch-nanomq.sh` checks out the **pinned
> revision**; bump REF when you have verified a newer one."

## Flagged ambiguities

- The porting brief says "RT-Thread ART-Pi". Resolved: that names the board
  (Ruiside is RT-Thread's hardware arm); the port runs Zephyr on it, not NanoMQ
  on the RT-Thread kernel.
- "Demo" was the word for these applications while they lived in the nanomq
  repository under `demo/`. Resolved: they are examples under `examples/`; the
  nanomq tutorials still use "demo" in prose and in quoted history.
