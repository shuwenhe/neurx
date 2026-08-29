#!/bin/bash
# ╔════════════════════════════════════════════════════════════════╗
# ║   NeurX Distributed Inference Deployment Script                ║
# ║   For: 192.168.10.39 (Controller) + 192.168.10.75 (Worker)    ║
# ╚════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_NAME="$(basename "$0")"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          NeurX Distributed Inference Deployment               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Detect role
if [ -z "$NEURX_ROLE" ]; then
    echo "Usage: NEURX_ROLE=controller|worker bash $SCRIPT_NAME"
    echo ""
    echo "Example:"
    echo "  On 192.168.10.39:  NEURX_ROLE=controller bash deploy.sh"
    echo "  On 192.168.10.75:  NEURX_ROLE=worker bash deploy.sh"
    echo ""
    exit 1
fi

ROLE="$NEURX_ROLE"
NEURX_ROOT="${NEURX_ROOT:-.}"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "❌ Configuration directory not found: $CONFIG_DIR"
    exit 1
fi

# ============================================
# CONTROLLER MODE
# ============================================

if [ "$ROLE" = "controller" ]; then
    echo "🖥️  Starting in CONTROLLER mode (192.168.10.39)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Load controller config
    echo "📝 Loading configuration: $CONFIG_DIR/controller.env"
    source "$CONFIG_DIR/controller.env"
    
    # Validate environment
    echo "✓ NEURX_CLUSTER_NAME=$NEURX_CLUSTER_NAME"
    echo "✓ MASTER_ADDR=$MASTER_ADDR"
    echo "✓ MASTER_PORT=$MASTER_PORT"
    echo "✓ WORLD_SIZE=$WORLD_SIZE"
    echo ""
    
    # Create directories
    echo "📂 Creating directories..."
    mkdir -p "$NEURX_HEARTBEAT_DIR" "$NEURX_LOG_DIR"
    mkdir -p "$NEURX_CHECKPOINT_DIR" "$NEURX_OUTPUT_DIR"
    echo "✓ Directories ready"
    echo ""
    
    # Check prerequisites
    echo "🔍 Checking prerequisites..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        echo "⚠️  nvidia-smi not found (GPU support required)"
    else
        echo "✓ NVIDIA GPU detected:"
        nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader | sed 's/^/  /'
    fi
    echo ""
    
    # Check model
    if [ -d "$NEURX_MODEL_DIR" ]; then
        echo "✓ Model found: $NEURX_MODEL_DIR"
    else
        echo "⚠️  Model directory not found: $NEURX_MODEL_DIR"
        echo "   Run: python -c \"from transformers import AutoModel; AutoModel.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')\""
    fi
    echo ""
    
    # Start controller
    echo "🚀 Starting NeurX Controller..."
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Configuration:"
    echo "  Cluster: $NEURX_CLUSTER_NAME"
    echo "  Master: $MASTER_ADDR:$MASTER_PORT"
    echo "  Workers: $WORLD_SIZE"
    echo "  API: http://$MASTER_ADDR:$NEURX_PORT"
    echo ""
    echo "Starting process..."
    echo ""
    
    # Go to NeurX root
    cd "$NEURX_ROOT"
    
    # Try different ways to run controller
    if [ -f "./build/neurx-controller" ]; then
        echo "Running: ./build/neurx-controller"
        ./build/neurx-controller
    elif [ -f "./cmd/controller/main.s" ]; then
        echo "Running: S compiler on ./cmd/controller/main.s"
        echo "(Ensure S compiler is installed)"
        # s ./cmd/controller/main.s
        echo ""
        echo "To run, execute:"
        echo "  cd $NEURX_ROOT"
        echo "  source $CONFIG_DIR/controller.env"
        echo "  s ./cmd/controller/main.s"
    else
        echo "❌ Controller binary or source not found!"
        exit 1
    fi

# ============================================
# WORKER MODE
# ============================================

elif [ "$ROLE" = "worker" ]; then
    echo "🖥️  Starting in WORKER mode (192.168.10.75)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Load worker config
    echo "📝 Loading configuration: $CONFIG_DIR/worker_rank0.env"
    source "$CONFIG_DIR/worker_rank0.env"
    
    # Validate environment
    echo "✓ NEURX_CLUSTER_NAME=$NEURX_CLUSTER_NAME"
    echo "✓ MASTER_ADDR=$MASTER_ADDR:$MASTER_PORT"
    echo "✓ RANK=$RANK (WORLD_SIZE=$WORLD_SIZE)"
    echo "✓ LOCAL_RANK=$LOCAL_RANK"
    echo ""
    
    # Create directories
    echo "📂 Creating directories..."
    mkdir -p "$NEURX_HEARTBEAT_DIR" "$NEURX_LOG_DIR"
    echo "✓ Directories ready"
    echo ""
    
    # Check prerequisites
    echo "🔍 Checking prerequisites..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        echo "❌ nvidia-smi not found (GPU support required)"
        exit 1
    else
        echo "✓ NVIDIA GPU detected:"
        nvidia-smi --query-gpu=index,name,driver_version --format=csv,noheader | sed 's/^/  /'
    fi
    echo ""
    
    # Check model
    if [ -d "/model/Qwen2.5-0.5B-Instruct" ]; then
        echo "✓ Model found: /model/Qwen2.5-0.5B-Instruct"
    else
        echo "⚠️  Model not found: /model/Qwen2.5-0.5B-Instruct"
        echo "   Run: python -c \"from transformers import AutoModel; AutoModel.from_pretrained('Qwen/Qwen2.5-0.5B-Instruct', cache_dir='/model')\""
    fi
    echo ""
    
    # Test connection to controller
    echo "🔗 Testing connection to Controller..."
    if timeout 2 bash -c "echo > /dev/tcp/$MASTER_ADDR/$MASTER_PORT" 2>/dev/null; then
        echo "✓ Controller is reachable at $MASTER_ADDR:$MASTER_PORT"
    else
        echo "⚠️  Cannot reach Controller at $MASTER_ADDR:$MASTER_PORT"
        echo "   Ensure Controller is running and port $MASTER_PORT is open"
    fi
    echo ""
    
    # Start worker
    echo "🚀 Starting NeurX Worker..."
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Configuration:"
    echo "  Cluster: $NEURX_CLUSTER_NAME"
    echo "  Master: $MASTER_ADDR:$MASTER_PORT"
    echo "  Rank: $RANK (Local Rank: $LOCAL_RANK)"
    echo "  World Size: $WORLD_SIZE"
    echo "  Node: $NEURX_NODE_HOST:$NEURX_NODE_PORT"
    echo ""
    echo "Starting process..."
    echo ""
    
    # Go to NeurX root
    cd "$NEURX_ROOT"
    
    # Try different ways to run worker
    if [ -f "./build/neurx-worker" ]; then
        echo "Running: ./build/neurx-worker"
        ./build/neurx-worker
    elif [ -f "./cmd/worker/main.s" ]; then
        echo "Running: S compiler on ./cmd/worker/main.s"
        echo "(Ensure S compiler is installed)"
        # s ./cmd/worker/main.s
        echo ""
        echo "To run, execute:"
        echo "  cd $NEURX_ROOT"
        echo "  source $CONFIG_DIR/worker_rank0.env"
        echo "  s ./cmd/worker/main.s"
    else
        echo "❌ Worker binary or source not found!"
        exit 1
    fi

else
    echo "❌ Unknown role: $ROLE"
    echo "Valid roles: controller, worker"
    exit 1
fi
