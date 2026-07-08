#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# s/ lives alongside the repo workspace, not under train/
S_ROOT="$(cd "$NEURX_DIR/../../../s" && pwd)"
BUILD_DIR="$NEURX_DIR/build"
SOURCE_FILE="$NEURX_DIR/tools/infer_llm_checkpoint.s"
IR_FILE="$BUILD_DIR/infer_llm.ir"
RUNNER_BIN="$BUILD_DIR/s_ir_runner_infer"
HOST_ARCH="$(uname -m)"

if [[ -n "${S_COMPILER_BUILDER:-}" ]]; then
  COMPILER_BUILDER="$S_COMPILER_BUILDER"
elif [[ "$HOST_ARCH" == "x86_64" || "$HOST_ARCH" == "amd64" ]]; then
  COMPILER_BUILDER="$S_ROOT/bin/build_s_x86_64.sh"
else
  COMPILER_BUILDER="$S_ROOT/bin/build_s_arm64.sh"
fi

mkdir -p "$BUILD_DIR"

echo "Building local S inference runner"
echo "  project root : $NEURX_DIR"
echo "  S root       : $S_ROOT"
echo "  compiler bin : $COMPILER_BUILDER"
echo "  source file  : $SOURCE_FILE"
echo "  IR output    : $IR_FILE"
echo "  runner bin   : $RUNNER_BIN"

if [[ "${NEURX_INFER_SKIP_BUILD:-0}" != "1" ]]; then
  cd "$S_ROOT"
  LATEST_COMPILER="$(bash "$COMPILER_BUILDER")"
  echo "  latest compiler: $LATEST_COMPILER"
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
echo "  checkpoint   : ${1:-<empty>}"
echo "  seed         : ${2:-neurx }"
echo "  max_new      : ${3:-120}"
echo "  exec         : NEURX_INFER_CHECKPOINT=\"${1:-}\" NEURX_INFER_SEED=\"${2:-neurx }\" NEURX_INFER_MAX_NEW_CHARS=\"${3:-120}\" \"$RUNNER_BIN\" \"$IR_FILE\""
NEURX_INFER_CHECKPOINT="${1:-}" NEURX_INFER_SEED="${2:-neurx }" NEURX_INFER_MAX_NEW_CHARS="${3:-120}" "$RUNNER_BIN" "$IR_FILE"
