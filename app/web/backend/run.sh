#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S_BINARY="${NEURX_S_BINARY:-${S_BINARY:-s}}"
exec "${S_BINARY}" run "${ROOT_DIR}/backend/serve.s"
