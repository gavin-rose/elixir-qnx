#!/usr/bin/env bash
# Cross-compile Erlang/OTP for QNX 8.0 using the SDP installed in the image.
# Run inside the container, after the image is built:
#   docker compose run --rm toolchain ./scripts/build-otp.sh
#   ARCH=aarch64le docker compose run --rm toolchain ./scripts/build-otp.sh
set -euo pipefail

ARCH="${ARCH:-x86_64}"
case "$ARCH" in
  x86_64)    CPU=x86_64;  DEFAULT_SRC=/work/otp;           DEFAULT_DEST=/work/otp-qnx ;;
  aarch64le) CPU=aarch64; DEFAULT_SRC=/work/otp-aarch64le; DEFAULT_DEST=/work/otp-qnx-aarch64le ;;
  *) echo "unknown ARCH: $ARCH (x86_64 or aarch64le)" >&2; exit 1 ;;
esac

OTP_REF="${OTP_REF:-maint-28}"
OTP_PATCH_URL="${OTP_PATCH_URL:-https://github.com/erlang/otp/commit/d7e0b82835312a0458e276f4663bb432574a26d6.patch}"
MULTIARCH_PATCH="${MULTIARCH_PATCH:-/work/patches/otp-qnx-multiarch.patch}"
QNX_XCOMP="${QNX_XCOMP:-xcomp/erl-xcomp-$CPU-qnx.conf}"
SRC="${SRC:-$DEFAULT_SRC}"
DEST="${DEST:-$DEFAULT_DEST}"

# GUI and dev-only apps have no place in a QNX runtime and pull in wx, which is
# disabled in the cross build (their wx modules otherwise fail under -Werror).
EXTRA_CONFIGURE="${EXTRA_CONFIGURE:---without-wx --without-debugger --without-observer --without-et}"

# Apply a patch unless the file it creates already exists, so re-runs on an
# existing checkout are no-ops.
apply_once() {
  local patch_file="$1" marker="$2"
  if [ -f "$marker" ]; then
    echo "$(basename "$patch_file"): already applied"
  elif git apply --check "$patch_file" 2>/dev/null; then
    git apply -v "$patch_file"
  else
    echo "warning: $(basename "$patch_file") does not apply cleanly, attempting 3-way" >&2
    git apply -3 "$patch_file" || { echo "error: patch failed against $OTP_REF" >&2; exit 1; }
  fi
}

# shellcheck disable=SC1091
source "${QNX_BASE}/qnxsdp-env.sh"

if [ ! -d "$SRC" ]; then
  git clone --depth 1 --branch "$OTP_REF" https://github.com/erlang/otp.git "$SRC"
fi
cd "$SRC"

# Maennchen's experimental QNX port (x86_64), then our patch making it multi-arch.
base_patch="$(mktemp)"
curl -fsSL "$OTP_PATCH_URL" >"$base_patch"
apply_once "$base_patch" xcomp/erl-xcomp-x86_64-qnx.conf
apply_once "$MULTIARCH_PATCH" xcomp/erl-xcomp-aarch64-qnx.conf

export ERL_TOP="$SRC"
# shellcheck disable=SC2086
./otp_build configure --xcomp-conf="$QNX_XCOMP" $EXTRA_CONFIGURE
./otp_build boot -a
./otp_build release -a "$DEST"

echo "Cross-compiled OTP ($ARCH) staged at: $DEST"
