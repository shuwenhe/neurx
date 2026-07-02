#!/usr/bin/env bash
set -euo pipefail

# Run GPT-style pretraining on a single node with 8 Ascend 310P3 cards
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Ascend toolkit (adjust if your install path differs)
export ASCEND_HOME_PATH="${ASCEND_HOME_PATH:-/usr/local/Ascend/ascend-toolkit/latest}"
source "$ROOT_DIR/arch/cann/env.sh"

# Visible devices and HCCL settings for 8-card run
export ASCEND_RT_VISIBLE_DEVICES="0,1,2,3,4,5,6,7"
export HCCL_CONNECT_TIMEOUT="7200"

# Distributed backend (Ascend uses HCCL)
export TENSOR_DIST_BACKEND="hccl"
export NEURX_PRETRAIN_BACKEND="hccl"
export NEURX_PRETRAIN_WORLD_SIZE="8"
export NEURX_PRETRAIN_MASTER_ADDR="${NEURX_PRETRAIN_MASTER_ADDR:-127.0.0.1}"
export NEURX_PRETRAIN_MASTER_PORT="${NEURX_PRETRAIN_MASTER_PORT:-29500}"

# Model/run-time overrides (tweak as needed)
export MODEL_SIZE="${MODEL_SIZE:-gpt-large}"
export S_COMPILER="${S_COMPILER:-$ROOT_DIR/../s/.local/bin/s}"

mkdir -p artifacts/logs
LOG=artifacts/logs/gpt5.5_pretrain_$(date +%Y%m%d_%H%M%S).log

echo "Starting NeurX pretrain (8 x Ascend310P3). Log -> $LOG"

S_COMPILER="$S_COMPILER" MODEL_SIZE="$MODEL_SIZE" \
NEURX_PRETRAIN_WORLD_SIZE="$NEURX_PRETRAIN_WORLD_SIZE" NEURX_PRETRAIN_BACKEND="$NEURX_PRETRAIN_BACKEND" \
bash script/run_gpt_large_pretrain.sh 2>&1 | tee "$LOG"
