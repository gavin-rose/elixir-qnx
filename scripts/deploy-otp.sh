#!/usr/bin/env bash
# Copy the cross-compiled OTP release into a running QNX guest over the SSH
# port-forward that run-qemu.sh opens, then it can be started on the target.
# Run on the host while the guest is booted:
#   ./scripts/deploy-otp.sh
set -euo pipefail

REL="${REL:-otp-qnx}"
SSH_PORT="${SSH_PORT:-2222}"
USER_="${USER_:-qnxuser}"
DEST="${DEST:-/opt/otp}"

[ -d "$REL" ] || { echo "no $REL release dir; run build-otp.sh first" >&2; exit 1; }

tar -C "$REL" -czf /tmp/otp-qnx.tgz .
scp -P "$SSH_PORT" -o StrictHostKeyChecking=no /tmp/otp-qnx.tgz "${USER_}@localhost:/tmp/otp-qnx.tgz"

# The OTP release records its build-time ROOTDIR; running bin/erl may need the
# release's Install script first to rewrite paths for $DEST on the target.
ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "${USER_}@localhost" \
  "mkdir -p ${DEST} && cd ${DEST} && tar xzf /tmp/otp-qnx.tgz && echo deployed to ${DEST}"

echo "On the guest, start the shell with: ${DEST}/bin/erl"
echo "If it complains about ROOTDIR, run ${DEST}/Install -minimal ${DEST} first."
