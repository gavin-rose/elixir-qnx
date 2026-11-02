#!/usr/bin/env bash
# Download the precompiled Elixir (OTP 28 build) into ./elixir for make-image.sh
# to bake into the QNX image. Elixir ships as portable BEAM bytecode, so there
# is nothing to compile or cross-compile.
set -euo pipefail

ELIXIR_VERSION="${ELIXIR_VERSION:-1.20.5}"
DEST="${DEST:-elixir}"
url="https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-28.zip"

tmp="$(mktemp -d)"
curl -fsSL "$url" -o "$tmp/elixir.zip"
rm -rf "$DEST" && mkdir -p "$DEST"
unzip -q "$tmp/elixir.zip" -d "$DEST"
rm -rf "$tmp"

echo "Elixir $ELIXIR_VERSION (OTP 28 build) unpacked into $DEST"
