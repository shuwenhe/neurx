#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-18080}"

echo "neurx s-backend http wrapper listening on 127.0.0.1:${PORT}" >&2

exec socat \
  TCP-LISTEN:"${PORT}",bind=127.0.0.1,reuseaddr,fork \
  SYSTEM:"${SCRIPT_DIR}/http_handler.sh"
