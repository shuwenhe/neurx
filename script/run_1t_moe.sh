#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export MODEL_SIZE=1t

exec bash "$NEURX_DIR/script/run_gpt_large_pretrain.sh"
