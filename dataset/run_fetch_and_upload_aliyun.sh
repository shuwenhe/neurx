#!/bin/bash
set -euo pipefail

# run_fetch_and_upload_aliyun.sh
# Usage: set environment variables OSS_BUCKET and optionally HF_HUB_TOKEN, then run on an ECS instance.
# Example:
#   export OSS_BUCKET=oss://my-bucket/the-stack/
#   export HF_HUB_TOKEN=hf_xxx
#   bash dataset/run_fetch_and_upload_aliyun.sh

OUT_DIR=${OUT_DIR:-/data/the-stack-py}
BUCKET=${OSS_BUCKET:-}
SHARD_SIZE=${SHARD_SIZE:-1000}
DATASET=${DATASET:-bigcode/the-stack-dedup}
LANG=${LANG:-py}
LICENSES=${LICENSES:-"MIT Apache-2.0 BSD-3-Clause"}

if [ -z "$BUCKET" ]; then
  echo "ERROR: OSS_BUCKET not set. Export OSS_BUCKET=oss://your-bucket/the-stack/"
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$(dirname "$0")/.."

echo "Starting stream fetch -> $OUT_DIR"
python3 tools/stack_streamer.py --dataset "$DATASET" --lang "$LANG" --licenses $LICENSES \
  --shard-size "$SHARD_SIZE" --out-dir "$OUT_DIR" --max-files 0 --progress

# Upload with ossutil (assumes ossutil is installed and configured)
if ! command -v ossutil >/dev/null 2>&1; then
  echo "ossutil not found. Install one-time as described in dataset/README.md"
  exit 1
fi

echo "Uploading $OUT_DIR to $BUCKET"
ossutil cp -r "$OUT_DIR/" "$BUCKET" --update

echo "Upload complete. Files available at: $BUCKET"
