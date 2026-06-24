#!/usr/bin/env bash
set -euo pipefail

usage(){
  cat <<EOF
Usage: $0 [--config path] [--steps N]

--config: YAML config file (default: workflows/llm/pretrain/config/sample.yaml)
--steps:  override steps in config (optional)

This launcher extracts workflow fields from YAML, generates a small S runner
that calls the 2T runtime-backed pipeline runner, and compiles the runner IR.
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
WARMUP_STEPS="$(awk -F":" '/^warmup_steps[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
MIN_LR="$(awk -F":" '/^min_lr[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
WEIGHT_DECAY="$(awk -F":" '/^weight_decay[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
DATASET_MANIFEST="$(awk -F":" '/^dataset_manifest[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"
OUTPUT_DIR="$(awk -F":" '/^output_dir[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"
CHECKPOINT_ROOT="$(awk -F":" '/^checkpoint_root[[:space:]]*:/ {sub(/^[[:space:]]*/, "", $2); gsub(/^"|"$/, "", $2); print $2; exit}' "$CONFIG" || true)"
LOG_INTERVAL="$(awk -F":" '/^log_interval[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
EVAL_INTERVAL="$(awk -F":" '/^eval_interval[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SAVE_INTERVAL="$(awk -F":" '/^save_interval[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
TP_DEGREE="$(awk -F":" '/^tensor_parallel_degree[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
PP_DEGREE="$(awk -F":" '/^pipeline_parallel_degree[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
DP_DEGREE="$(awk -F":" '/^data_parallel_degree[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
SP_DEGREE="$(awk -F":" '/^sequence_parallel_degree[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
ZERO_STAGE="$(awk -F":" '/^zero_stage[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
HIDDEN_DIM="$(awk -F":" '/^hidden_dim[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
NUM_LAYERS="$(awk -F":" '/^num_layers[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
NUM_ATTN_HEADS="$(awk -F":" '/^num_attention_heads[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
NUM_KV_HEADS="$(awk -F":" '/^num_kv_heads[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
INTERMEDIATE_DIM="$(awk -F":" '/^intermediate_dim[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"
VOCAB_SIZE="$(awk -F":" '/^vocab_size[[:space:]]*:/ {gsub(/ /, "", $2); print $2; exit}' "$CONFIG" || true)"

if [[ -z "$MICRO_BATCH" ]]; then MICRO_BATCH=8; fi
if [[ -z "$SEQ_LEN" ]]; then SEQ_LEN=16; fi
if [[ -z "$LR" ]]; then LR=0.00015; fi
if [[ -z "$WARMUP_STEPS" ]]; then WARMUP_STEPS=128; fi
if [[ -z "$MIN_LR" ]]; then MIN_LR=0.00003; fi
if [[ -z "$WEIGHT_DECAY" ]]; then WEIGHT_DECAY=0.1; fi
if [[ -z "$DATASET_MANIFEST" ]]; then DATASET_MANIFEST="data/pretrain/mini_manifest.json"; fi
if [[ -z "$OUTPUT_DIR" ]]; then OUTPUT_DIR="artifacts/checkpoints/run_20260518_001"; fi
if [[ -z "$CHECKPOINT_ROOT" ]]; then CHECKPOINT_ROOT="$OUTPUT_DIR"; fi
if [[ -z "$LOG_INTERVAL" ]]; then LOG_INTERVAL=8; fi
if [[ -z "$EVAL_INTERVAL" ]]; then EVAL_INTERVAL=16; fi
if [[ -z "$SAVE_INTERVAL" ]]; then SAVE_INTERVAL=32; fi
if [[ -z "$TP_DEGREE" ]]; then TP_DEGREE=4; fi
if [[ -z "$PP_DEGREE" ]]; then PP_DEGREE=2; fi
if [[ -z "$DP_DEGREE" ]]; then DP_DEGREE=1; fi
if [[ -z "$SP_DEGREE" ]]; then SP_DEGREE=1; fi
if [[ -z "$ZERO_STAGE" ]]; then ZERO_STAGE=2; fi
if [[ -z "$HIDDEN_DIM" ]]; then HIDDEN_DIM=128; fi
if [[ -z "$NUM_LAYERS" ]]; then NUM_LAYERS=4; fi
if [[ -z "$NUM_ATTN_HEADS" ]]; then NUM_ATTN_HEADS=8; fi
if [[ -z "$NUM_KV_HEADS" ]]; then NUM_KV_HEADS=2; fi
if [[ -z "$INTERMEDIATE_DIM" ]]; then INTERMEDIATE_DIM=512; fi
if [[ -z "$VOCAB_SIZE" ]]; then VOCAB_SIZE=4096; fi

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

use neurx.workflows.llm.pretrain.run.pipeline_runner.{run_pretrain_with_config}
use neurx.workflows.llm.pretrain.run.pipeline_runner.{run_pretrain_with_distributed_config}

func main() int {
  run_pretrain_with_distributed_config(${MICRO_BATCH}, ${SEQ_LEN}, ${LR}, ${MAX_STEPS}, ${WARMUP_STEPS}, ${MIN_LR}, ${WEIGHT_DECAY}, ${LOG_INTERVAL}, ${EVAL_INTERVAL}, ${SAVE_INTERVAL}, "${DATASET_MANIFEST}", "${CHECKPOINT_ROOT}", ${TP_DEGREE}, ${PP_DEGREE}, ${DP_DEGREE}, ${SP_DEGREE}, ${ZERO_STAGE}, ${HIDDEN_DIM}, ${NUM_LAYERS}, ${NUM_ATTN_HEADS}, ${NUM_KV_HEADS}, ${INTERMEDIATE_DIM}, ${VOCAB_SIZE})
  0
}
SFILE

# Compile the tmp S file only; the workflow runner now drives the 2T runtime and
# rank-sharded checkpoint path directly.
s "$TMP_S" "$TMP_IR"

echo "Compiled pretrain workflow entrypoint with steps=${MAX_STEPS}, micro_batch=${MICRO_BATCH}, seq_len=${SEQ_LEN}, lr=${LR}, model=${HIDDEN_DIM}h/${NUM_LAYERS}l/${NUM_ATTN_HEADS}q/${NUM_KV_HEADS}kv/${INTERMEDIATE_DIM}ff/${VOCAB_SIZE}v, log/eval/save=${LOG_INTERVAL}/${EVAL_INTERVAL}/${SAVE_INTERVAL}, manifest=${DATASET_MANIFEST}, checkpoint_root=${CHECKPOINT_ROOT}, tp/pp/dp/sp/zero=${TP_DEGREE}/${PP_DEGREE}/${DP_DEGREE}/${SP_DEGREE}/${ZERO_STAGE}"
