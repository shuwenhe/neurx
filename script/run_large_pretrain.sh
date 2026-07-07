#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "════════════════════════════════════════════════════════════"
echo "🚀 NeurX Large Model Pre-training Pipeline"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Project root: $NEURX_ROOT"
echo "Configuration: Large LLM (1T MoE)"
echo ""

# Verify data preparation
echo "Step 1: Verifying data preparation..."
if [ ! -f "$NEURX_ROOT/dataset/pretrain/manifest.json" ]; then
    echo "❌ Error: manifest.json not found"
    echo "Please run: bash script/clean_data.sh && bash script/generate_shards.sh"
    exit 1
fi
echo "✅ Data preparation verified"
echo ""

# Setup S compiler environment
S_COMPILER="${S_COMPILER:-/home/shuwen/.local/bin/s}"
S_SOURCE_ROOT="${S_SOURCE_ROOT:-/home/shuwen/shuwen/train/s}"

if [ ! -f "$S_COMPILER" ]; then
    echo "❌ Error: S compiler not found at $S_COMPILER"
    exit 1
fi

export S_COMPILER="$S_COMPILER"
export S_SOURCE_ROOT="$S_SOURCE_ROOT"

echo "Step 2: Compiling training entry point..."
BUILD_DIR="$NEURX_ROOT/artifacts/build/pretrain_training"
mkdir -p "$BUILD_DIR"

cd "$NEURX_ROOT"
echo "Compiling entry_main.s to IR..."
"$S_COMPILER" ir pretrain/llm/entry_main.s -o "$BUILD_DIR/training.ir" 2>&1 && \
test -f "$BUILD_DIR/training.ir" || {
    echo "❌ Compilation failed or output file not created"
    exit 1
}
echo "✅ Compilation successful: $BUILD_DIR/training.ir"
echo ""

# Build S IR runner
echo "Step 3: Building S IR runner..."
make -C "$NEURX_ROOT" build-s-ir-runner >/dev/null 2>&1 || {
    echo "❌ Failed to build S IR runner"
    exit 1
}
echo "✅ S IR runner ready"
echo ""

# Setup training environment variables  
export NEURX_ROOT="$NEURX_ROOT"
export NEURX_PRETRAIN_MANIFEST="$NEURX_ROOT/dataset/pretrain/manifest.json"
export NEURX_TRAIN_SPLIT_PATH="$NEURX_ROOT/dataset/pretrain/cleaned/train.jsonl"
export NEURX_VAL_SPLIT_PATH="$NEURX_ROOT/dataset/pretrain/cleaned/val.jsonl"
export NEURX_TEST_SPLIT_PATH="$NEURX_ROOT/dataset/pretrain/cleaned/test.jsonl"
export NEURX_PRETRAIN_DATA_DIR="$NEURX_ROOT/dataset/pretrain"
export NEURX_ALLOW_FULL_1T_LOCAL=1
export MODEL_SIZE=1t

# Run training
echo "Step 4: Launching training..."
echo "════════════════════════════════════════════════════════════"

S_RUNNER_BIN="${NEURX_ROOT}/artifacts/build/s_runner/s_ir_runner"
if [ ! -f "$S_RUNNER_BIN" ]; then
    echo "❌ Error: S IR runner not found at $S_RUNNER_BIN"
    exit 1
fi

echo "Starting training with S IR runner..."
echo ""

# Run the training with logging
LOG_DIR="$NEURX_ROOT/artifacts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/train_$(date +%Y%m%d_%H%M%S).log"

cd "$NEURX_ROOT"
"$S_RUNNER_BIN" "$BUILD_DIR/training.ir" 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Training completed. Logs saved to: $LOG_FILE"
echo "════════════════════════════════════════════════════════════"
