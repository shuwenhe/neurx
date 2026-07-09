#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SHARD_DIR="${1:-$NEURX_ROOT/dataset/pretrain/shard}"
MANIFEST_FILE="${2:-$NEURX_ROOT/dataset/pretrain/manifest.json}"

if [ ! -d "$SHARD_DIR" ]; then
    echo "Error: shard directory not found: $SHARD_DIR" >&2
    exit 1
fi

tmp_manifest="$(mktemp)"
trap 'rm -f "$tmp_manifest"' EXIT

find "$SHARD_DIR" -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort > "$tmp_manifest"

if [ ! -s "$tmp_manifest" ]; then
    echo "Error: no shard files found in $SHARD_DIR" >&2
    exit 1
fi

mkdir -p "$(dirname "$MANIFEST_FILE")"
cp "$tmp_manifest" "$MANIFEST_FILE"
echo "Generated pretrain manifest: $MANIFEST_FILE" >&2
