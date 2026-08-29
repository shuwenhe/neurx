#!/bin/bash
# Launch NeurX distributed inference on the known LAN GPU nodes.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NEURX_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$NEURX_ROOT/config/clusters/2node_deployment"
CONTROLLER_USER="${NEURX_CONTROLLER_USER:-shuwen}"
CONTROLLER_HOST="${NEURX_CONTROLLER_HOST:-192.168.10.39}"
WORKER_USER="${NEURX_WORKER_USER:-shuwen}"
WORKER_HOST="${NEURX_WORKER_HOST:-192.168.10.75}"
REMOTE_NEURX_ROOT="${NEURX_REMOTE_NEURX_ROOT:-/Users/shuwen/shuwen/neurx}"
MASTER_ADDR="${MASTER_ADDR:-192.168.10.39}"
MASTER_PORT="${MASTER_PORT:-29500}"
WORLD_SIZE="${WORLD_SIZE:-2}"

if [ ! -f "$CONFIG_DIR/controller.env" ] || [ ! -f "$CONFIG_DIR/worker_rank0.env" ]; then
    echo "[*] Generating 2-node deployment config"
    bash "$NEURX_ROOT/scripts/setup_2node_deployment.sh" >/dev/null
fi

echo "[*] Verifying SSH access"
ssh -o ConnectTimeout=5 "$CONTROLLER_USER@$CONTROLLER_HOST" "hostname >/dev/null"
ssh -l "$WORKER_USER" -o ConnectTimeout=5 "$WORKER_HOST" "hostname >/dev/null"

echo "[*] Verifying remote NeurX checkout"
if ! ssh "$CONTROLLER_USER@$CONTROLLER_HOST" "test -d '$REMOTE_NEURX_ROOT'"; then
    echo "[!] $CONTROLLER_HOST:$REMOTE_NEURX_ROOT not found"
    echo "    Sync with:"
    echo "    rsync -az --delete /Users/shuwen/shuwen/neurx/ $CONTROLLER_USER@$CONTROLLER_HOST:$REMOTE_NEURX_ROOT/"
    exit 1
fi
if ! ssh -l "$WORKER_USER" "$WORKER_HOST" "test -d '$REMOTE_NEURX_ROOT'"; then
    echo "[!] $WORKER_HOST:$REMOTE_NEURX_ROOT not found"
    echo "    Sync with:"
    echo "    rsync -az --delete /Users/shuwen/shuwen/neurx/ $WORKER_USER@$WORKER_HOST:$REMOTE_NEURX_ROOT/"
    exit 1
fi

echo "[*] Launching controller on $CONTROLLER_HOST"
ssh "$CONTROLLER_USER@$CONTROLLER_HOST" "cd '$REMOTE_NEURX_ROOT' && \
    source config/clusters/2node_deployment/controller.env && \
    export MASTER_ADDR='$MASTER_ADDR' MASTER_PORT='$MASTER_PORT' WORLD_SIZE='$WORLD_SIZE' && \
    mkdir -p /tmp/neurx_cluster/{heartbeat,logs} artifact/{checkpoints,inference_output} && \
    nohup ./cmd/controller/main.s > /tmp/neurx_cluster/logs/controller.log 2>&1 &"

echo "[*] Launching worker on $WORKER_HOST"
ssh -l "$WORKER_USER" "$WORKER_HOST" "cd '$REMOTE_NEURX_ROOT' && \
    source config/clusters/2node_deployment/worker_rank0.env && \
    export MASTER_ADDR='$MASTER_ADDR' MASTER_PORT='$MASTER_PORT' WORLD_SIZE='$WORLD_SIZE' RANK=1 LOCAL_RANK=0 && \
    mkdir -p /tmp/neurx_cluster/{heartbeat,logs} artifact/{checkpoints,inference_output} && \
    nohup ./cmd/worker/main.s > /tmp/neurx_cluster/logs/worker.log 2>&1 &"

echo "[*] Waiting for API"
for _ in $(seq 1 30); do
    if curl -sf "http://$MASTER_ADDR:8000/health" >/dev/null 2>&1; then
        echo "[✓] Inference API is up: http://$MASTER_ADDR:8000"
        exit 0
    fi
    sleep 2
done

echo "[!] Launched processes, but API did not respond yet."
echo "    Check controller log on $CONTROLLER_HOST:"
echo "    ssh $CONTROLLER_USER@$CONTROLLER_HOST 'tail -n 100 /tmp/neurx_cluster/logs/controller.log'"
echo "    Check worker log on $WORKER_HOST:"
echo "    ssh -l '$WORKER_USER' $WORKER_HOST 'tail -n 100 /tmp/neurx_cluster/logs/worker.log'"
exit 1
