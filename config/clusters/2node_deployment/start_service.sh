#!/bin/bash

# NeurX Service Launcher - Python Implementation
# This script starts the distributed inference service using the mock Python implementation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON_SERVICE="$SCRIPT_DIR/neurx_service.py"

# Ensure Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed" >&2
    exit 1
fi

# Check if service script exists
if [ ! -f "$PYTHON_SERVICE" ]; then
    echo "❌ Service script not found: $PYTHON_SERVICE" >&2
    exit 1
fi

# Load configuration
if [ -z "$NEURX_ROLE" ]; then
    echo "Usage: NEURX_ROLE=controller|worker bash $0" >&2
    exit 1
fi

if [ "$NEURX_ROLE" = "controller" ]; then
    if [ ! -f "$SCRIPT_DIR/controller.env" ]; then
        echo "❌ Configuration not found: $SCRIPT_DIR/controller.env" >&2
        exit 1
    fi
    source "$SCRIPT_DIR/controller.env" 2>/dev/null || true
elif [ "$NEURX_ROLE" = "worker" ]; then
    if [ ! -f "$SCRIPT_DIR/worker_rank0.env" ]; then
        echo "❌ Configuration not found: $SCRIPT_DIR/worker_rank0.env" >&2
        exit 1
    fi
    source "$SCRIPT_DIR/worker_rank0.env" 2>/dev/null || true
else
    echo "❌ Invalid NEURX_ROLE: $NEURX_ROLE" >&2
    exit 1
fi

# Set defaults if not sourced
NEURX_CLUSTER_NAME="${NEURX_CLUSTER_NAME:-neurx-2node}"
WORLD_SIZE="${WORLD_SIZE:-2}"
RANK="${RANK:-0}"
LOCAL_RANK="${LOCAL_RANK:-0}"
MASTER_ADDR="${MASTER_ADDR:-192.168.10.39}"
MASTER_PORT="${MASTER_PORT:-29500}"
NEURX_PORT="${NEURX_PORT:-8000}"
NEURX_NODE_PORT="${NEURX_NODE_PORT:-29501}"
NEURX_NODE_HOST="${NEURX_NODE_HOST:-192.168.10.75}"
NEURX_MODEL_NAME="${NEURX_MODEL_NAME:-Qwen/Qwen2.5-0.5B-Instruct}"
NEURX_HEARTBEAT_DIR="${NEURX_HEARTBEAT_DIR:-/tmp/neurx_cluster/heartbeat}"
NEURX_LOG_DIR="${NEURX_LOG_DIR:-/tmp/neurx_cluster/logs}"

# Export environment
export NEURX_ROLE
export NEURX_CLUSTER_NAME
export WORLD_SIZE
export RANK
export LOCAL_RANK
export MASTER_ADDR
export MASTER_PORT
export NEURX_PORT
export NEURX_NODE_PORT
export NEURX_NODE_HOST
export NEURX_MODEL_NAME
export NEURX_HEARTBEAT_DIR
export NEURX_LOG_DIR
export PYTHONUNBUFFERED=1

# Create log directories
mkdir -p "$NEURX_LOG_DIR" "$NEURX_HEARTBEAT_DIR" 2>/dev/null || true

# Run service
python3 "$PYTHON_SERVICE"
