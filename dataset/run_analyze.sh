#!/bin/bash
set -euo pipefail

# run_analyze.sh /path/to/shards_dir [out_report.json]
SHARDS_DIR=${1:-/app/train/neurx/dataset/the-stack}
OUT=${2:-/app/train/neurx/dataset/report.json}

python3 dataset/analyze_dataset.py "$SHARDS_DIR" --out "$OUT" --max-records 0 --sample 0

cat "$OUT"
