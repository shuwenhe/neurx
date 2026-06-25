#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [--config path] [--generations N]

--config: YAML config path (default: workflows/agent/skills/config/sample.yaml)
--generations: override max_generations from config
--s-bin: explicit path to the S executable
EOF
}

CONFIG="$(pwd)/workflows/agent/skills/config/sample.yaml"
GENERATIONS_OVERRIDE=""
S_BIN_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"; shift 2;;
    --generations)
      GENERATIONS_OVERRIDE="$2"; shift 2;;
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

MAX_GENERATIONS="$(awk -F":" '/^max_generations[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
PROMOTION_THRESHOLD="$(awk -F":" '/^promotion_threshold[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
RETIRE_THRESHOLD="$(awk -F":" '/^retire_threshold[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
MIN_SUCCESS_RATE="$(awk -F":" '/^min_success_rate[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
MAX_AVG_STEPS="$(awk -F":" '/^max_avg_steps[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
OUTPUT_DIR="$(awk -F":" '/^output_dir[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"

if [[ -n "$GENERATIONS_OVERRIDE" ]]; then
  MAX_GENERATIONS="$GENERATIONS_OVERRIDE"
fi

if [[ -z "$MAX_GENERATIONS" ]]; then MAX_GENERATIONS=20; fi
if [[ -z "$PROMOTION_THRESHOLD" ]]; then PROMOTION_THRESHOLD=85.0; fi
if [[ -z "$RETIRE_THRESHOLD" ]]; then RETIRE_THRESHOLD=20.0; fi
if [[ -z "$MIN_SUCCESS_RATE" ]]; then MIN_SUCCESS_RATE=0.80; fi
if [[ -z "$MAX_AVG_STEPS" ]]; then MAX_AVG_STEPS=12; fi
if [[ -z "$OUTPUT_DIR" ]]; then OUTPUT_DIR="artifacts/checkpoints/agent/skills"; fi

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
  echo "[neurx] skills workflow: missing runnable 's' executable"
  echo "Set S_BIN/S_ROOT, add 's' to PATH, or place the toolchain under ~/s/bin."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMP_S="$(mktemp /tmp/neurx_agent_skills_run.XXXXXX.s)"
TMP_IR="$(mktemp /tmp/neurx_agent_skills_run.XXXXXX.ir)"
cleanup() {
  rm -f "$TMP_S" "$TMP_IR"
}
trap cleanup EXIT

cat > "$TMP_S" <<SFILE
package neurx.workflows.agent.skills.run_tmp

use neurx.workflows.agent.skills.pipeline_runner.{run_agent_skills_workflow}

func main() int {
    run_agent_skills_workflow(${MAX_GENERATIONS}, ${PROMOTION_THRESHOLD}, ${RETIRE_THRESHOLD}, ${MIN_SUCCESS_RATE}, ${MAX_AVG_STEPS}, "${OUTPUT_DIR}")
    0
}
SFILE

"$ROOT_DIR/workflows/agent/common/compile_runtime.sh" --s-bin "$S_BIN"
"$S_BIN" "$TMP_S" "$TMP_IR"

echo "Ran agent skills workflow with generations=${MAX_GENERATIONS}, promote=${PROMOTION_THRESHOLD}, retire=${RETIRE_THRESHOLD}, min_success=${MIN_SUCCESS_RATE}, max_avg_steps=${MAX_AVG_STEPS}, output=${OUTPUT_DIR}, s_bin=${S_BIN}"
