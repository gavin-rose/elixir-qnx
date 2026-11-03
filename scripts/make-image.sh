#!/usr/bin/env bash
# Build a bootable QNX 8.0 image for QEMU with the cross-compiled OTP release
# baked into the data partition. Runs inside the toolchain container:
#   docker compose run --rm toolchain bash scripts/make-image.sh
#
# ARCH is x86_64 (default) or aarch64le; aarch64le runs under HVF on Apple Silicon.
set -euo pipefail

ARCH="${ARCH:-x86_64}"
HOST="${HOST:-qnx-$ARCH}"
USERS="${USERS:-qnxuser/qnx}"
RAM="${RAM:-2048}"
WORK="${WORK:-/work}"
if [ "$ARCH" = x86_64 ]; then DEFAULT_REL="$WORK/otp-qnx"; else DEFAULT_REL="$WORK/otp-qnx-$ARCH"; fi
REL="${REL:-$DEFAULT_REL}"
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

# Tarred with Linux tar here, so no macOS resource forks end up in the image.
tar -C "$REL" -czf "$TARGET_DIR/local/otp-qnx.tgz" .
tar -C "$ELIXIR" -czf "$TARGET_DIR/local/elixir.tgz" .

rm -rf "$TARGET_DIR/local/webdemo-stage"
mkdir -p "$TARGET_DIR/local/webdemo-stage"
# -L dereferences symlinks: mix symlinks each app's priv/ to deps/<app>/priv,
# which would dangle on the guest and 404 the client JS (phoenix.js etc.).
cp -RL "$WEBDEMO_LIB" "$TARGET_DIR/local/webdemo-stage/lib"
cp "$WORK/webdemo/start.sh" "$TARGET_DIR/local/webdemo-stage/start.sh"
# The analyzer is the real-time task: a native QNX binary the BEAM launches via on -p.
qcc -Vgcc_nto"$ARCH" -O2 -o "$TARGET_DIR/local/webdemo-stage/analyzer" "$WORK/analyzer/analyzer.c" -lm
tar -C "$TARGET_DIR/local/webdemo-stage" -czf "$TARGET_DIR/local/webdemo.tgz" .

# mkqnximage picks up local/snippets/*.custom when present.
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
