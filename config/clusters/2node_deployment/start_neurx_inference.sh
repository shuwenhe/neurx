#!/bin/bash

# NeurX Inference Service Launcher - S Native Edition
# 使用 S 编译的原生推理引擎（如果可用），否则回到优化的 Python 实现

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(dirname $(dirname $(dirname "$SCRIPT_DIR")))"

echo "🚀 NeurX S-Native Inference Service Launcher"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 检查环境配置
if [ -f "$SCRIPT_DIR/controller.env" ] && [ "$(basename $(pwd))" != "2node_deployment" ]; then
    echo "📋 Loading controller configuration..."
    source "$SCRIPT_DIR/controller.env"
elif [ -f "$SCRIPT_DIR/worker_rank0.env" ] && [ "$(basename $(pwd))" != "2node_deployment" ]; then
    echo "📋 Loading worker configuration..."
    source "$SCRIPT_DIR/worker_rank0.env"
fi

# 2. 设置默认值
export NEURX_ROLE=${NEURX_ROLE:-controller}
export NEURX_PORT=${NEURX_PORT:-8000}
export NEURX_MODEL_NAME=${NEURX_MODEL_NAME:-"Qwen/Qwen2.5-0.5B-Instruct"}

# 3. 检查 S 编译器和推理引擎可用性
echo "🔍 Checking S inference engine availability..."
echo ""

# 检查 S IR runner
if [ -f "$NEURX_ROOT/build/s_ir_runner" ]; then
    echo "✓ S IR runner found: $NEURX_ROOT/build/s_ir_runner"
    export S_IR_RUNNER="$NEURX_ROOT/build/s_ir_runner"
    export USE_S_INFERENCE=auto
else
    echo "⚠️  S IR runner not found, will use Python implementation"
    export USE_S_INFERENCE=false
fi

# 检查 Python 环境
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Role: $NEURX_ROLE"
echo "  Model: $NEURX_MODEL_NAME"
echo "  Port: $NEURX_PORT"
echo "  S Inference: ${USE_S_INFERENCE:=auto}"
echo ""

# 4. 启动推理服务
echo "🚀 Starting NeurX Inference Service..."
echo ""

cd "$SCRIPT_DIR"
exec python3 neurx_inference_s.py
