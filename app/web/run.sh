#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NEURX_BACKEND_URL="${NEURX_BACKEND_URL:-http://127.0.0.1:18080/neurx/api/chat}"

cd "${ROOT_DIR}"
exec npm run dev
