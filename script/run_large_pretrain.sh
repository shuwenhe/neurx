#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export NEURX_ROOT="$NEURX_ROOT"

export S_SOURCE_ROOT="${S_SOURCE_ROOT:-$NEURX_ROOT/../s}"
if [ -z "${S_COMPILER:-}" ]; then
    if [ -x "$NEURX_ROOT/../s/.local/bin/s" ]; then
        export S_COMPILER="$NEURX_ROOT/../s/.local/bin/s"
    elif [ -x "$NEURX_ROOT/../s/bin/s" ]; then
        export S_COMPILER="$NEURX_ROOT/../s/bin/s"
    else
        export S_COMPILER="$(command -v s 2>/dev/null || true)"
    fi
fi
export S_RUNNER_BIN="${S_RUNNER_BIN:-$NEURX_ROOT/artifacts/build/s_runner/s_ir_runner}"

# Bridge the `make train` entry point to the real launcher. Keep the existing
# Makefile contract, but translate legacy variable names to the ones the
# pretraining backend actually reads.
export MODEL_SIZE="${MODEL_SIZE:-1t}"
export NEURX_PRETRAIN_MANIFEST="${NEURX_PRETRAIN_MANIFEST:-$NEURX_ROOT/dataset/pretrain/manifest.json}"
export NEURX_PRETRAIN_OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT_DIR:-${NEURX_PRETRAIN_OUTPUT:-$NEURX_ROOT/artifacts/checkpoints/llm_training}}"
export NEURX_PRETRAIN_MICRO_BATCH="${NEURX_PRETRAIN_MICRO_BATCH:-${NEURX_PRETRAIN_BATCH_SIZE:-${NEURX_BATCH_SIZE:-32}}}"
export NEURX_PRETRAIN_SEQ_LEN="${NEURX_PRETRAIN_SEQ_LEN:-${NEURX_SEQ_LENGTH:-2048}}"
export NEURX_PRETRAIN_STEPS="${NEURX_PRETRAIN_STEPS:-${NEURX_TOTAL_STEPS:-1000}}"
export NEURX_PRETRAIN_WARMUP_STEPS="${NEURX_PRETRAIN_WARMUP_STEPS:-${NEURX_WARMUP_STEPS:-100}}"
export NEURX_PRETRAIN_MIN_LR="${NEURX_PRETRAIN_MIN_LR:-${NEURX_MIN_LR:-0.00002}}"
export NEURX_PRETRAIN_LR="${NEURX_PRETRAIN_LR:-${NEURX_LR:-0.0002}}"
export NEURX_PRETRAIN_WEIGHT_DECAY="${NEURX_PRETRAIN_WEIGHT_DECAY:-${NEURX_WEIGHT_DECAY:-0.1}}"
export NEURX_PRETRAIN_LOG_INTERVAL="${NEURX_PRETRAIN_LOG_INTERVAL:-${NEURX_LOG_INTERVAL:-10}}"
export NEURX_PRETRAIN_EVAL_INTERVAL="${NEURX_PRETRAIN_EVAL_INTERVAL:-${NEURX_EVAL_INTERVAL:-50}}"
export NEURX_PRETRAIN_SAVE_INTERVAL="${NEURX_PRETRAIN_SAVE_INTERVAL:-${NEURX_SAVE_INTERVAL:-100}}"
export NEURX_PRETRAIN_RESUME="${NEURX_PRETRAIN_RESUME:-1}"
export NEURX_ALLOW_FULL_1T_LOCAL="${NEURX_ALLOW_FULL_1T_LOCAL:-1}"
export WORLD_SIZE="${WORLD_SIZE:-${NEURX_PRETRAIN_WORLD_SIZE:-${NEURX_WORLD_SIZE:-1}}}"
export RANK="${RANK:-${NEURX_PRETRAIN_RANK:-0}}"
export DDP_BACKEND="${DDP_BACKEND:-${NEURX_PRETRAIN_BACKEND:-gloo}}"

echo "Launching NeurX large-model pretraining..."
echo "  manifest : $NEURX_PRETRAIN_MANIFEST"
echo "  output    : $NEURX_PRETRAIN_OUTPUT_DIR"
echo "  world size: $WORLD_SIZE"
echo "  backend   : $DDP_BACKEND"
echo "  steps     : $NEURX_PRETRAIN_STEPS"
echo "  batch     : $NEURX_PRETRAIN_MICRO_BATCH"
echo ""

# Compile S script to IR
BUILD_DIR="$NEURX_ROOT/artifacts/build/run_large_pretrain"
LOG_DIR="$NEURX_ROOT/artifacts/logs"
mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"

echo "Compiling S training pipeline..."
cd "$NEURX_ROOT"
if [ -z "$S_COMPILER" ]; then
    echo "Error: S compiler not found"
    exit 1
fi
"$S_COMPILER" ir 'script/run_large_pretrain.s' -o "$BUILD_DIR/run_large_pretrain.ir" 2>&1
test -f "$BUILD_DIR/run_large_pretrain.ir" || exit 1

echo "Running training pipeline..."
# Use S IR runner to execute compiled IR
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "S IR runner not found at $S_RUNNER_BIN; building it now..."
    make -C "$NEURX_ROOT" build-s-ir-runner
fi
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "Error: S IR runner not found at $S_RUNNER_BIN"
    exit 1
fi
RUN_LOG="$LOG_DIR/run_large_pretrain_$(date +%Y%m%d_%H%M%S).log"
echo "Real training log: $RUN_LOG"
if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL "$S_RUNNER_BIN" "$BUILD_DIR/run_large_pretrain.ir" 2>&1 | tee -a "$RUN_LOG"
else
    "$S_RUNNER_BIN" "$BUILD_DIR/run_large_pretrain.ir" 2>&1 | tee -a "$RUN_LOG"
fi
