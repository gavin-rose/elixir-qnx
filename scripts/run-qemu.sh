#!/usr/bin/env bash
# Boot a QNX image built by make-image.sh, on the macOS host via QEMU.
#
# The args mirror QNX's own runimage template (boot via -kernel output/ifs.bin),
# with two macOS adjustments: user-mode networking plus an SSH port-forward,
# because the template's bridge networking is unsupported on Darwin; and HVF
# acceleration for the aarch64 target on Apple Silicon.
set -euo pipefail

ARCH="${ARCH:-x86_64}"
TARGET_DIR="${TARGET_DIR:-targets/$ARCH}"
RAM="${RAM:-2048}"
CPUS="${CPUS:-4}"
SSH_PORT="${SSH_PORT:-2222}"
HTTP_PORT="${HTTP_PORT:-4000}"

cd "$TARGET_DIR"
[ -f output/ifs.bin ] || { echo "no output/ifs.bin in $TARGET_DIR; run make-image.sh first" >&2; exit 1; }

# User-mode networking with SSH and HTTP forwards to the guest (no privileges).
net_args=(-netdev user,id=net0,hostfwd=tcp::"${SSH_PORT}"-:22,hostfwd=tcp::"${HTTP_PORT}"-:4000)

case "$ARCH" in
  x86_64)
    # No HVF for an x86 guest on an ARM host, so QEMU uses TCG (slower). Fine for
    # a first boot; the aarch64 target below is the fast one.
    exec qemu-system-x86_64 \
      -smp "$CPUS" -cpu max -m "$RAM" \
      -drive file=output/disk-qemu.vmdk,if=ide,id=drv0 \
      -kernel output/ifs.bin \
      "${net_args[@]}" -device virtio-net-pci,netdev=net0 \
      -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 \
      -nographic -serial mon:stdio
    ;;
  aarch64le)
    # HVF gives near-native speed on Apple Silicon; -cpu host requires it.
    # The machine/gic wiring may need tuning against the image mkqnximage emits.
    exec qemu-system-aarch64 \
      -machine virt,accel=hvf,gic-version=3 -cpu host \
      -smp "$CPUS" -m "$RAM" \
      -drive file=output/disk-qemu.vmdk,if=none,id=drv0 -device virtio-blk-device,drive=drv0 \
      -kernel output/ifs.bin \
      "${net_args[@]}" -device virtio-net-device,netdev=net0 \
      -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-device,rng=rng0 \
      -nographic -serial mon:stdio
    ;;
  *)
    echo "unknown ARCH: $ARCH" >&2
    exit 1
    ;;
esac
