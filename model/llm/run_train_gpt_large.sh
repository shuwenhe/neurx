#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
NEW_SCRIPT="$NEURX_DIR/script/run_gpt_large_pretrain.sh"

if [[ ! -f "$NEW_SCRIPT" ]]; then
  echo "error: new pretraining script not found: $NEW_SCRIPT" >&2
  exit 1
fi

export NEURX_PRETRAIN_SOURCE="${NEURX_PRETRAIN_SOURCE:-$NEURX_DIR/pretrain/llm/gpt_large_pretrain.s}"
export NEURX_PRETRAIN_OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT_DIR:-$NEURX_DIR/artifacts/checkpoints/model_llm_gpt_large}"

exec bash "$NEW_SCRIPT"
