#!/usr/bin/env bash
# Cross-compile Erlang/OTP for QNX 8.0 using the SDP installed in the image.
# Run inside the container, after the image is built:
#   docker compose run --rm toolchain ./scripts/build-otp.sh
set -euo pipefail

OTP_REF="${OTP_REF:-maint-28}"
OTP_PATCH_URL="${OTP_PATCH_URL:-https://github.com/erlang/otp/commit/d7e0b82835312a0458e276f4663bb432574a26d6.patch}"
QNX_XCOMP="${QNX_XCOMP:-xcomp/erl-xcomp-x86_64-qnx.conf}"
SRC="${SRC:-/work/otp}"
DEST="${DEST:-/work/otp-qnx}"

# GUI and dev-only apps have no place in a QNX runtime and pull in wx, which is
# disabled in the cross build (their wx modules otherwise fail under -Werror).
EXTRA_CONFIGURE="${EXTRA_CONFIGURE:---without-wx --without-debugger --without-observer --without-et}"

# shellcheck disable=SC1091
source "${QNX_BASE}/qnxsdp-env.sh"

if [ ! -d "$SRC" ]; then
  git clone --depth 1 --branch "$OTP_REF" https://github.com/erlang/otp.git "$SRC"
fi
cd "$SRC"

# Maennchen's experimental QNX patch adds the xcomp conf and the QNX/POSIX shims.
# Idempotent: the conf file only exists once the patch is applied, so re-runs on
# an existing checkout skip it. The patch base may not match $OTP_REF exactly; if
# apply fails, pin OTP_REF to a closer ref or resolve the conflict by hand.
if [ -f "$QNX_XCOMP" ]; then
  echo "QNX patch already applied, skipping"
else
  patch_file="$(mktemp)"
  curl -fsSL "$OTP_PATCH_URL" >"$patch_file"
  if git apply --check "$patch_file" 2>/dev/null; then
    git apply -v "$patch_file"
  else
    echo "warning: QNX patch does not apply cleanly against $OTP_REF, attempting 3-way" >&2
    git apply -3 "$patch_file" || {
      echo "error: patch failed; adjust OTP_REF or merge manually" >&2
      exit 1
    }
  fi
fi

export ERL_TOP="$SRC"
# shellcheck disable=SC2086
./otp_build configure --xcomp-conf="$QNX_XCOMP" $EXTRA_CONFIGURE
./otp_build boot -a
./otp_build release -a "$DEST"

echo "Cross-compiled OTP staged at: $DEST"
echo "On the QNX target, erlang:system_info(system_architecture) should report x86_64-unknown-nto-qnx."
