#!/usr/bin/env bash
# Isolated X display; never attach to the host display or disable the sandbox.
set -euo pipefail
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
: > /evidence/viewer.log
exec >> /evidence/viewer.log 2>&1
# Invoked indirectly by the EXIT trap below.
# shellcheck disable=SC2329
finish() {
  local status=$?
  printf '%s\n' "$status" > /evidence/exit-code.txt
  if [[ ! -f /evidence/result.json ]]; then
    printf '{"status":"failed","error":"driver did not finish; inspect viewer.log","exit_code":%s}\n' \
      "$status" > /evidence/result.json
  fi
  if [[ -n ${xvfb_pid:-} ]]; then kill "$xvfb_pid" 2>/dev/null || true; fi
}
trap finish EXIT
if [[ $(id -u) == 0 || -n ${QTWEBENGINE_DISABLE_SANDBOX:-} ||
      -n ${QTWEBENGINE_CHROMIUM_FLAGS:-} ]]; then
  printf '%s\n' 'Require nonroot Qt WebEngine with its normal sandbox and no extra Chromium flags.'
  exit 2
fi
Xvfb :99 -screen 0 1280x900x24 -nolisten tcp > /evidence/xvfb.log 2>&1 &
xvfb_pid=$!
for _attempt in {1..30}; do
  if xdotool getdisplaygeometry; then break; fi
  sleep 0.2
done
status=0
timeout --signal=TERM --kill-after=5s 260s python3 /opt/reader/driver.py "$@" || status=$?
exit "$status"
