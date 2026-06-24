#!/bin/bash

set -euo pipefail

NEURX_DIR="/Users/feifei/train/neurx"
S_PRETRAIN_RUNNER="$NEURX_DIR/run_s_pretrain.sh"

echo "======================================================================="
echo "NeurX 深度学习框架 - Real Training Entry"
echo "======================================================================="
echo ""

echo "✓ 使用 NeurX S 训练流程..."
echo "  训练入口: $S_PRETRAIN_RUNNER"
echo ""

exec bash "$S_PRETRAIN_RUNNER" "$@"
