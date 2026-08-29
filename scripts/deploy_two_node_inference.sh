#!/bin/bash
# Sync NeurX to two LAN GPU machines and start distributed inference.

set -euo pipefail

NEURX_ROOT="/Users/shuwen/shuwen/neurx"
REMOTE_ROOT="${NEURX_REMOTE_ROOT:-/neurx}"
CONTROLLER_USER="${NEURX_CONTROLLER_USER:-shuwen}"
CONTROLLER_HOST="${NEURX_CONTROLLER_HOST:-192.168.10.39}"
WORKER_USER="${NEURX_WORKER_USER:-shuwen}"
WORKER_HOST="${NEURX_WORKER_HOST:-192.168.10.75}"
MASTER_ADDR="${MASTER_ADDR:-192.168.10.39}"
MASTER_PORT="${MASTER_PORT:-29500}"
WORLD_SIZE="${WORLD_SIZE:-2}"
MODE="${1:-run}"

sync_remote() {
    local login="$1"
    local host="$2"
    echo "[*] Syncing NeurX to $login@$host:$REMOTE_ROOT"
    ssh "$login@$host" "mkdir -p '$REMOTE_ROOT'"
    rsync -az --delete "$NEURX_ROOT/" "$login@$host:$REMOTE_ROOT/"
}

if [ "$MODE" = "sync-only" ]; then
    sync_remote "$CONTROLLER_USER" "$CONTROLLER_HOST"
    sync_remote "$WORKER_USER" "$WORKER_HOST"
    echo "[✓] Sync complete"
    exit 0
fi

sync_remote "$CONTROLLER_USER" "$CONTROLLER_HOST"
sync_remote "$WORKER_USER" "$WORKER_HOST"

echo "[*] Starting controller"
ssh "$CONTROLLER_USER@$CONTROLLER_HOST" "cd '$REMOTE_ROOT' && \
    source config/clusters/2node_deployment/controller.env && \
    export MASTER_ADDR='$MASTER_ADDR' MASTER_PORT='$MASTER_PORT' WORLD_SIZE='$WORLD_SIZE' && \
    mkdir -p /tmp/neurx_cluster/{heartbeat,logs} artifact/{checkpoints,inference_output} && \
    nohup ./cmd/controller/main.s > /tmp/neurx_cluster/logs/controller.log 2>&1 &"

echo "[*] Starting worker"
ssh -l "$WORKER_USER" "$WORKER_HOST" "cd '$REMOTE_ROOT' && \
    source config/clusters/2node_deployment/worker_rank0.env && \
    export MASTER_ADDR='$MASTER_ADDR' MASTER_PORT='$MASTER_PORT' WORLD_SIZE='$WORLD_SIZE' RANK=1 LOCAL_RANK=0 && \
    mkdir -p /tmp/neurx_cluster/{heartbeat,logs} artifact/{checkpoints,inference_output} && \
    nohup ./cmd/worker/main.s > /tmp/neurx_cluster/logs/worker.log 2>&1 &"

echo "[*] Waiting for health endpoint"
for _ in $(seq 1 30); do
    if curl -sf "http://$MASTER_ADDR:8000/health" >/dev/null 2>&1; then
        echo "[✓] Inference is up: http://$MASTER_ADDR:8000"
        exit 0
    fi
    sleep 2
done

echo "[!] Started remote processes, but health endpoint is not ready."
echo "    Controller log:"
echo "    ssh $CONTROLLER_USER@$CONTROLLER_HOST 'tail -n 100 /tmp/neurx_cluster/logs/controller.log'"
echo "    Worker log:"
echo "    ssh -l '$WORKER_USER' $WORKER_HOST 'tail -n 100 /tmp/neurx_cluster/logs/worker.log'"
exit 1
