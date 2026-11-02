#!/usr/bin/env bash
# Build a bootable QNX 8.0 image for QEMU. Runs inside the toolchain container:
#   docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work \
#     elixir-qnx-toolchain bash scripts/make-image.sh
#
# Output lands in ./targets/<arch>/output (bind-mounted to the host for QEMU).
# Default arch is x86_64 to match the OTP build; switch to aarch64le once an
# aarch64 OTP release exists (that is the faster, HVF-accelerated target).
set -euo pipefail

ARCH="${ARCH:-x86_64}"
HOST="${HOST:-qnx-$ARCH}"
USERS="${USERS:-qnxuser/qnx}"
RAM="${RAM:-2048}"
TARGET_DIR="${TARGET_DIR:-/work/targets/$ARCH}"

# shellcheck disable=SC1091
source "${QNX_BASE}/qnxsdp-env.sh"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# A login user lets us reach the guest over the SSH port-forward that
# run-qemu.sh sets up; the guest generates its sshd host key on first boot (the
# container has no ssh-keygen for --sshd-pregen). --ip=dhcp takes an address
# from QEMU's user-mode network.
mkqnximage \
  --type=qemu \
  --arch="$ARCH" \
  --hostname="$HOST" \
  --users="$USERS" \
  --ssh-ident=none \
  --ip=dhcp \
  --ram="$RAM" \
  --force \
  --noprompt \
  --build

echo "Image built in: $TARGET_DIR/output"
ls -la "$TARGET_DIR/output" 2>/dev/null || true
