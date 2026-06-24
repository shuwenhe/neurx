#!/bin/bash

set -euo pipefail

NEURX_DIR="/Users/feifei/train/neurx"
S_ROOT="/Users/feifei/train/s"
BUILD_DIR="$NEURX_DIR/build"
OUTPUT_DIR="${NEURX_S_PRETRAIN_OUTPUT_DIR:-$NEURX_DIR/artifacts/checkpoints/llm_s_pretrain}"
SOURCE_FILE="$NEURX_DIR/train_llm.s"
IR_FILE="$BUILD_DIR/train_llm.ir"
RUNNER_BIN="$BUILD_DIR/s_ir_runner_pretrain"

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$S_ROOT"
LATEST_COMPILER="$(./bin/build_s_arm64.sh)"
"$LATEST_COMPILER" "$SOURCE_FILE" "$IR_FILE"

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

echo "======================================================================="
echo "NeurX S Pretrain Runner"
echo "======================================================================="
echo "Source: $SOURCE_FILE"
echo "IR: $IR_FILE"
echo "Output Dir: $OUTPUT_DIR"
echo "======================================================================="
echo ""

set +e
TRAIN_OUTPUT="$("$RUNNER_BIN" "$IR_FILE" 2>&1)"
STATUS=$?
set -e
echo "$TRAIN_OUTPUT"
if [ "$STATUS" -ne 0 ]; then
    exit "$STATUS"
fi

NEURX_OUTPUT_DIR="$OUTPUT_DIR" node "$NEURX_DIR/tools/materialize_llm_checkpoint.mjs"

STEP="$(printf '%s\n' "$TRAIN_OUTPUT" | awk -F': ' '/^Total Steps:/ {print $2; exit}' | tr -d '[:space:]')"
LOSS="$(printf '%s\n' "$TRAIN_OUTPUT" | awk -F': ' '/^Final Loss:/ {print $2; exit}' | tr -d '[:space:]')"
BEST_LOSS="$(printf '%s\n' "$TRAIN_OUTPUT" | awk -F': ' '/^Best Loss:/ {print $2; exit}' | tr -d '[:space:]')"
TOKENS="$(printf '%s\n' "$TRAIN_OUTPUT" | awk -F': ' '/^Tokens Processed:/ {print $2; exit}' | tr -d '[:space:]')"

STEP="${STEP:-800}"
LOSS="${LOSS:-1.0000}"
BEST_LOSS="${BEST_LOSS:-1.0000}"
TOKENS="${TOKENS:-0}"

echo ""
echo "Training Pipeline Complete!"
echo "Model files saved to: $OUTPUT_DIR"
echo "  - final_model.neurx"
echo "  - best_model.neurx"
echo "  - latest_checkpoint.txt"
