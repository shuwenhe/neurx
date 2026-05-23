#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [--config path] [--steps N]

--config: YAML config path (default: workflows/agent/tool_use/config/sample.yaml)
--steps: override max_steps from config
--s-bin: explicit path to the S executable
EOF
}

CONFIG="$(pwd)/workflows/agent/tool_use/config/sample.yaml"
STEPS_OVERRIDE=""
S_BIN_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"; shift 2;;
    --steps)
      STEPS_OVERRIDE="$2"; shift 2;;
    --s-bin)
      S_BIN_OVERRIDE="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [[ ! -f "$CONFIG" ]]; then
  echo "Config not found: $CONFIG"
  exit 1
fi

MAX_STEPS="$(awk -F":" '/^max_steps[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
MODEL_NAME="$(awk -F":" '/^model_name[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"
TOOL_MANIFEST="$(awk -F":" '/^tool_manifest[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"
OUTPUT_DIR="$(awk -F":" '/^output_dir[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"

if [[ -n "$STEPS_OVERRIDE" ]]; then
  MAX_STEPS="$STEPS_OVERRIDE"
fi

if [[ -z "$MAX_STEPS" ]]; then MAX_STEPS=200; fi
if [[ -z "$MODEL_NAME" ]]; then MODEL_NAME="agent-tool-use-mini"; fi
if [[ -z "$TOOL_MANIFEST" ]]; then TOOL_MANIFEST="data/agent/tool_use/tools.json"; fi
if [[ -z "$OUTPUT_DIR" ]]; then OUTPUT_DIR="artifacts/checkpoints/agent/tool_use"; fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
fi
cd "$ROOT_DIR"

source "$ROOT_DIR/workflows/agent/common/find_s.sh"
if [[ -n "$S_BIN_OVERRIDE" ]]; then
  S_BIN="$S_BIN_OVERRIDE"
else
  S_BIN="$(resolve_s_bin "$ROOT_DIR" || true)"
fi

if ! is_runnable_s_candidate "$S_BIN"; then
  echo "[neurx] tool_use workflow: missing runnable 's' executable"
  echo "Set S_BIN/S_ROOT, add 's' to PATH, or place the toolchain under ~/s/bin."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMP_S="$(mktemp /tmp/neurx_agent_tool_use_run.XXXXXX.s)"
TMP_IR="$(mktemp /tmp/neurx_agent_tool_use_run.XXXXXX.ir)"
cleanup() {
  rm -f "$TMP_S" "$TMP_IR"
}
trap cleanup EXIT

cat > "$TMP_S" <<SFILE
package neurx.workflows.agent.tool_use.run_tmp

use neurx.workflows.agent.tool_use.pipeline_runner.{run_agent_tool_use_workflow}

func main() int {
    run_agent_tool_use_workflow(${MAX_STEPS}, "${OUTPUT_DIR}", "${TOOL_MANIFEST}", "${MODEL_NAME}")
    0
}
SFILE

"$ROOT_DIR/workflows/agent/common/compile_runtime.sh" --s-bin "$S_BIN"
"$S_BIN" "$TMP_S" "$TMP_IR"

echo "Ran agent tool_use workflow with steps=${MAX_STEPS}, model=${MODEL_NAME}, tool_manifest=${TOOL_MANIFEST}, output=${OUTPUT_DIR}, s_bin=${S_BIN}"
