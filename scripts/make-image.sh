#!/usr/bin/env bash
# Build a bootable QNX 8.0 image for QEMU with the cross-compiled OTP release
# baked into the data partition. Runs inside the toolchain container:
#   docker compose run --rm toolchain bash scripts/make-image.sh
#
# Default arch is x86_64 to match the OTP build; switch to aarch64le once an
# aarch64 OTP release exists (the faster, HVF-accelerated target).
set -euo pipefail

ARCH="${ARCH:-x86_64}"
HOST="${HOST:-qnx-$ARCH}"
USERS="${USERS:-qnxuser/qnx}"
RAM="${RAM:-2048}"
WORK="${WORK:-/work}"
REL="${REL:-$WORK/otp-qnx}"
ELIXIR="${ELIXIR:-$WORK/elixir}"
TARGET_DIR="${TARGET_DIR:-$WORK/targets/$ARCH}"
SNIPPETS_SRC="${SNIPPETS_SRC:-$WORK/image/snippets}"

WEBDEMO_LIB="$WORK/webdemo/_build/dev/lib"

[ -d "$REL" ] || { echo "no OTP release at $REL; run build-otp.sh first" >&2; exit 1; }
[ -d "$ELIXIR" ] || { echo "no Elixir at $ELIXIR; run fetch-elixir.sh first" >&2; exit 1; }
[ -d "$WEBDEMO_LIB" ] || { echo "no compiled webdemo; run 'mix compile' in webdemo/ first" >&2; exit 1; }

# shellcheck disable=SC1091
source "${QNX_BASE}/qnxsdp-env.sh"

mkdir -p "$TARGET_DIR/local/snippets"

# Bake the OTP release in as a tarball, unpacked on first boot by
# post_start.custom. Built here with Linux tar, so no macOS resource forks.
tar -C "$REL" -czf "$TARGET_DIR/local/otp-qnx.tgz" .

# Precompiled Elixir (portable BEAM bytecode), unpacked next to the OTP release.
tar -C "$ELIXIR" -czf "$TARGET_DIR/local/elixir.tgz" .

# The host-compiled web demo (Bandit + Plug): portable app and dep beams, plus
# the start script, run on the guest beam.
rm -rf "$TARGET_DIR/local/webdemo-stage"
mkdir -p "$TARGET_DIR/local/webdemo-stage"
# -L dereferences symlinks: mix symlinks each app's priv/ to deps/<app>/priv,
# which would dangle on the guest and 404 the client JS (phoenix.js etc.).
cp -RL "$WEBDEMO_LIB" "$TARGET_DIR/local/webdemo-stage/lib"
cp "$WORK/webdemo/start.sh" "$TARGET_DIR/local/webdemo-stage/start.sh"
# Cross-compile the native QNX analyzer (the real-time sampling loop) and stage
# it with the app; the BEAM launches it via `on -p` at a real-time priority.
qcc -Vgcc_ntox86_64 -O2 -o "$TARGET_DIR/local/webdemo-stage/analyzer" "$WORK/analyzer/analyzer.c" -lm
tar -C "$TARGET_DIR/local/webdemo-stage" -czf "$TARGET_DIR/local/webdemo.tgz" .

# Install the tracked image-customization snippets (OTP bake-in, sshd-auth fix,
# PATH). mkqnximage uses local/snippets/*.custom when present.
cp "$SNIPPETS_SRC"/*.custom "$TARGET_DIR/local/snippets/"

cd "$TARGET_DIR"
mkqnximage \
  --type=qemu \
  --arch="$ARCH" \
  --hostname="$HOST" \
  --users="$USERS" \
  --ssh-ident=none \
  --ip=dhcp \
  --ram="$RAM" \
  --data-size="${DATA_SIZE:-768}" \
  --data-inodes="${DATA_INODES:-40000}" \
  --force \
  --noprompt \
  --build

echo "Image built in: $TARGET_DIR/output"
