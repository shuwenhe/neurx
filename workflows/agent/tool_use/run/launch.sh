#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/workflows/agent/common/find_s.sh"
S_BIN="$(resolve_s_bin "$REPO_ROOT" || true)"
if [[ -z "$S_BIN" ]]; then
  echo "[neurx] tool_use workflow: missing runnable 's' executable"
  echo "Set S_BIN/S_ROOT, add 's' to PATH, or place the toolchain under ~/s/bin."
  exit 1
fi

mkdir -p artifacts/checkpoints/agent/tool_use

echo "[neurx] tool_use workflow: starting configured tool use runner"
"$REPO_ROOT/workflows/agent/tool_use/run/run_with_config.sh" \
  --s-bin "$S_BIN" \
  --config "$REPO_ROOT/workflows/agent/tool_use/config/sample.yaml"
