#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export NEURX_ROOT="$NEURX_ROOT"

# Bridge the `make train` entry point to the real launcher instead of the
# S status wrapper. Keep the existing environment contract from Makefile and
# translate it to the launcher variables this script understands.
export NEURX_PRETRAIN_MANIFEST="${NEURX_PRETRAIN_MANIFEST:-$NEURX_ROOT/dataset/pretrain/manifest.json}"
export NEURX_PRETRAIN_DATASET="${NEURX_PRETRAIN_DATASET:-${NEURX_TRAIN_SPLIT_PATH:-$NEURX_ROOT/dataset/pretrain/cleaned/train.jsonl}}"
export NEURX_PRETRAIN_OUTPUT="${NEURX_PRETRAIN_OUTPUT:-$NEURX_ROOT/artifacts/checkpoints/llm_training}"
export NEURX_PRETRAIN_STEPS="${NEURX_PRETRAIN_STEPS:-${NEURX_TOTAL_STEPS:-1000}}"
export NEURX_PRETRAIN_WARMUP_STEPS="${NEURX_PRETRAIN_WARMUP_STEPS:-${NEURX_WARMUP_STEPS:-100}}"
export NEURX_PRETRAIN_BATCH_SIZE="${NEURX_PRETRAIN_BATCH_SIZE:-${NEURX_BATCH_SIZE:-32}}"
export NEURX_PRETRAIN_SEQ_LENGTH="${NEURX_PRETRAIN_SEQ_LENGTH:-${NEURX_SEQ_LENGTH:-2048}}"
export NEURX_PRETRAIN_LR="${NEURX_PRETRAIN_LR:-${NEURX_LR:-0.0002}}"
export NEURX_PRETRAIN_CKPT_INTERVAL="${NEURX_PRETRAIN_CKPT_INTERVAL:-${NEURX_CHECKPOINT_INTERVAL:-500}}"

echo "Launching NeurX large-model pretraining..."
echo "  manifest : $NEURX_PRETRAIN_MANIFEST"
echo "  dataset   : $NEURX_PRETRAIN_DATASET"
echo "  output    : $NEURX_PRETRAIN_OUTPUT"
echo "  steps     : $NEURX_PRETRAIN_STEPS"
echo "  batch     : $NEURX_PRETRAIN_BATCH_SIZE"
echo ""

# Use S implementation for faster training pipeline
export NEURX_ROOT="$NEURX_ROOT"
exec "$S_COMPILER" script/run_large_pretrain.s 2>&1 | head -1000
