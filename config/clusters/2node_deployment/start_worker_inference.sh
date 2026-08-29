#!/bin/bash
# Start Worker Inference Service on 192.168.10.75
# CPU-Only Mode (GPU Not Available)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(dirname $(dirname $(dirname "$SCRIPT_DIR")))"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NeurX Worker Inference Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Load worker configuration
if [ -f "$SCRIPT_DIR/worker_rank0.env" ]; then
    source "$SCRIPT_DIR/worker_rank0.env"
    echo "✓ Loaded worker configuration"
else
    echo "⚠️  Worker config not found, using defaults"
    export NEURX_ROLE="worker"
    export NEURX_PORT=8000
    export NEURX_MODEL_NAME="Qwen/Qwen2.5-0.5B-Instruct"
    export WORLD_SIZE=2
    export RANK=1
fi

echo ""

# 设置 CPU-only 模式
export CUDA_VISIBLE_DEVICES="-1"
export NEURX_USE_GPU="false"

echo "Configuration:"
echo "  Role:        ${NEURX_ROLE:-worker}"
echo "  Rank:        ${RANK:-1} / ${WORLD_SIZE:-2}"
echo "  Model:       ${NEURX_MODEL_NAME:-Qwen/Qwen2.5-0.5B-Instruct}"
echo "  Port:        ${NEURX_PORT:-8000}"
echo "  Mode:        CPU-Only (GPU Not Available)"
echo ""

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found"
    exit 1
fi

echo "🚀 Starting worker inference service..."
echo ""

# 启动推理服务
cd "$SCRIPT_DIR"
exec python3 neurx_inference_gpu_ready.py
