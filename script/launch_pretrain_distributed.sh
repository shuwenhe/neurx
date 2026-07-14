#!/bin/bash
# ============================================================================
# NeurX Multi-GPU Distributed Pretraining Launcher
# Supports DDP (Distributed Data Parallel) training across multiple GPUs
# ============================================================================

set -e

PROJECT_ROOT="${NEURX_ROOT:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_SCRIPT_DIR="${PROJECT_ROOT}/script"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration
# ============================================================================

NUM_GPUS=${NEURX_NUM_GPUS:-$(nvidia-smi --list-gpus 2>/dev/null | wc -l || echo 1)}
RANK=${RANK:-0}
WORLD_SIZE=${WORLD_SIZE:-${NUM_GPUS}}
LOCAL_RANK=${LOCAL_RANK:-0}
MASTER_ADDR=${MASTER_ADDR:-127.0.0.1}
MASTER_PORT=${MASTER_PORT:-29500}
BACKEND=${NEURX_DDP_BACKEND:-nccl}

PRETRAIN_CONFIG="${PROJECT_ROOT}/pretrain/pretrain_config.toml"
PRETRAIN_STEPS=${NEURX_PRETRAIN_STEPS:-1000000000}
LOG_INTERVAL=${NEURX_PRETRAIN_LOG_INTERVAL:-100}
SAVE_INTERVAL=${NEURX_PRETRAIN_SAVE_INTERVAL:-5000}

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[PRETRAIN-DDP]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PRETRAIN-DDP]${NC} ✓ $*"
}

log_warn() {
    echo -e "${YELLOW}[PRETRAIN-DDP]${NC} ⚠ $*"
}

log_error() {
    echo -e "${RED}[PRETRAIN-DDP]${NC} ✗ $*" >&2
}

# ============================================================================
# GPU Detection and Validation
# ============================================================================

detect_gpus() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --list-gpus 2>/dev/null | wc -l || echo 0
    else
        echo 0
    fi
}

validate_nvidia() {
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi not found. NVIDIA drivers not installed."
        return 1
    fi
    
    local available_gpus=$(detect_gpus)
    if [ "$available_gpus" -le 0 ]; then
        log_error "No NVIDIA GPUs detected"
        return 1
    fi
    
    log_success "Detected $available_gpus GPU(s)"
    return 0
}

# ============================================================================
# Distributed Training Setup
# ============================================================================

setup_distributed() {
    local available_gpus=$(detect_gpus)
    
    if [ "$WORLD_SIZE" -gt "$available_gpus" ]; then
        log_warn "Requested $WORLD_SIZE GPUs but only $available_gpus available"
        WORLD_SIZE=$available_gpus
    fi
    
    local is_distributed=$([ "$WORLD_SIZE" -gt 1 ] && echo "yes" || echo "no")
    
    log_info "=== DDP Configuration ==="
    log_info "Available GPUs: $available_gpus"
    log_info "Distributed: $is_distributed"
    
    if [ "$is_distributed" = "yes" ]; then
        log_info "World size: $WORLD_SIZE"
        log_info "Current rank: $RANK"
        log_info "Local rank: $LOCAL_RANK"
        log_info "Backend: $BACKEND"
        log_info "Master: $MASTER_ADDR:$MASTER_PORT"
    fi
}

# ============================================================================
# Config Validation
# ============================================================================

validate_config() {
    if [ ! -f "$PRETRAIN_CONFIG" ]; then
        log_error "Config not found: $PRETRAIN_CONFIG"
        return 1
    fi
    
    log_success "Config found: $PRETRAIN_CONFIG"
    
    # Show key config values
    log_info "=== Training Config ==="
    log_info "Max steps: $PRETRAIN_STEPS"
    log_info "Log interval: $LOG_INTERVAL"
    log_info "Save interval: $SAVE_INTERVAL"
    
    return 0
}

# ============================================================================
# Training Launch
# ============================================================================

launch_training() {
    log_info "=== Launching Training ==="
    
    # Export environment variables for training
    export RANK=$RANK
    export WORLD_SIZE=$WORLD_SIZE
    export LOCAL_RANK=$LOCAL_RANK
    export MASTER_ADDR=$MASTER_ADDR
    export MASTER_PORT=$MASTER_PORT
    export NEURX_DDP_BACKEND=$BACKEND
    export NEURX_PRETRAIN_STEPS=$PRETRAIN_STEPS
    export NEURX_PRETRAIN_LOG_INTERVAL=$LOG_INTERVAL
    export NEURX_PRETRAIN_SAVE_INTERVAL=$SAVE_INTERVAL
    export NEURX_PRETRAIN_CONFIG=$PRETRAIN_CONFIG
    
    if [ "$WORLD_SIZE" -gt 1 ]; then
        # Multi-GPU DDP training
        log_info "Starting DDP training on GPU $LOCAL_RANK (rank $RANK/$WORLD_SIZE)"
        log_info "CUDA_VISIBLE_DEVICES will be set to: $LOCAL_RANK"
        
        export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
        
        # Here would be the actual training command
        log_success "DDP environment configured"
        log_info "Ready to execute training script with:"
        log_info "  RANK=$RANK WORLD_SIZE=$WORLD_SIZE LOCAL_RANK=$LOCAL_RANK"
        log_info "  MASTER_ADDR=$MASTER_ADDR MASTER_PORT=$MASTER_PORT"
        
    else
        # Single GPU training
        log_info "Starting single-GPU training on GPU 0"
        export CUDA_VISIBLE_DEVICES=0
        
        log_success "GPU training environment configured"
    fi
    
    # Print environment for verification
    if [ "$RANK" -eq 0 ]; then
        log_info "=== Environment Variables ==="
        log_info "RANK=$RANK"
        log_info "WORLD_SIZE=$WORLD_SIZE"
        log_info "LOCAL_RANK=$LOCAL_RANK"
        log_info "MASTER_ADDR=$MASTER_ADDR"
        log_info "MASTER_PORT=$MASTER_PORT"
        log_info "NEURX_DDP_BACKEND=$BACKEND"
        log_info "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    log_info "=== NeurX Multi-GPU Distributed Pretraining ==="
    log_info "Project root: $PROJECT_ROOT"
    
    # Validate NVIDIA
    if ! validate_nvidia; then
        log_error "NVIDIA validation failed"
        exit 1
    fi
    
    # Setup distributed
    setup_distributed
    
    # Validate config
    if ! validate_config; then
        log_error "Config validation failed"
        exit 1
    fi
    
    # Launch training
    launch_training
    
    log_success "All checks passed. Ready for training!"
    log_info "To start training with DDP, use:"
    if [ "$WORLD_SIZE" -gt 1 ]; then
        log_info "  torchrun --nproc_per_node=$WORLD_SIZE --master_addr=$MASTER_ADDR --master_port=$MASTER_PORT <training_script>"
        log_info "Or with torch.distributed.launch:"
        log_info "  python -m torch.distributed.launch --nproc_per_node=$WORLD_SIZE --master_addr=$MASTER_ADDR --master_port=$MASTER_PORT <training_script>"
    else
        log_info "  python <training_script>"
    fi
}

# ============================================================================
# Script Execution
# ============================================================================

main "$@"
