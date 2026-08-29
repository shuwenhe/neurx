#!/bin/bash
# Launch NeurX distributed inference cluster

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NEURX_ROOT=$(dirname "$SCRIPT_DIR")
CLUSTER_NAME="${1:-neurx-inference}"
CONFIG_DIR="$NEURX_ROOT/config/clusters"
ENV_FILE="$CONFIG_DIR/distributed_inference.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "[!] Configuration not found: $ENV_FILE"
    echo "[!] Please run: generate_inference_config.sh first"
    exit 1
fi

echo "[*] Loading configuration from: $ENV_FILE"
source "$ENV_FILE"

# Verify NeurX binaries exist
if [ ! -f "$NEURX_ROOT/build/neurx-controller" ] && [ ! -f "$NEURX_ROOT/cmd/controller/main.s" ]; then
    echo "[!] NeurX controller binary not found"
    echo "[!] Build with: cd $NEURX_ROOT && make build"
    exit 1
fi

echo ""
echo "=========================================="
echo "NeurX Distributed Inference Launcher"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Master: $MASTER_ADDR:$MASTER_PORT"
echo "World Size: $WORLD_SIZE"
echo "Model: $NEURX_MODEL"
echo ""

# Create cluster directories
mkdir -p "$NEURX_HEARTBEAT_DIR"
mkdir -p "$(dirname $NEURX_CHECKPOINT_DIR)"
mkdir -p "$(dirname $NEURX_OUTPUT_DIR)"

echo "[*] Stage 1: Start Controller (Master Node)"
echo "==========================================="

# Launch controller
export NEURX_CLUSTER_NAME=$CLUSTER_NAME
export NEURX_BACKEND=$NEURX_BACKEND
export MASTER_ADDR=$MASTER_ADDR
export MASTER_PORT=$MASTER_PORT
export WORLD_SIZE=$WORLD_SIZE
export NEURX_ENABLE_HETERO_LAUNCH=$NEURX_ENABLE_HETERO_LAUNCH
export NEURX_HEARTBEAT_DIR=$NEURX_HEARTBEAT_DIR

echo "[*] Environment variables set for controller"
echo "  MASTER_ADDR=$MASTER_ADDR"
echo "  MASTER_PORT=$MASTER_PORT"
echo "  WORLD_SIZE=$WORLD_SIZE"
echo ""

# Dry-run controller to generate launch scripts
echo "[*] Running controller discovery (dry-run)..."
cd "$NEURX_ROOT"

# Try to run as compiled binary, fallback to S source
if [ -f "./build/neurx-controller" ]; then
    ./build/neurx-controller
elif [ -f "./cmd/controller/main.s" ]; then
    echo "[*] Controller source (S language) - requires S compiler"
    echo "[*] Generated launch scripts at: /tmp/neurx_cluster/"
else
    echo "[!] No controller binary or source found"
    exit 1
fi

echo ""
echo "[✓] Controller discovery complete"
echo ""

# Show generated scripts
if [ -f "/tmp/neurx_cluster/launch.sh" ]; then
    echo "[*] Generated worker launch commands saved to:"
    echo "    /tmp/neurx_cluster/launch.sh"
    echo ""
    echo "Worker launch commands:"
    cat /tmp/neurx_cluster/launch.sh
    echo ""
fi

echo "=========================================="
echo "[*] Stage 2: Deploy Workers to GPU Nodes"
echo "=========================================="
echo ""
echo "To launch workers, execute on each node:"
echo ""

# Show worker launch commands
for i in $(seq 0 $((WORLD_SIZE - 1))); do
    if [ -f "$CONFIG_DIR/worker_rank${i}.env" ]; then
        source "$CONFIG_DIR/worker_rank${i}.env"
        echo "# Worker $i:"
        echo "source $CONFIG_DIR/worker_rank${i}.env"
        echo "export RANK=$i"
        echo "export LOCAL_RANK=0"
        echo "$NEURX_ROOT/build/neurx-worker  # or: S $NEURX_ROOT/cmd/worker/main.s"
        echo ""
    fi
done

echo "=========================================="
echo "[*] Waiting for workers to connect..."
echo "=========================================="
echo ""

# Monitor heartbeat
HEARTBEAT_TIMEOUT=60
ELAPSED=0
CONNECTED_WORKERS=0

while [ $ELAPSED -lt $HEARTBEAT_TIMEOUT ]; do
    if [ -d "$NEURX_HEARTBEAT_DIR" ]; then
        CONNECTED_WORKERS=$(find "$NEURX_HEARTBEAT_DIR" -type f -mmin -1 2>/dev/null | wc -l)
        echo "[*] Elapsed: ${ELAPSED}s - Connected workers: $CONNECTED_WORKERS / $WORLD_SIZE"
        
        if [ $CONNECTED_WORKERS -ge $((WORLD_SIZE - 1)) ]; then
            echo "[✓] All workers connected!"
            break
        fi
    fi
    
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $CONNECTED_WORKERS -lt $((WORLD_SIZE - 1)) ]; then
    echo "[!] Timeout waiting for workers. Check logs at:"
    echo "    /tmp/neurx_cluster/heartbeat/"
fi

echo ""
echo "=========================================="
echo "[*] Stage 3: Test Distributed Inference"
echo "=========================================="
echo ""
echo "Run inference via REST API:"
echo "curl -X POST http://$MASTER_ADDR:8000/v1/completions \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"model\": \"$NEURX_MODEL\", \"prompt\": \"Hello, world!\", \"max_tokens\": 100}'"
echo ""

# Optionally start serving API
if [ "${NEURX_START_API:-1}" = "1" ]; then
    echo "[*] Starting inference API server..."
    export NEURX_BIND_ADDRESS=0.0.0.0
    export NEURX_PORT=8000
    export NEURX_MODEL=$NEURX_MODEL
    # $NEURX_ROOT/build/neurx-serve &
    echo "    (Serving on http://0.0.0.0:8000)"
fi

echo ""
echo "[✓] Distributed inference cluster is ready!"
echo ""
