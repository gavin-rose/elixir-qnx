#!/bin/sh
# Start the webdemo Bandit server on the QNX guest, using the baked-in Elixir and
# OTP. The app and its deps were compiled on the host (portable BEAM bytecode);
# launching through the elixir script puts Elixir's own ebins on the path so the
# Elixir-compiled modules load.
export PATH=/data/opt/otp/bin:/data/opt/elixir/bin:$PATH
export PORT="${PORT:-4000}"

PA=""
for d in /data/opt/webdemo/lib/*/ebin; do PA="$PA -pa $d"; done

exec elixir --no-halt --erl "$PA" -e "Application.ensure_all_started(:webdemo)"
