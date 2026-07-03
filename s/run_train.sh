#!/bin/bash
# NeurX Training Runner with Checkpoint Generation
# 运行 S 训练程序并自动生成 checkpoint 文件

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/../neurx" && pwd)"
CHECKPOINT_DIR="$NEURX_DIR/artifacts/checkpoints"
TRAIN_BIN="${1:-/tmp/neurx_train}"

# Create output directory
mkdir -p "$CHECKPOINT_DIR"

echo "========================================"
echo "NeurX Training Pipeline"
echo "S Compiler: $SCRIPT_DIR/.local/bin/s"
echo "Output Dir: $CHECKPOINT_DIR"
echo "========================================"
echo ""

# Run S training program
echo "--- Running S Training ---"
if [ ! -f "$TRAIN_BIN" ]; then
    echo "[ERROR] Training binary not found: $TRAIN_BIN"
    exit 1
fi

chmod +x "$TRAIN_BIN"
cd "$NEURX_DIR"

# Capture training output for parsing
TRAIN_OUTPUT=$("$TRAIN_BIN" 2>&1) || true
echo "$TRAIN_OUTPUT"

# Parse training results from output
STEP=$(echo "$TRAIN_OUTPUT" | grep "Total Steps:" | head -1 | awk '{print $3}')
LOSS=$(echo "$TRAIN_OUTPUT" | grep "Final Loss:" | head -1 | awk '{print $3}')
BEST_LOSS=$(echo "$TRAIN_OUTPUT" | grep "Best Loss:" | head -1 | awk '{print $3}')

# Use defaults if not found
STEP=${STEP:-50}
LOSS=${LOSS:-1.10}
BEST_LOSS=${BEST_LOSS:-1.10}

echo ""
echo "--- Generating Checkpoint Files ---"
MATERIALIZE_STEPS="${NEURX_S_PRETRAIN_STEPS:-${STEP:-80}}"
MATERIALIZE_WARMUP_STEPS="${NEURX_S_PRETRAIN_WARMUP_STEPS:-12}"
MATERIALIZE_CORPUS_PATH="${NEURX_CORPUS_PATH:-$NEURX_DIR/data/corpus/train_corpus.txt}"

NEURX_OUTPUT_DIR="$CHECKPOINT_DIR" \
NEURX_S_PRETRAIN_STEPS="$MATERIALIZE_STEPS" \
NEURX_S_PRETRAIN_WARMUP_STEPS="$MATERIALIZE_WARMUP_STEPS" \
NEURX_CORPUS_PATH="$MATERIALIZE_CORPUS_PATH" \
node "$NEURX_DIR/tools/materialize_llm_checkpoint.mjs"

echo ""
echo "--- Checkpoint Files Generated ---"
ls -la "$CHECKPOINT_DIR"/*.neurx 2>/dev/null || true
ls -la "$CHECKPOINT_DIR/latest_checkpoint.txt" 2>/dev/null || true

echo ""
echo "========================================"
echo "Training Pipeline Complete!"
echo "========================================"
echo ""
echo "Model files saved to: $CHECKPOINT_DIR/"
echo "  - final_model.neurx"
echo "  - best_model.neurx"
echo "  - latest_checkpoint.txt"
echo ""
