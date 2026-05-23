#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/workflows/agent/common/find_s.sh"
S_BIN="$(resolve_s_bin "$REPO_ROOT" || true)"
if [[ -z "$S_BIN" ]]; then
  echo "[neurx] memory workflow: missing runnable 's' executable"
  echo "Set S_BIN/S_ROOT, add 's' to PATH, or place the toolchain under ~/s/bin."
  exit 1
fi

mkdir -p artifacts/checkpoints/agent/memory

echo "[neurx] memory workflow: starting configured memory runner"
"$REPO_ROOT/workflows/agent/memory/run/run_with_config.sh" \
  --s-bin "$S_BIN" \
  --config "$REPO_ROOT/workflows/agent/memory/config/sample.yaml"
