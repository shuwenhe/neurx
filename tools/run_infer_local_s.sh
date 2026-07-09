#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# s/ lives alongside the repo workspace, not under train/
S_ROOT="$(cd "$NEURX_DIR/../../../s" && pwd)"
BUILD_DIR="$NEURX_DIR/build"
SOURCE_FILE="$NEURX_DIR/tools/infer_llm_checkpoint.s"
IR_FILE="$BUILD_DIR/infer_llm.ir"
RUNNER_BIN="$NEURX_DIR/artifacts/build/s_runner/s_ir_runner"
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
  make build-s-ir-runner
fi

echo "Running S inference runner"
echo "  checkpoint   : ${1:-<empty>}"
echo "  seed         : ${2:-neurx }"
echo "  max_new      : ${3:-120}"
echo "  exec         : S_IR_RUNNER_INPUT=\"$IR_FILE\" S_IR_RUNNER_ENTRY=main \"$RUNNER_BIN\""
S_IR_RUNNER_INPUT="$IR_FILE" S_IR_RUNNER_ENTRY=main "$RUNNER_BIN"
