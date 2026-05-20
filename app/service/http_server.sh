#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-18080}"

echo "neurx s-backend http wrapper listening on 127.0.0.1:${PORT}" >&2

# Drop benign disconnect noise from socat while keeping real backend errors visible.
exec socat \
  TCP-LISTEN:"${PORT}",bind=127.0.0.1,reuseaddr,fork \
  SYSTEM:"${SCRIPT_DIR}/http_handler.sh" \
  2> >(awk '
    /Broken pipe/ { next }
    /exiting on signal 15/ { next }
    { print > "/dev/stderr" }
  ')
