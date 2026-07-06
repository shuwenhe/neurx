#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export MODEL_SIZE=1t
export NEURX_ALLOW_FULL_1T_LOCAL="${NEURX_ALLOW_FULL_1T_LOCAL:-1}"

exec bash "$NEURX_DIR/script/run_model_large_pretrain.sh"
