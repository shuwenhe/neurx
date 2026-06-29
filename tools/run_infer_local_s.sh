#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# s/ is located at train/s relative to the neurx directory
S_ROOT="$(cd "$NEURX_DIR/../s" && pwd)"
BUILD_DIR="$NEURX_DIR/build"
SOURCE_FILE="$NEURX_DIR/tools/infer_llm_checkpoint.s"
IR_FILE="$BUILD_DIR/infer_llm.ir"
RUNNER_BIN="$BUILD_DIR/s_ir_runner_infer"

mkdir -p "$BUILD_DIR"

if [[ "${NEURX_INFER_SKIP_BUILD:-0}" != "1" ]]; then
  cd "$S_ROOT"
  LATEST_COMPILER="$($S_ROOT/bin/build_s_arm64.sh)"
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
fi

echo "Running S inference runner"
NEURX_INFER_CHECKPOINT="${1:-}" NEURX_INFER_SEED="${2:-neurx }" NEURX_INFER_MAX_NEW_CHARS="${3:-120}" "$RUNNER_BIN" "$IR_FILE"
