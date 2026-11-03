# Elixir on QNX

Bringing the Elixir/Erlang stack to the QNX 8.0 real-time OS: a reproducible,
Dockerized cross-compile toolchain for Erlang/OTP on QNX, with Elixir and a
small Phoenix app on top, plus clean cross-compile support offered upstream.

Built for the QNX Global Hackathon. Runs entirely in QEMU; no target hardware
required.

## Status

Early. The toolchain image (QNX SDP 8.0 + OTP cross-compile) is the first piece.

Prior art this builds on: Jonatan Maennchen's proof of concept running Erlang/OTP
28 on QNX 8.0 (https://erlef.org/blog/embedded/otp-qnx-port), which is an
experimental, unmerged patch (`erlang/otp` commit `d7e0b82`) covering an x86_64
QEMU boot and the Erlang shell. It does not cover Elixir, Phoenix, aarch64, or a
clean upstreamable cross-compile config. That gap is the project.

## Why Docker

The QNX SDK host tools are x86_64 Linux only and are not supported on macOS or
ARM hosts, so the toolchain lives in a `linux/amd64` container. On Apple Silicon,
Docker Desktop runs it under Rosetta. The QNX image it produces can target
aarch64le and then runs near-native in QEMU on an Apple Silicon host.

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

### Web demo

`webdemo/` is a minimal Bandit + Plug app (pure-Elixir deps, no NIFs). Compile it
on the host first (`cd webdemo && mix compile`); `make-image.sh` bakes its
host-compiled beams into the image and `post_start.custom` starts it on boot. The
guest's port 4000 is forwarded, so once it is up, open `http://localhost:4000`:
the page is served by the BEAM on QNX and reports the guest's
`system_architecture`, `os:type`, and more.

On Apple Silicon the x86_64 guest runs under TCG (slower); the aarch64le target
runs under HVF near-native, and becomes the primary once an aarch64 OTP release
is built (`ARCH=aarch64le`).

### image/snippets

Tracked `mkqnximage` customizations copied into the build's `local/snippets/`:

- `data_files.custom` adds the OTP and Elixir tarballs to the data partition.
- `post_start.custom` unpacks/installs them on first boot and prints the proofs.
- `profile.custom` puts `erl`, `iex`, and `elixir` on `PATH`.
- `system_files.custom` adds `sshd-auth` (QNX's stock image omits it, breaking sshd).

## Roadmap

1. OTP 28 cross-compiled for x86_64 QNX, booted in QEMU (reproduce the PoC baseline).
2. Elixir on QNX: ship the Elixir `ebin` dirs into the image, run `iex`.
3. `mix release` bundling the QNX ERTS (`include_erts`/`system_libs`): the
   "release for QNX" packaging step.
4. A Phoenix + LiveView page served from inside QNX in QEMU (pure-Elixir deps
   only; no NIFs).
5. aarch64le: a new `erl-xcomp-aarch64-qnx.conf` plus generalizing the hardcoded
   compiler name, offered as a clean PR to `erlang/otp`. Also the faster QEMU
   target on Apple Silicon.

## Hackathon category

Open-Source Contribution & Ports (the upstream cross-compile PR), or Developer
Tooling & Host Tools (the release packager), whichever lands strongest.
