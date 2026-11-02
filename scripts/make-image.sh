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
TARGET_DIR="${TARGET_DIR:-$WORK/targets/$ARCH}"
SNIPPETS_SRC="${SNIPPETS_SRC:-$WORK/image/snippets}"

[ -d "$REL" ] || { echo "no OTP release at $REL; run build-otp.sh first" >&2; exit 1; }

# shellcheck disable=SC1091
source "${QNX_BASE}/qnxsdp-env.sh"

mkdir -p "$TARGET_DIR/local/snippets"

# Bake the OTP release in as a tarball, unpacked on first boot by
# post_start.custom. Built here with Linux tar, so no macOS resource forks.
tar -C "$REL" -czf "$TARGET_DIR/local/otp-qnx.tgz" .

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
