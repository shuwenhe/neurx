#!/bin/bash

# NeurX GPU-Ready Distributed Inference Service Launcher
# 支持 GPU 推理，带 CPU 自动降级

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(dirname $(dirname $(dirname "$SCRIPT_DIR")))"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 NeurX GPU-Ready Distributed Inference Service"
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
export NEURX_USE_GPU=${NEURX_USE_GPU:-auto}  # auto, true, false
export NEURX_GPU_DEVICE=${NEURX_GPU_DEVICE:-0}

# 检查 GPU 可用性
echo "🔍 Detecting GPU hardware..."
if command -v nvidia-smi &> /dev/null; then
    GPU_COUNT=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
    echo "✓ NVIDIA CUDA detected: $GPU_COUNT GPU(s)"
    export NEURX_USE_GPU="true"
else
    echo "✓ No NVIDIA GPU found (CPU-only mode)"
    export NEURX_USE_GPU="false"
fi

# 检查 S IR Runner
echo ""
echo "🔍 Checking S inference engine..."
if [ -f "/app/neurx/build/s_ir_runner" ]; then
    export S_IR_RUNNER="/app/neurx/build/s_ir_runner"
    export USE_S_IR="true"
    echo "✓ S IR Runner found: $S_IR_RUNNER"
else
    export USE_S_IR="false"
    echo "✓ S IR Runner not found, using Python"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Role:          $NEURX_ROLE"
echo "  Rank:          $RANK / $WORLD_SIZE"
echo "  Model:         $NEURX_MODEL_NAME"
echo "  Port:          $NEURX_PORT"
echo "  GPU Mode:      $NEURX_USE_GPU"
if [ "$NEURX_USE_GPU" = "true" ]; then
    echo "  GPU Device:    $NEURX_GPU_DEVICE"
fi
echo "  S IR:          $USE_S_IR"
echo ""

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found"
    exit 1
fi

echo "🚀 Starting GPU-Ready inference service..."
echo ""

# 启动推理服务
cd "$SCRIPT_DIR"
exec python3 neurx_inference_gpu_ready.py
