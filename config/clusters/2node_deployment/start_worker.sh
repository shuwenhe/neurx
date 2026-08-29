#!/bin/bash
# Start Worker on 192.168.10.75 (via SSH)

CONTROLLER_IP=192.168.10.39
WORKER_IP=192.168.10.75
NEURX_ROOT="/Users/shuwen/shuwen/neurx"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"

echo "🚀 Starting NeurX Worker (192.168.10.75) via SSH"
echo ""

# Create SSH command
SSH_CMD="
set -e

echo '╔════════════════════════════════════════════════════════════════╗'
echo '║               NeurX Worker Starting                           ║'
echo '╚════════════════════════════════════════════════════════════════╝'
echo ''

# Navigate to NeurX root
cd $NEURX_ROOT 2>/dev/null || cd ~/neurx || { echo 'NeurX directory not found'; exit 1; }

# Load configuration
source $CONFIG_DIR/worker_rank0.env

# Create directories
mkdir -p \$NEURX_HEARTBEAT_DIR
mkdir -p \$NEURX_LOG_DIR

echo 'Configuration:'
echo \"  Cluster Name:      \$NEURX_CLUSTER_NAME\"
echo \"  Master Address:    \$MASTER_ADDR:\$MASTER_PORT\"
echo \"  Rank:              \$RANK\"
echo \"  World Size:        \$WORLD_SIZE\"
echo \"  Backend:           \$NEURX_BACKEND\"
echo ''
echo 'Starting Worker...'
echo ''

# Check GPU
nvidia-smi

echo ''

# Run worker
if [ -f './build/neurx-worker' ]; then
    ./build/neurx-worker
elif [ -f './cmd/worker/main.s' ]; then
    echo 'Note: S compiler required to run from source'
    echo 'Command: s ./cmd/worker/main.s'
else
    echo '❌ Worker binary or source not found!'
    exit 1
fi
"

# Execute via SSH
echo "Executing on $WORKER_IP..."
echo ""

ssh -o StrictHostKeyChecking=no "shuwen@$WORKER_IP" "$SSH_CMD" || \
ssh -o StrictHostKeyChecking=no "root@$WORKER_IP" "$SSH_CMD" || \
ssh -o StrictHostKeyChecking=no "ubuntu@$WORKER_IP" "$SSH_CMD" || \
{
    echo "❌ Could not SSH to $WORKER_IP"
    echo ""
    echo "Please ensure:"
    echo "  1. SSH key is configured"
    echo "  2. Machine is reachable at $WORKER_IP"
    echo "  3. SSH service is running"
    echo ""
    echo "Try manually:"
    echo "  ssh shuwen@$WORKER_IP"
    exit 1
}
