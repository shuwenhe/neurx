#!/usr/bin/env bash
set -euo pipefail
# NeurX worker helper (can be run on worker or invoked remotely)
# Usage: bash neurx_worker_start.sh

TMP_BIN=${TMP_BIN:-/tmp/neurx_train}
WORLD_SIZE=${WORLD_SIZE:-2}
RANK=${RANK:-1}
LOCAL_RANK=${LOCAL_RANK:-0}
MASTER_ADDR=${MASTER_ADDR:-112.29.145.3}
MASTER_PORT=${MASTER_PORT:-29500}
CONFIG=${NEURX_PRETRAIN_CONFIG:-workflows/llm/pretrain/config/sample.yaml}

echo "[neurx-worker] Starting as rank=$RANK (local_rank=$LOCAL_RANK) connecting to $MASTER_ADDR:$MASTER_PORT"

if [ ! -x "$TMP_BIN" ]; then
  echo "Training binary not found or not executable: $TMP_BIN" >&2
  exit 2
fi

export WORLD_SIZE=${WORLD_SIZE}
export RANK=${RANK}
export LOCAL_RANK=${LOCAL_RANK}
export MASTER_ADDR=${MASTER_ADDR}
export MASTER_PORT=${MASTER_PORT}
export NEURX_PRETRAIN_CONFIG=${CONFIG}
export NEURX_TRAIN_BIN=${TMP_BIN}

# Run in foreground so user can monitor, or use nohup to background
${TMP_BIN} 2>&1 | tee ~/neurx_worker_train.log
