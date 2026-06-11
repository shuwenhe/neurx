#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
fi
cd "$ROOT_DIR"

source "$ROOT_DIR/workflows/agent/common/find_s.sh"
S_BIN="$(resolve_s_bin "$ROOT_DIR" || true)"
if [[ -z "$S_BIN" ]]; then
  echo "[neurx] skills workflow: missing runnable 's' executable"
  echo "Set S_BIN/S_ROOT, add 's' to PATH, or place the toolchain under ~/s/bin."
  exit 1
fi

echo "[neurx] skills workflow: starting configured skill evolution runner"
"$ROOT_DIR/workflows/agent/skills/run/run_with_config.sh" \
  --s-bin "$S_BIN" \
  --config "$ROOT_DIR/workflows/agent/skills/config/sample.yaml"
