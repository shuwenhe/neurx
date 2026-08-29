#!/bin/bash
# Monitor NeurX distributed inference cluster status

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NEURX_ROOT=$(dirname "$SCRIPT_DIR")
CLUSTER_NAME="${1:-neurx-inference}"
CONFIG_DIR="$NEURX_ROOT/config/clusters"
ENV_FILE="$CONFIG_DIR/distributed_inference.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "[!] Configuration not found: $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          NeurX Distributed Inference Cluster Status            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Display cluster info
echo "📊 CLUSTER INFORMATION"
echo "─────────────────────────────────────────────────────────────────"
echo "Cluster Name:        $CLUSTER_NAME"
echo "Master Address:      $MASTER_ADDR:$MASTER_PORT"
echo "Total Workers:       $WORLD_SIZE"
echo "Backend:             $NEURX_BACKEND"
echo "Model:               $NEURX_MODEL"
echo ""

# Check Controller connectivity
echo "🔗 CONTROLLER STATUS"
echo "─────────────────────────────────────────────────────────────────"
if timeout 2 bash -c "echo > /dev/tcp/$MASTER_ADDR/$MASTER_PORT" 2>/dev/null; then
    echo "✅ Controller is reachable: $MASTER_ADDR:$MASTER_PORT"
else
    echo "❌ Controller is unreachable: $MASTER_ADDR:$MASTER_PORT"
fi
echo ""

# Check Worker heartbeats
echo "💓 WORKER HEARTBEATS"
echo "─────────────────────────────────────────────────────────────────"
if [ -d "$NEURX_HEARTBEAT_DIR" ]; then
    for i in $(seq 0 $((WORLD_SIZE - 1))); do
        heartbeat_files=$(find "$NEURX_HEARTBEAT_DIR" -name "*rank_${i}*" -o -name "*worker_${i}*" 2>/dev/null | head -1)
        if [ -z "$heartbeat_files" ]; then
            # Try alternative naming pattern
            heartbeat_files=$(ls "$NEURX_HEARTBEAT_DIR"/*${i}* 2>/dev/null | head -1)
        fi
        
        if [ -n "$heartbeat_files" ]; then
            timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$heartbeat_files" 2>/dev/null || echo "unknown")
            echo "✅ Worker $i: heartbeat received at $timestamp"
        else
            echo "⏳ Worker $i: waiting for heartbeat..."
        fi
    done
else
    echo "⚠️  Heartbeat directory not found: $NEURX_HEARTBEAT_DIR"
fi
echo ""

# Check GPU resources if possible
echo "🖥️  GPU RESOURCES"
echo "─────────────────────────────────────────────────────────────────"

# Check local GPU
if command -v nvidia-smi &> /dev/null; then
    echo "Local GPU Status:"
    nvidia-smi --query-gpu=index,name,driver_version,memory.used,memory.total \
        --format=csv,noheader | while read line; do
        echo "  $line"
    done
    echo ""
else
    echo "⚠️  nvidia-smi not found on local machine"
fi

# Try to check remote GPUs
echo "Remote GPU Status (via SSH):"
if [ -f "$CONFIG_DIR/worker_rank0.env" ]; then
    source "$CONFIG_DIR/worker_rank0.env" 2>/dev/null || true
    if [ -n "$NEURX_NODE_HOST" ]; then
        echo "  Checking $NEURX_NODE_HOST..."
        if timeout 3 ssh -o ConnectTimeout=2 "root@$NEURX_NODE_HOST" nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader 2>/dev/null; then
            echo "  ✅ Connected"
        else
            echo "  ⚠️  Could not connect (check SSH keys)"
        fi
    fi
fi
echo ""

# Check API server status
echo "🚀 INFERENCE API STATUS"
echo "─────────────────────────────────────────────────────────────────"
API_PORT="${NEURX_PORT:-8000}"
if timeout 2 bash -c "echo > /dev/tcp/$MASTER_ADDR/$API_PORT" 2>/dev/null; then
    echo "✅ API Server is running on http://$MASTER_ADDR:$API_PORT"
    echo ""
    echo "Example request:"
    echo "  curl -X POST http://$MASTER_ADDR:$API_PORT/v1/completions \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"model\": \"$NEURX_MODEL\", \"prompt\": \"Hello!\", \"max_tokens\": 100}'"
else
    echo "⏳ API Server not yet running"
    echo "   Start with: export NEURX_BIND_ADDRESS=0.0.0.0 NEURX_PORT=8000"
    echo "               ./build/neurx-serve"
fi
echo ""

# Display configuration paths
echo "📁 CONFIGURATION PATHS"
echo "─────────────────────────────────────────────────────────────────"
echo "NeurX Root:          $NEURX_ROOT"
echo "Config Directory:    $CONFIG_DIR"
echo "Heartbeat Directory: $NEURX_HEARTBEAT_DIR"
echo "Output Directory:    $NEURX_OUTPUT_DIR"
echo ""

# Display quick commands
echo "⚡ QUICK COMMANDS"
echo "─────────────────────────────────────────────────────────────────"
echo "View logs:           tail -f /tmp/neurx_cluster/*.log"
echo "List configs:        ls -la $CONFIG_DIR/"
echo "Check heartbeats:    ls -la $NEURX_HEARTBEAT_DIR/"
echo "Run inference test:  curl http://$MASTER_ADDR:$API_PORT/v1/models"
echo "Troubleshoot:        bash $SCRIPT_DIR/troubleshoot_cluster.sh"
echo ""

echo "╚════════════════════════════════════════════════════════════════╝"
