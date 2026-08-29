#!/bin/bash
# Generate NeurX distributed inference configuration

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NEURX_ROOT=$(dirname "$SCRIPT_DIR")
CLUSTER_NAME="${1:-neurx-inference}"
GPU_NODES_FILE="${2:-$SCRIPT_DIR/gpu_nodes_discovered.txt}"
CONFIG_DIR="$NEURX_ROOT/config/clusters"

echo "[*] Reading GPU nodes from: $GPU_NODES_FILE"

if [ ! -f "$GPU_NODES_FILE" ]; then
    echo "[!] GPU nodes file not found: $GPU_NODES_FILE"
    echo "[!] Please run discover_gpu_nodes.sh first"
    exit 1
fi

# Count nodes
NODE_COUNT=$(wc -l < "$GPU_NODES_FILE")
if [ "$NODE_COUNT" -lt 2 ]; then
    echo "[!] Need at least 2 GPU nodes for distributed inference"
    exit 1
fi

echo "[*] Found $NODE_COUNT GPU nodes"
echo ""

# Read first node as controller
CONTROLLER_IP=$(head -1 "$GPU_NODES_FILE" | cut -d'|' -f1)
echo "[*] Controller node (Master): $CONTROLLER_IP"

# Generate controller environment config
cat > "$CONFIG_DIR/distributed_inference.env" << EOF
# NeurX Distributed Inference Configuration
# Generated at: $(date)
# Cluster Name: $CLUSTER_NAME
# Total Nodes: $NODE_COUNT

# Controller (Master) Configuration
NEURX_CLUSTER_NAME=$CLUSTER_NAME
NEURX_BACKEND=nccl
MASTER_ADDR=$CONTROLLER_IP
MASTER_PORT=29500
WORLD_SIZE=$NODE_COUNT
NEURX_CONTROLLER_APPLY=0

# Model Configuration
NEURX_MODEL=Qwen/Qwen2.5-0.5B-Instruct
NEURX_MODEL_DIR=/model/Qwen2.5-0.5B-Instruct

# Inference Settings
NEURX_MAX_CONCURRENCY=128
NEURX_MAX_TOKENS=512
NEURX_BATCH_SIZE=8

# Deployment Settings
NEURX_IMAGE=neurx:latest
NEURX_CHECKPOINT_DIR=./artifact/checkpoints
NEURX_OUTPUT_DIR=./artifact/inference_output
NEURX_HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat

# GPU Configuration
NEURX_GPU_MEMORY_UTILIZATION=0.9
NEURX_USE_FLASH_ATTENTION=true
NEURX_USE_PAGED_ATTENTION=true

# Enable heterogeneous node handling
NEURX_ENABLE_HETERO_LAUNCH=1

# SSH Configuration for Remote Workers
NEURX_SSH_KEY_PATH=~/.ssh/id_rsa
NEURX_SSH_KNOWN_HOSTS=/etc/neurx/ssh_known_hosts

EOF

echo "[✓] Generated: $CONFIG_DIR/distributed_inference.env"

# Generate worker configuration for each node
echo ""
echo "[*] Generating worker node configurations..."

awk -F'|' -v num_nodes="$NODE_COUNT" 'NR > 1 {
    node_ip = $1
    gpu_info = $2
    rank = NR - 2
    printf "Node %d: %s (GPU: %s)\n", rank, node_ip, gpu_info
}' "$GPU_NODES_FILE" | while read line; do
    rank=$(echo "$line" | grep -oE "Node [0-9]+" | cut -d' ' -f2)
    node_ip=$(echo "$line" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | tail -1)
    
    if [ -z "$rank" ] || [ -z "$node_ip" ]; then
        continue
    fi
    
    # Generate worker env file
    cat > "$CONFIG_DIR/worker_rank${rank}.env" << EOF
# NeurX Worker Node $rank Configuration
NEURX_CLUSTER_NAME=$CLUSTER_NAME
MASTER_ADDR=$CONTROLLER_IP
MASTER_PORT=29500
WORLD_SIZE=$NODE_COUNT
RANK=$rank
LOCAL_RANK=0
NEURX_NODE_NAME=worker-$rank
NEURX_NODE_HOST=$node_ip
NEURX_NODE_PORT=2950$rank
NEURX_WORKER_BIN=/opt/neurx/bin/inference-worker
NEURX_HEARTBEAT_DIR=/tmp/neurx_cluster/heartbeat
EOF
    
    echo "[✓] Created: $CONFIG_DIR/worker_rank${rank}.env"
done

echo ""
echo "====== Summary ======"
echo "Configuration saved to: $CONFIG_DIR/"
echo "Cluster Name: $CLUSTER_NAME"
echo "Total GPU Nodes: $NODE_COUNT"
echo "Controller: $CONTROLLER_IP:29500"
echo "World Size (parallel degree): $NODE_COUNT"
echo ""
echo "Next steps:"
echo "1. Deploy model to: /model/Qwen2.5-0.5B-Instruct on all nodes"
echo "2. Start controller: ./cmd/controller/main.s"
echo "3. Start workers on each node using corresponding worker_rank*.env"
echo ""
