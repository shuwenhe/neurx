#!/bin/bash

set -e

NEURX_HOME="${NEURX_HOME:-/app/neurx}"
NEURX_MODEL_DIR="${NEURX_MODEL_DIR:-/models/default}"
NEURX_INFER_DEVICE="${NEURX_INFER_DEVICE:-cpu}"
NEURX_S_PORT="${NEURX_S_PORT:-8000}"
NEURX_S_HOST="${NEURX_S_HOST:-0.0.0.0}"
NEURX_CPU_THREADS="${NEURX_CPU_THREADS:-4}"
NEURX_CHAT_MAX_NEW_TOKENS="${NEURX_CHAT_MAX_NEW_TOKENS:-512}"
S_RUNNER="${NEURX_HOME}/artifacts/build/s_runner/s_ir_runner"
PRODUCTION_CHAT_IR="${NEURX_HOME}/artifacts/build/production_s_inference/production_chat.ir"
PRODUCTION_GPU_BACKEND_IR="${NEURX_HOME}/artifacts/build/production_s_inference/gpu_backend_enhanced.ir"
PRODUCTION_CPU_BACKEND_IR="${NEURX_HOME}/artifacts/build/production_s_inference/cpu_backend.ir"
CHAT_CLIENT_IR="${NEURX_HOME}/artifacts/build/production_s_inference/chat_client.ir"
WAIT_BACKEND_READY_IR="${NEURX_HOME}/artifacts/build/production_s_inference/wait_backend_ready.ir"
GPU_BACKEND_PORT="${NEURX_S_PORT}"

log_info() {
    echo "[INFO] $@" >&2
}

log_error() {
    echo "[ERROR] $@" >&2
}

log_success() {
    echo "[✓] $@" >&2
}

check_requirements() {
    log_info "Checking NeurX runtime requirements..."
    
    if [ ! -f "$S_RUNNER" ]; then
        log_error "S IR Runner not found at: $S_RUNNER"
        exit 1
    fi
    
    if [ ! -f "$PRODUCTION_CHAT_IR" ]; then
        log_error "Production Chat IR not found at: $PRODUCTION_CHAT_IR"
        exit 1
    fi
    
    if [ ! -d "$NEURX_MODEL_DIR" ]; then
        log_error "Model directory not found at: $NEURX_MODEL_DIR"
        log_info "Expected model weights in: $NEURX_MODEL_DIR"
        exit 1
    fi
    
    if [ ! -f "$NEURX_MODEL_DIR/model.safetensors" ] && [ ! -f "$NEURX_MODEL_DIR/model.safetensors.index.json" ]; then
        log_error "Model weights not found at: $NEURX_MODEL_DIR"
        log_info "Expected: model.safetensors or model.safetensors.index.json"
        exit 1
    fi
    
    log_success "All requirements met"
}

