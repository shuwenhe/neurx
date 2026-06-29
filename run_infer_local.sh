#!/bin/bash

set -euo pipefail

NEURX_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKPOINT_ROOT="${1:-${NEURX_INFER_CHECKPOINT:-$NEURX_DIR/artifacts/checkpoints/llm_s_pretrain}}"
SEED_TEXT="${2:-${NEURX_INFER_SEED:-neurx }}"
MAX_NEW_CHARS="${3:-${NEURX_INFER_MAX_NEW_CHARS:-120}}"

cd "$NEURX_DIR"
node "$NEURX_DIR/tools/infer_llm_checkpoint.mjs" "$CHECKPOINT_ROOT" "$SEED_TEXT" "$MAX_NEW_CHARS"
