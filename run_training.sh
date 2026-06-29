#!/bin/bash

set -euo pipefail

# Usage:
#   bash run_training.sh
#   NEURX_S_PRETRAIN_STEPS=3 NEURX_S_PRETRAIN_WARMUP_STEPS=2 bash run_training.sh
#   NEURX_S_PRETRAIN_OUTPUT_DIR=/tmp/neurx_ckpt bash run_training.sh
#
# Environment variables:
#   NEURX_S_PRETRAIN_STEPS         default: 50
#   NEURX_S_PRETRAIN_WARMUP_STEPS  default: 10
#   NEURX_S_PRETRAIN_OUTPUT_DIR    default: artifacts/checkpoints/llm_s_pretrain

NEURX_DIR="$(cd "$(dirname "$0")" && pwd)"
S_PRETRAIN_RUNNER="$NEURX_DIR/run_s_pretrain.sh"

echo "======================================================================="
echo "NeurX 深度学习框架 - Real Training Entry"
echo "======================================================================="
echo ""

echo "✓ 使用 NeurX S 训练流程..."
echo "  训练入口: $S_PRETRAIN_RUNNER"
echo ""

exec bash "$S_PRETRAIN_RUNNER" "$@"
