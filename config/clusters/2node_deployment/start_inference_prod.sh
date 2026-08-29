#!/bin/bash

# NeurX Distributed Inference Service - Production Launcher
# 启动原生 S 推理服务或 Python 优化实现

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(dirname $(dirname $(dirname "$SCRIPT_DIR")))"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NeurX Distributed Inference Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 加载配置
if [ -f "$SCRIPT_DIR/controller.env" ]; then
    source "$SCRIPT_DIR/controller.env"
    echo "✓ Loaded controller configuration"
elif [ -f "$SCRIPT_DIR/worker_rank0.env" ]; then
    source "$SCRIPT_DIR/worker_rank0.env"
    echo "✓ Loaded worker configuration"
fi

echo ""

# 设置默认值
export NEURX_ROLE=${NEURX_ROLE:-controller}
export NEURX_PORT=${NEURX_PORT:-8000}
export NEURX_MODEL_NAME=${NEURX_MODEL_NAME:-"Qwen/Qwen2.5-0.5B-Instruct"}
export WORLD_SIZE=${WORLD_SIZE:-2}
export RANK=${RANK:-0}

# 检查 S IR Runner
echo "🔍 Checking S inference engine..."
if [ -f "/app/neurx/build/s_ir_runner" ]; then
    export S_IR_RUNNER="/app/neurx/build/s_ir_runner"
    export USE_S_IR="true"
    echo "✓ S IR Runner found: $S_IR_RUNNER"
    echo "  Backend: S-IR-Native"
else
    export USE_S_IR="false"
    echo "✓ S IR Runner not found, using Python"
    echo "  Backend: Python-Optimized"
fi

echo ""
echo "Configuration:"
echo "  Role:        $NEURX_ROLE"
echo "  Rank:        $RANK / $WORLD_SIZE"
echo "  Model:       $NEURX_MODEL_NAME"
echo "  Port:        $NEURX_PORT"
echo ""

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found"
    exit 1
fi

echo "🚀 Starting inference service..."
echo ""

# 启动推理服务
cd "$SCRIPT_DIR"
exec python3 neurx_inference_prod.py
