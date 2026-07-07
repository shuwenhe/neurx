#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERIFY_DATASET_DIR="${1:-${VERIFY_DATASET_DIR:-$NEURX_ROOT/dataset/pretrain/shard}}"

exec make -C "$NEURX_ROOT" verify-dataset-s VERIFY_DATASET_DIR="$VERIFY_DATASET_DIR"
