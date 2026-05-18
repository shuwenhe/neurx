#!/usr/bin/env bash
set -euo pipefail

usage(){
  cat <<EOF
Usage: $0 [--config path] [--steps N]

--config: YAML config path (default: workflows/robotics/train/config/sample.yaml)
--steps: override max_steps from config
EOF
}

CONFIG="$(pwd)/workflows/robotics/train/config/sample.yaml"
STEPS_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"; shift 2;;
    --steps)
      STEPS_OVERRIDE="$2"; shift 2;;
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

BATCH_SIZE="$(awk -F":" '/^batch_size[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SEQ_LEN="$(awk -F":" '/^seq_len[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
MAX_STEPS="$(awk -F":" '/^max_steps[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
LEARNING_RATE="$(awk -F":" '/^learning_rate[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
TASK_NAME="$(awk -F":" '/^task_name[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"

if [[ -n "$STEPS_OVERRIDE" ]]; then
  MAX_STEPS="$STEPS_OVERRIDE"
fi

if [[ -z "$BATCH_SIZE" ]]; then BATCH_SIZE=2; fi
if [[ -z "$SEQ_LEN" ]]; then SEQ_LEN=4; fi
if [[ -z "$MAX_STEPS" ]]; then MAX_STEPS=16; fi
if [[ -z "$LEARNING_RATE" ]]; then LEARNING_RATE=0.001; fi
if [[ -z "$TASK_NAME" ]]; then TASK_NAME="robotics_workflow_default"; fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
fi
cd "$ROOT_DIR"

TMP_S="$(mktemp /tmp/neurx_robotics_workflow_run.XXXXXX.s)"
TMP_IR="$(mktemp /tmp/neurx_robotics_workflow_run.XXXXXX.ir)"
cleanup(){
  rm -f "$TMP_S" "$TMP_IR"
}
trap cleanup EXIT

cat > "$TMP_S" <<SFILE
package neurx.workflows.robotics.train.run_tmp

use neurx.workflows.robotics.train.pipeline_runner.{run_robotics_training_with_params}

func main() int {
    run_robotics_training_with_params(${BATCH_SIZE}, ${SEQ_LEN}, ${MAX_STEPS}, ${LEARNING_RATE}, "${TASK_NAME}")
    0
}
SFILE

make s-compile-runtime
s "$TMP_S" "$TMP_IR"

echo "Ran robotics workflow with batch=${BATCH_SIZE}, seq_len=${SEQ_LEN}, steps=${MAX_STEPS}, lr=${LEARNING_RATE}, task=${TASK_NAME}"
