# Elixir on QNX

Bringing the Elixir/Erlang stack to the QNX 8.0 real-time OS: a reproducible,
Dockerized cross-compile toolchain for Erlang/OTP on QNX, with Elixir and a
small Phoenix app on top, plus clean cross-compile support offered upstream.

Built for the QNX Global Hackathon. Runs entirely in QEMU; no target hardware
required.

## Status

Working on x86_64 and aarch64le in QEMU: Erlang/OTP 28, Elixir 1.20.5, and a
Phoenix LiveView operations console, all running on QNX 8.0.

Prior art this builds on: Jonatan Maennchen's proof of concept running Erlang/OTP
28 on QNX 8.0 (https://erlef.org/blog/embedded/otp-qnx-port), which is an
experimental, unmerged patch (`erlang/otp` commit `d7e0b82`) covering an x86_64
QEMU boot and the Erlang shell. It does not cover Elixir, Phoenix, aarch64, or a
clean upstreamable cross-compile config. That gap is the project.

## Why Docker

The QNX SDK host tools are x86_64 Linux only and are not supported on macOS or
ARM hosts, so the toolchain lives in a `linux/amd64` container. On Apple Silicon,
Docker Desktop runs it under Rosetta. The QNX images it produces target x86_64
or aarch64le, and both boot in QEMU on the host.

## Prerequisites

1. Docker Desktop with "Use Rosetta for x86_64/amd64 emulation" enabled.
2. A myQNX account and a QNX Everywhere (non-commercial) license key.
3. The QNX Software Center Linux installer staged at `vendor/qnx-setup-linux.run`
   (version 2.0.4 or later; see `vendor/README.md`).

## Build the toolchain

Credentials are passed as build secrets and never written into an image layer:

```sh
export MYQNX_USER="you@example.com"
export MYQNX_PASSWORD="..."
export LICENSE_KEY="..."

docker compose build
```

This installs the QNX Software Center, then SDP 8.0 (`com.qnx.qnx800`) into
`/opt/qnx800` in the image.

## Cross-compile Erlang/OTP for QNX

```sh
docker compose run --rm toolchain ./scripts/build-otp.sh
```

Outputs a QNX-targeted OTP release under `./otp-qnx` (gitignored). Override
`OTP_REF`, `QNX_XCOMP`, or `DEST` as needed. GUI/dev apps (wx, debugger,
observer, et) are excluded from the cross build.

## Boot in QEMU

`make-image.sh` tars the OTP release and the precompiled Elixir, installs the
image-customization snippets from `image/snippets/`, and builds a bootable QNX
image with both baked into the data partition. On first boot they are unpacked
and installed and proof lines are printed to the console.

```sh
# fetch the precompiled Elixir (once); ./otp-qnx comes from build-otp.sh
./scripts/fetch-elixir.sh

# build the image in the container (ARCH defaults to x86_64 to match the OTP build)
docker compose run --rm toolchain bash scripts/make-image.sh

# boot it on the host (user-mode networking, ssh forwarded to localhost:2222)
./scripts/run-qemu.sh
```

The serial console should show, from inside QNX:

```
QNX-ERLANG-PROOF arch=x86_64-unknown-nto-qnx os={unix,qnx} version=16.4.0.7
QNX-ELIXIR-PROOF elixir=1.20.5 otp=28 arch=x86_64-unknown-nto-qnx
```

You can also `ssh -p 2222 qnxuser@localhost` (password `qnx`) into the running
guest; `erl`, `iex`, and `elixir` are on the path.

### Lab operations console

`webdemo/` is a Phoenix LiveView **operations console** for a simulated lab
analyzer. It is the demo of the honest architecture: QNX runs the real-time
workload, OTP supervises it, Phoenix operates it. Nothing hard-real-time is
faked in Elixir.

- `analyzer/analyzer.c` is the analyzer: a native QNX program (cross-compiled by
  `make-image.sh`) whose sampling loop is scheduled by QNX at a real-time
  priority (launched via `on -p`). It is the real-time task; the BEAM does not
  run it.
- `Webdemo.Analyzer` opens a port to it, parses its telemetry, and republishes
  it on PubSub. It is supervised: when the native process dies, OTP restarts it.
- `Webdemo.ConsoleLive` is the remote console (live telemetry, sparkline,
  status, event log); `Webdemo.FaultLab` injects/clears faults and pushes
  calibration by writing the control files the analyzer reads each tick.

Compile the app on the host (`cd webdemo && mix compile`), build and boot the
image, then open `http://localhost:4000`:

- Live telemetry streams over the LiveView websocket (reading, temperature,
  pressure, with a sparkline).
- The fault lab injects **overheat** / **stuck** (watch the alarm and readings),
  or **crashes** the analyzer, after which OTP restarts the native process and
  telemetry resumes with no operator action.
- Calibration updates apply live, with no restart.

Both targets run under QEMU's TCG emulation; see [aarch64](#aarch64) for the
ARM build and why it does not use HVF.

### image/snippets

Tracked `mkqnximage` customizations copied into the build's `local/snippets/`:

- `data_files.custom` adds the OTP and Elixir tarballs to the data partition.
- `post_start.custom` unpacks/installs them on first boot and prints the proofs.
- `profile.custom` puts `erl`, `iex`, and `elixir` on `PATH`.
- `system_files.custom` adds `sshd-auth` (QNX's stock image omits it, breaking sshd).

## aarch64

Everything above also builds and runs on aarch64le (QEMU `virt`, `cortex-a57`):

```sh
ARCH=aarch64le docker compose run --rm toolchain bash scripts/build-otp.sh
ARCH=aarch64le docker compose run --rm toolchain bash scripts/make-image.sh
ARCH=aarch64le ./scripts/run-qemu.sh
```

- The QNX SDP baseline omits two packages an aarch64 QEMU image needs:
  `com.qnx.qnx800.target.qemuvirt` (the board startup, `startup-qemu-virt`) and
  `com.qnx.qnx800.target.driver.virtio.devb` (the disk driver, `devb-virtio`).
  The Dockerfile installs both.
- It runs under TCG rather than HVF. HVF on Apple Silicon only offers a GICv3
  interrupt controller, and QNX's `startup-qemu-virt` in this configuration
  takes a GICv2-only path and asserts.

## Upstream patch

`patches/otp-qnx-multiarch.patch` applies on top of Jonatan Maennchen's QNX
port ([erlang/otp d7e0b82](https://github.com/erlang/otp/commit/d7e0b82835312a0458e276f4663bb432574a26d6),
not merged upstream) and makes it multi-arch:

- adds `xcomp/erl-xcomp-aarch64-qnx.conf`;
- derives the QNX cross compiler in `erts/emulator/Makefile.in` from the target
  triple instead of hardcoding `ntox86_64-gcc`;
- ignores the aarch64 build directories.

Verified: it applies cleanly to a fresh `maint-28` clone on top of the base
port, and the result cross-compiles to an aarch64 QNX `beam.smp` that boots and
runs everything above. Because mainline OTP has no QNX support yet, the upstream
PR carries the base port too, with its author's permission and credit:
[erlang/otp#12150](https://github.com/erlang/otp/pull/12150).

## Tested on

- QNX SDP 8.0 (QNX Everywhere, non-commercial), QNX Software Center 2.0.4
- QEMU 11.1 on macOS (Apple Silicon); x86_64 and aarch64le guests
- `qcc`, `ntox86_64-gcc` and `ntoaarch64-gcc` 12.2.0, in a `linux/amd64` Docker
  container under Rosetta
- Erlang/OTP 28 (`maint-28`, erts 16.4.0.7) and Elixir 1.20.5

## Not done

- `mix release` bundling the QNX ERTS: the app runs from host-compiled beams on
  the guest's Elixir instead.
- HVF acceleration for aarch64 (see above).
