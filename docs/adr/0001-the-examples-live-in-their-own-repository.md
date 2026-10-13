# The examples live in their own repository, nanomq is fetched as a dependency

The Zephyr examples were built and shipped inside the nanomq repository on the
`zephyr-rtos` branch, under `demo/`. That coupled two things that change for
different reasons: the port itself (nng's Zephyr platform layer, the broker
core's trimming, nanolib) and the example applications (board overlays,
network bring-up, flashing tools, the acceptance suite's client side). Every
example change moved the nanomq branch; every nanomq change risked the
examples, and the examples could only ever be built from a nanomq checkout
whose branch carried them.

They now live in this repository, `nanomq/NanoMQ-Zephyr-Example`, under
`examples/`. nanomq keeps the port and its documentation — the tutorials in
`docs/{en_US,zh_CN}/tutorial/` stay complete and are still the place the
narrative is written — while the operational material (build, flash, console,
functional suite) is here. nanomq no longer carries `demo/`; its tutorials and
links point at this repository.

The dependency direction reverses: this repository builds *against* a nanomq
checkout, fetched by `scripts/fetch-nanomq.sh` into `extern/nanomq` and pinned
by `nanomq.ref` (see ADR-0002). The examples compile the broker core sources
and the NanoNNG fork out of that checkout, exactly as they did when the
checkout was their parent directory.

## Considered Options

- **Keep the examples in the nanomq repository** — no dependency wiring, and
  the examples always match the branch they live on. Rejected: the examples
  version independently of the port, and a downstream user cannot take the
  examples without taking a whole nanomq branch.
- **Make this repository a submodule of nanomq** — nanomq would keep a pointer
  to the examples. Rejected: it inverts the dependency that matters (examples
  depend on the port, not the other way round) and reintroduces the coupled
  versioning.
- **Let this repository own the Zephyr manifest** (`west init -m
  nanomq/NanoMQ-Zephyr-Example`) — self-contained from `west init` onward.
  Rejected for now: it would put a second manifest and a second Zephyr tree
  beside the user's existing workspace, and the examples do not need to pin
  Zephyr themselves.
- **This repository inside a west workspace, nanomq fetched into it**
  (chosen). The examples keep the build commands they always had — `west build
  -b <board> examples/<example>` — and the workspace stays the user's.

## Consequences

- This repository must be cloned *inside* a west workspace. `west build`
  resolves the workspace from the application directory, so an examples
  checkout outside one cannot build; `tools/flash.sh` reports that explicitly
  instead of failing inside west.
- The nanomq dependency has to be fetched before the first build:
  `scripts/fetch-nanomq.sh` (see ADR-0002).
- Builds can still use any nanomq checkout through `-DNANOMQ_ROOT=`, which is
  how the board bring-up work builds against a worktree with edited nng
  sources.
- The nanomq tutorials keep the full porting text and point their commands and
  absolute links here: the example paths are `examples/…` and the repository is
  `nanomq/NanoMQ-Zephyr-Example`.
- The ART-Pi out-of-tree patches, the vendor flash algorithm and the board
  overlays travel with the ART-Pi example; nothing about them is nanomq's.
