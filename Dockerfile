# syntax=docker/dockerfile:1.7
# QNX SDP 8.0 cross-compile toolchain for building Erlang/OTP (and Elixir) for QNX.
# Built as linux/amd64 because the QNX host tools are x86_64 Linux only; on Apple
# Silicon this is accelerated by Rosetta in Docker Desktop.
FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# The QNX Software Center is an Eclipse/Java app and needs a JRE and SWT even for
# the command-line client; xvfb covers the SWT display init in a headless build.
# The rest bootstrap an OTP build and the cross-compile.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils \
      default-jre libswt-gtk-4-java xvfb \
      build-essential autoconf m4 libncurses-dev perl libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the QNX Software Center Linux installer staged in ./vendor.
COPY vendor/qnx-setup-linux.run /tmp/qnx-setup.run

# Install the Software Center non-interactively (accepts the EULA, no autostart).
RUN chmod +x /tmp/qnx-setup.run \
    && /tmp/qnx-setup.run force-override disable-auto-start agree-to-license-terms /opt/qnxinstall \
    && rm -f /tmp/qnx-setup.run

# Install SDP 8.0 with your myQNX credentials and license key, passed as build
# secrets so they never land in an image layer. See README for the build command.
RUN --mount=type=secret,id=myqnx_user \
    --mount=type=secret,id=myqnx_password \
    --mount=type=secret,id=license_key \
    set -eu; \
    U="$(cat /run/secrets/myqnx_user)"; \
    P="$(cat /run/secrets/myqnx_password)"; \
    K="$(cat /run/secrets/license_key)"; \
    cd /opt/qnxinstall/qnxsoftwarecenter; \
    xvfb-run -a ./qnxsoftwarecenter_clt -myqnx.user "$U" -myqnx.password "$P" -addLicenseKey "$K"; \
    xvfb-run -a ./qnxsoftwarecenter_clt -myqnx.user "$U" -myqnx.password "$P" \
      -cleanInstall -mirrorBaseline qnx800 -installBaseline com.qnx.qnx800 -destination /opt/qnx800

ENV QNX_BASE=/opt/qnx800
WORKDIR /work
COPY scripts/ /work/scripts/
RUN chmod +x /work/scripts/*.sh
CMD ["bash"]
