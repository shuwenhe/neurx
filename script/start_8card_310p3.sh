#!/bin/bash
set -euo pipefail

# Wrapper to start 8-card training on NPU310P3 (Ascend-like environment)
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)/.."
NEURX_DIR="${NEURX_DIR:-$ROOT_DIR}"
S_ROOT="${S_ROOT:-/app/train/s}"
LOG_DIR="${LOG_DIR:-/tmp/neurx_train_logs}"
RANK_TABLE="${RANK_TABLE_FILE:-$NEURX_DIR/configs/rank_table_8card_310p3.json}"

export RANK_TABLE_FILE="$RANK_TABLE"
export WORLD_SIZE="${WORLD_SIZE:-8}"

mkdir -p "$LOG_DIR"

echo "S_ROOT=$S_ROOT"
echo "NEURX_DIR=$NEURX_DIR"
echo "RANK_TABLE_FILE=$RANK_TABLE_FILE"
echo "WORLD_SIZE=$WORLD_SIZE"

# Source Ascend/CANN env if present
for env_file in /usr/local/Ascend/ascend-toolkit/set_env.sh /usr/local/Ascend/cann-*/set_env.sh; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
    echo "Sourced $env_file"
    break
  fi
done

# Set backend for distributed launcher to HCCL (common for Ascend)
export TENSOR_DIST_BACKEND="hccl"

# Call existing 8-card launcher script
bash "$NEURX_DIR/script/launch_8card_run_train_ir.sh"
