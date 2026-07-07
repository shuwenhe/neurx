#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SHARDS_DIR="${1:-${SHARDS_DIR:-$NEURX_ROOT/dataset/pretrain/shard}}"
OUT="${2:-${OUT:-$NEURX_ROOT/dataset/report.json}}"

exec make -C "$NEURX_ROOT" analyze-dataset-s SHARDS_DIR="$SHARDS_DIR" OUT="$OUT"
