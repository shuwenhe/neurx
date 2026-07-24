#!/usr/bin/env bash
set -euo pipefail
# NeurX multi-node helper (master)
# Usage: sudo bash neurx_master_start.sh

MASTER_HOST=${MASTER_HOST:-112.29.145.3}
WORKER_HOST=${WORKER_HOST:-root@112.29.145.15}
NEURX_ROOT=${NEURX_ROOT:-/app/shuwen/neurx}
S_BIN=${S_BIN:-$(command -v s || echo /usr/bin/s)}
TMP_BIN=${TMP_BIN:-/tmp/neurx_train}
CONFIG=${NEURX_PRETRAIN_CONFIG:-workflows/llm/pretrain/config/sample.yaml}
WORLD_SIZE=${WORLD_SIZE:-2}
MASTER_PORT=${MASTER_PORT:-29500}
RSYNC_OPTS=${RSYNC_OPTS:--avz --delete}

echo "[neurx-master] NEURX_ROOT=$NEURX_ROOT, worker=$WORKER_HOST"

if [ ! -x "$S_BIN" ]; then
  echo "S compiler not found at $S_BIN" >&2
  exit 1
fi

echo "[neurx-master] Syncing code to worker..."
rsync $RSYNC_OPTS "$NEURX_ROOT/" "$WORKER_HOST:$NEURX_ROOT/"

echo "[neurx-master] Compiling pretrain entrypoint with s..."
# This writes /tmp/neurx_llm_pretrain_run_tmp.ir
"$S_BIN" "$NEURX_ROOT/workflows/llm/pretrain/run/run_with_config.s"

echo "[neurx-master] Emitting binary..."
"$S_BIN" --emit-bin /tmp/neurx_llm_pretrain_run_tmp.ir "$TMP_BIN"
chmod +x "$TMP_BIN"

echo "[neurx-master] Distributing binary to worker..."
rsync -avz "$TMP_BIN" "$WORKER_HOST:$TMP_BIN"

echo "[neurx-master] Starting worker on $WORKER_HOST (rank=1)..."
ssh -o StrictHostKeyChecking=no "$WORKER_HOST" bash -s <<EOF
export WORLD_SIZE=${WORLD_SIZE}
export RANK=1
export LOCAL_RANK=0
export MASTER_ADDR=${MASTER_HOST}
export MASTER_PORT=${MASTER_PORT}
export NEURX_PRETRAIN_CONFIG=${CONFIG}
export NEURX_TRAIN_BIN=${TMP_BIN}
nohup ${TMP_BIN} > ~/neurx_worker_train.log 2>&1 &
echo "worker started"
EOF

echo "[neurx-master] Starting master locally (rank=0)..."
export WORLD_SIZE=${WORLD_SIZE}
export RANK=0
export LOCAL_RANK=0
export MASTER_ADDR=${MASTER_HOST}
export MASTER_PORT=${MASTER_PORT}
export NEURX_PRETRAIN_CONFIG=${CONFIG}
export NEURX_TRAIN_BIN=${TMP_BIN}

nohup ${TMP_BIN} > ~/neurx_master_train.log 2>&1 &
echo "master started; logs: ~/neurx_master_train.log (master), ~/neurx_worker_train.log (worker) on remote"

echo "Done. Monitor logs or adjust config as needed."
