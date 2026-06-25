#!/bin/bash

set -euo pipefail

NEURX_DIR="${NEURX_DIR:-/app/train/neurx}"
S_ROOT="${S_ROOT:-/app/train/s}"
# default SOURCE_FILE moved to repo root (was $NEURX_DIR/src/train_model.s before restructuring)
SOURCE_FILE="${SOURCE_FILE:-$NEURX_DIR/train_model.s}"
IR_FILE="${IR_FILE:-$NEURX_DIR/build/train_model.ir}"
RUNNER_BIN="${RUNNER_BIN:-$NEURX_DIR/build/s_ir_runner}"

mkdir -p "$NEURX_DIR/build"

if [ ! -f "$IR_FILE" ]; then
    echo "IR not found, compiling source first..."
    cd "$S_ROOT"
    ./bin/s "$SOURCE_FILE" "$IR_FILE"
fi

echo "Building standalone IR runner..."
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

if [ "${EVAL_OUTPUT_COMMAND:-0}" = "1" ]; then
    echo "Running $IR_FILE and evaluating emitted command ..."
    COMMAND="$("$RUNNER_BIN" "$IR_FILE")"
    if [ -z "$COMMAND" ]; then
        echo "IR program emitted an empty command"
        exit 1
    fi
    echo "$COMMAND"
    eval "$COMMAND"
else
    echo "Running $IR_FILE ..."
    "$RUNNER_BIN" "$IR_FILE"
fi
