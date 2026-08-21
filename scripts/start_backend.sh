#!/bin/bash
# Start NeurX GPU Backend in background

set -e

export NEURX_ROOT="${1:-.}"
export NEURX_CHAT_MODEL_PATH="${2:-/model/Qwen2.5-VL-7B}"
export NEURX_INFER_DEVICE="gpu"
export NEURX_S_PORT="18084"

BACKEND_IR="${NEURX_ROOT}/artifacts/build/production_s_inference/gpu_backend.ir"
S_RUNNER="${NEURX_ROOT}/artifacts/build/s_runner/s_ir_runner"

# Kill old processes
pkill -9 -f "s_ir_runner.*gpu_backend" 2>/dev/null || true
pkill -9 -f "s_ir_runner.*cpu_backend" 2>/dev/null || true
sleep 2

# Start backend
echo "🚀 Starting NeurX GPU Backend on port 18084..."
nohup "$S_RUNNER" "$BACKEND_IR" >/tmp/neurx_gpu_backend.log 2>&1 &

# Wait for initialization
sleep 4

# Verify
if lsof -i :18084 2>/dev/null | grep -q LISTEN; then
    echo "✅ Backend is running on port 18084"
    echo "📋 Log: tail -f /tmp/neurx_gpu_backend.log"
    echo "🛑 Stop: make backend-stop"
    exit 0
else
    echo "❌ Backend failed. Check: tail /tmp/neurx_gpu_backend.log"
    tail -10 /tmp/neurx_gpu_backend.log
    exit 1
fi
