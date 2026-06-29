#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
S_ROOT="$(cd "$NEURX_DIR/../s" && pwd)"
BUILD_DIR="$NEURX_DIR/build"
SOURCE_FILE="$SCRIPT_DIR/train_gpt_large.s"
IR_FILE="$BUILD_DIR/train_gpt_large.ir"
RUNNER_BIN="$BUILD_DIR/s_ir_runner_train_gpt_large"
OUTPUT_DIR="${NEURX_LLM_OUTPUT_DIR:-$NEURX_DIR/artifacts/checkpoints/model_llm_gpt_large}"
LOG_FILE="$OUTPUT_DIR/training.log"
FINAL_FILE="$OUTPUT_DIR/final_model.neurx"
BEST_FILE="$OUTPUT_DIR/best_model.neurx"
LATEST_FILE="$OUTPUT_DIR/latest_checkpoint.txt"
SUMMARY_FILE="$OUTPUT_DIR/training_summary.txt"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

if [[ "${NEURX_LLM_SKIP_BUILD:-0}" != "1" ]]; then
  COMPILER="$("$S_ROOT/bin/build_s_arm64.sh")"
  "$COMPILER" "$SOURCE_FILE" "$IR_FILE"

  cd "$NEURX_DIR"
  cc -std=c11 -O2 -Wall -Wextra -Werror -DSEED_COMPILE_ONLY \
    -I "$S_ROOT/src/cmd/compile/seed" \
    -o "$RUNNER_BIN" \
    "$NEURX_DIR/tools/s_ir_runner.c" \
    "$S_ROOT/src/cmd/compile/seed/runtime/runtime.c" \
    "$S_ROOT/src/cmd/compile/seed/error/error.c" \
    "$S_ROOT/src/cmd/compile/seed/code/native_backend.c" \
    "$S_ROOT/src/cmd/compile/seed/lexical/lexer.c" \
    "$S_ROOT/src/cmd/compile/seed/syntax/parser.c" \
    "$S_ROOT/src/cmd/compile/seed/semantic/analyzer.c" \
    "$S_ROOT/src/cmd/compile/seed/intermediate/ir.c" \
    "$S_ROOT/src/cmd/compile/seed/code/generator.c" \
    "$S_ROOT/src/cmd/compile/seed/bootstrap/bootstrap.c" \
    "$S_ROOT/src/cmd/compile/seed/s_seed.c"
fi

rm -f "$FINAL_FILE" "$BEST_FILE" "$LATEST_FILE" "$SUMMARY_FILE" "$LOG_FILE"

NEURX_DIR="$NEURX_DIR" \
S_ROOT="$S_ROOT" \
NEURX_LLM_OUTPUT_DIR="$OUTPUT_DIR" \
NEURX_LLM_BATCH_SIZE="${NEURX_LLM_BATCH_SIZE:-8}" \
NEURX_LLM_SEQ_LEN="${NEURX_LLM_SEQ_LEN:-16}" \
NEURX_LLM_STEPS="${NEURX_LLM_STEPS:-32}" \
NEURX_LLM_WARMUP_STEPS="${NEURX_LLM_WARMUP_STEPS:-8}" \
NEURX_LLM_LR="${NEURX_LLM_LR:-0.00015}" \
NEURX_LLM_MIN_LR="${NEURX_LLM_MIN_LR:-0.00003}" \
NEURX_LLM_WEIGHT_DECAY="${NEURX_LLM_WEIGHT_DECAY:-0.1}" \
NEURX_LLM_LOG_INTERVAL="${NEURX_LLM_LOG_INTERVAL:-8}" \
NEURX_LLM_EVAL_INTERVAL="${NEURX_LLM_EVAL_INTERVAL:-16}" \
NEURX_LLM_SAVE_INTERVAL="${NEURX_LLM_SAVE_INTERVAL:-32}" \
NEURX_LLM_VOCAB_SIZE="${NEURX_LLM_VOCAB_SIZE:-50257}" \
NEURX_LLM_HIDDEN_SIZE="${NEURX_LLM_HIDDEN_SIZE:-4096}" \
NEURX_LLM_NUM_HEADS="${NEURX_LLM_NUM_HEADS:-32}" \
NEURX_LLM_NUM_LAYERS="${NEURX_LLM_NUM_LAYERS:-32}" \
NEURX_LLM_INTERMEDIATE_SIZE="${NEURX_LLM_INTERMEDIATE_SIZE:-11008}" \
NEURX_LLM_MAX_SEQ_LEN="${NEURX_LLM_MAX_SEQ_LEN:-2048}" \
NEURX_LLM_RESUME="${NEURX_LLM_RESUME:-1}" \
  "$RUNNER_BIN" "$IR_FILE" | tee "$LOG_FILE"

awk -v final_file="$FINAL_FILE" -v best_file="$BEST_FILE" '
  /^CHECKPOINT_BEGIN final_model$/ { mode = "final"; next }
  /^CHECKPOINT_END final_model$/ { mode = ""; next }
  /^CHECKPOINT_BEGIN best_model$/ { mode = "best"; next }
  /^CHECKPOINT_END best_model$/ { mode = ""; next }
  mode == "final" { print > final_file; next }
  mode == "best" { print > best_file; next }
' "$LOG_FILE"

printf '%s\n' "$FINAL_FILE" > "$LATEST_FILE"
awk 'seen { print } /^Training Complete$/{ seen = 1 }' "$LOG_FILE" > "$SUMMARY_FILE"

echo "Wrote checkpoint: $FINAL_FILE"
echo "Wrote checkpoint: $BEST_FILE"
echo "Wrote manifest: $LATEST_FILE"
echo "Wrote summary: $SUMMARY_FILE"
