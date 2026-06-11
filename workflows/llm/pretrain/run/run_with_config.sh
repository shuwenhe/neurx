#!/usr/bin/env bash
set -euo pipefail

usage(){
  cat <<EOF
Usage: $0 [--config path] [--steps N]

--config: YAML config file (default: workflows/llm/pretrain/config/sample.yaml)
--steps:  override steps in config (optional)

This launcher extracts workflow fields from YAML, generates a small S runner
that calls the persistent pipeline runner, compiles the runner IR, and executes it.
EOF
}

CONFIG="$(pwd)/workflows/llm/pretrain/config/sample.yaml"
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
  echo "Config not found: $CONFIG"; exit 1
fi

# Extract max_steps (simple YAML parsing: matches 'max_steps: <num>')
MAX_STEPS="$(awk -F":" '/^max_steps[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
if [[ -z "$MAX_STEPS" ]]; then
  echo "max_steps not found in $CONFIG, defaulting to 0"
  MAX_STEPS=0
fi

if [[ -n "$STEPS_OVERRIDE" ]]; then
  MAX_STEPS="$STEPS_OVERRIDE"
fi

# Extract other hyperparameters: micro_batch_size, seq_len, lr
MICRO_BATCH="$(awk -F":" '/^micro_batch_size[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SEQ_LEN="$(awk -F":" '/^seq_len[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
LR="$(awk -F":" '/^lr[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
LOG_INTERVAL="$(awk -F":" '/^log_interval[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
EVAL_INTERVAL="$(awk -F":" '/^eval_interval[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SAVE_INTERVAL="$(awk -F":" '/^save_interval[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"

if [[ -z "$MICRO_BATCH" ]]; then MICRO_BATCH=8; fi
if [[ -z "$SEQ_LEN" ]]; then SEQ_LEN=16; fi
if [[ -z "$LR" ]]; then LR=0.00015; fi
if [[ -z "$LOG_INTERVAL" ]]; then LOG_INTERVAL=8; fi
if [[ -z "$EVAL_INTERVAL" ]]; then EVAL_INTERVAL=16; fi
if [[ -z "$SAVE_INTERVAL" ]]; then SAVE_INTERVAL=32; fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi
cd "$ROOT_DIR"

# create temporary runner S file outside the repo so it does not get picked up
# by the main S compile scan.
TMP_S="$(mktemp /tmp/neurx_llm_pretrain_run.XXXXXX.s)"
TMP_IR="$(mktemp /tmp/neurx_llm_pretrain_run.XXXXXX.ir)"
cleanup() {
  rm -f "$TMP_S" "$TMP_IR"
}
trap cleanup EXIT

cat > "$TMP_S" <<SFILE
package neurx.workflows.llm.pretrain.run_tmp

use neurx.workflows.llm.pretrain.run.pipeline_runner.{run_pretrain_with_params}

func main() int {
  run_pretrain_with_params(${MICRO_BATCH}, ${SEQ_LEN}, ${LR}, ${MAX_STEPS}, ${LOG_INTERVAL}, ${EVAL_INTERVAL}, ${SAVE_INTERVAL})
  0
}
SFILE

# compile and run the tmp S file
make s-compile-runtime
s "$TMP_S" "$TMP_IR"

echo "Ran pretrain workflow with steps=${MAX_STEPS}, micro_batch=${MICRO_BATCH}, seq_len=${SEQ_LEN}, lr=${LR}, log/eval/save=${LOG_INTERVAL}/${EVAL_INTERVAL}/${SAVE_INTERVAL}"