download_model() {
    local model_name="$1"
    local model_path="$2"
    
    if [ -f "$model_path/model.safetensors" ] || [ -f "$model_path/model.safetensors.index.json" ]; then
        log_info "Model already exists at: $model_path"
        return 0
    fi
    
    log_info "Downloading model: $model_name from Hugging Face..."
    mkdir -p "$model_path"
    
    if python3 -c "import huggingface_hub" 2>/dev/null; then
        log_info "Using Python huggingface_hub library..."
        python3 << EOF
from huggingface_hub import snapshot_download
import sys
try:
    snapshot_download('$model_name', local_dir='$model_path', local_dir_use_symlinks=False)
    print(f"✓ Model downloaded successfully to $model_path")
except Exception as e:
    print(f"✗ Failed to download model: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    elif command -v hf &> /dev/null; then
        log_info "Using hf CLI tool..."
        hf download "$model_name" --local-dir "$model_path"
    else
        log_error "HuggingFace tools not found. Please install huggingface-hub."
        exit 1
    fi
}

start_cpu_inference() {
    log_info "Starting NeurX inference service (CPU mode)..."
    log_info "  Model: $NEURX_MODEL_DIR"
    log_info "  Device: CPU"
    log_info "  Port: $NEURX_S_PORT"
    log_info "  Max new tokens: $NEURX_CHAT_MAX_NEW_TOKENS"
    
    if [ ! -f "$PRODUCTION_CPU_BACKEND_IR" ]; then
        log_error "CPU backend IR not found at: $PRODUCTION_CPU_BACKEND_IR"
        exit 1
    fi
    
    export NEURX_ROOT="$NEURX_HOME"
    export NEURX_MODEL_DIR="$NEURX_MODEL_DIR"
    export NEURX_INFER_DEVICE=cpu
    export NEURX_CPU_THREADS="${NEURX_CPU_THREADS}"
    export NEURX_CHAT_MAX_NEW_TOKENS="${NEURX_CHAT_MAX_NEW_TOKENS}"
    export NEURX_S_PORT="${NEURX_S_PORT}"
    export NEURX_S_HOST="${NEURX_S_HOST}"
    
    log_info "Executing: $S_RUNNER $PRODUCTION_CPU_BACKEND_IR"
    exec "$S_RUNNER" "$PRODUCTION_CPU_BACKEND_IR"
}

start_gpu_inference() {
    log_info "Starting NeurX inference service (GPU mode)..."
    log_info "  Model: $NEURX_MODEL_DIR"
    log_info "  Device: GPU"
    log_info "  Port: $NEURX_S_PORT"
    log_info "  Max new tokens: $NEURX_CHAT_MAX_NEW_TOKENS"
    
    if [ ! -f "$PRODUCTION_GPU_BACKEND_IR" ]; then
        log_error "GPU backend IR not found at: $PRODUCTION_GPU_BACKEND_IR"
        exit 1
    fi
    
    export NEURX_ROOT="$NEURX_HOME"
    export NEURX_MODEL_DIR="$NEURX_MODEL_DIR"
    export NEURX_INFER_DEVICE=gpu
    export NEURX_S_PORT="$GPU_BACKEND_PORT"
    export NEURX_S_HOST="$NEURX_S_HOST"
    export NEURX_CHAT_MAX_NEW_TOKENS="${NEURX_CHAT_MAX_NEW_TOKENS}"
    
    log_info "Starting GPU backend..."
    "$S_RUNNER" "$PRODUCTION_GPU_BACKEND_IR" >/var/log/neurx/gpu_backend.log 2>&1 &
    GPU_BACKEND_PID=$!
    
    log_info "GPU backend PID: $GPU_BACKEND_PID"
    sleep 10
    
    if ! lsof -i :${NEURX_S_PORT} >/dev/null 2>&1; then
        log_error "GPU backend failed to bind port ${NEURX_S_PORT}"
        kill $GPU_BACKEND_PID 2>/dev/null || true
        exit 1
    fi
    
    log_success "GPU backend is ready on port ${NEURX_S_PORT}"
    
    log_info "Starting chat client..."
    export NEURX_S_HOST="127.0.0.1"
    export NEURX_S_PORT="${NEURX_S_PORT}"
    
    exec "$S_RUNNER" "$CHAT_CLIENT_IR"
}

start_api_server() {
    log_info "Starting NeurX OpenAI-compatible API server..."
    log_info "  Model: $NEURX_MODEL_DIR"
    log_info "  Device: $NEURX_INFER_DEVICE"
    log_info "  Port: $NEURX_S_PORT"
    
    export NEURX_ROOT="$NEURX_HOME"
    export NEURX_MODEL_DIR="$NEURX_MODEL_DIR"
    export NEURX_INFER_DEVICE="${NEURX_INFER_DEVICE}"
    export NEURX_S_PORT="${NEURX_S_PORT}"
    export NEURX_S_HOST="${NEURX_S_HOST}"
    export NEURX_CHAT_MAX_NEW_TOKENS="${NEURX_CHAT_MAX_NEW_TOKENS}"
    
    if [ "$NEURX_INFER_DEVICE" == "gpu" ]; then
        log_info "Executing GPU backend API server..."
        exec "$S_RUNNER" "$PRODUCTION_GPU_BACKEND_IR"
    else
        log_info "Executing CPU backend API server..."
        exec "$S_RUNNER" "$PRODUCTION_CPU_BACKEND_IR"
    fi
}

show_help() {
    cat <<EOF
NeurX Inference Service Docker Container

Usage: docker run [OPTIONS] neurx:latest [COMMAND] [ARGS]

Commands:
  start          Start interactive chat service (default)
  api            Start OpenAI-compatible API server
  download-model Download model weights from Hugging Face
  shell          Open bash shell for debugging
  help           Show this help message

Environment Variables:
  NEURX_MODEL_DIR           Model weights directory (default: /models/default)
  NEURX_INFER_DEVICE        Inference device: cpu or gpu (default: cpu)
  NEURX_S_PORT              Service port (default: 8000)
  NEURX_S_HOST              Service host (default: 0.0.0.0)
  NEURX_CPU_THREADS         CPU threads for inference (default: 4)
  NEURX_CHAT_MAX_NEW_TOKENS Maximum tokens to generate (default: 512)

Examples:
  # Interactive chat (CPU)
  docker run -v /path/to/models:/models neurx:latest start
  
  # API server (GPU)
  docker run --gpus all \\
    -v /path/to/models:/models \\
    -p 8000:8000 \\
    -e NEURX_INFER_DEVICE=gpu \\
    neurx:latest api
  
  # Download model first
  docker run -v /path/to/models:/models \\
    neurx:latest download-model Qwen/Qwen2.5-0.5B-Instruct

EOF
}

case "${1:-start}" in
    start)
        mkdir -p /var/log/neurx
        check_requirements
        if [ "$NEURX_INFER_DEVICE" == "gpu" ]; then
            start_gpu_inference
        else
            start_cpu_inference
        fi
        ;;
    
    api)
        mkdir -p /var/log/neurx
        check_requirements
        start_api_server
        ;;
    
    download-model)
        if [ -z "$2" ]; then
            log_error "Model name required"
            log_info "Usage: docker run neurx:latest download-model <MODEL_NAME>"
            log_info "Example: docker run neurx:latest download-model Qwen/Qwen2.5-0.5B-Instruct"
            exit 1
        fi
        download_model "$2" "$NEURX_MODEL_DIR"
        log_success "Model downloaded to: $NEURX_MODEL_DIR"
        ;;
    
    shell)
        exec /bin/bash
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
