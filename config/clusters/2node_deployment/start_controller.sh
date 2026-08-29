#!/bin/bash
# Start Controller on 192.168.10.39

set -e

NEURX_ROOT="/Users/shuwen/shuwen/neurx"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

echo "🚀 Starting NeurX Controller (192.168.10.39)"
echo ""

# Load configuration
source "$CONFIG_DIR/controller.env"

# Create directories
mkdir -p "$NEURX_HEARTBEAT_DIR"
mkdir -p "$NEURX_LOG_DIR"
mkdir -p artifact/checkpoints
mkdir -p artifact/inference_output

# Navigate to project root
cd "$NEURX_ROOT"

# Print startup info
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               NeurX Controller Starting                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Cluster Name:      $NEURX_CLUSTER_NAME"
echo "  Master Address:    $MASTER_ADDR:$MASTER_PORT"
echo "  World Size:        $WORLD_SIZE"
echo "  Model:             $NEURX_MODEL"
echo "  API Port:          $NEURX_PORT"
echo "  Backend:           $NEURX_BACKEND"
echo ""
echo "Starting Controller..."
echo ""

# Run controller
# Option 1: If compiled binary exists
if [ -f "./build/neurx-controller" ]; then
    ./build/neurx-controller
# Option 2: If S source code exists
elif [ -f "./cmd/controller/main.s" ]; then
    echo "Note: S compiler required to run from source"
    echo "Command: s ./cmd/controller/main.s"
    # Uncomment to run:
    # s ./cmd/controller/main.s
else
    echo "❌ Controller binary or source not found!"
    exit 1
fi
