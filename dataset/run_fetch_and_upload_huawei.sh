#!/bin/bash
set -euo pipefail

# run_fetch_and_upload_huawei.sh
# Usage: set OBS_BUCKET and optionally HF_HUB_TOKEN, then run on an ECS instance.
# Example:
#   export OBS_BUCKET=obs://my-bucket/the-stack/
#   export HF_HUB_TOKEN=hf_xxx
#   bash dataset/run_fetch_and_upload_huawei.sh

OUT_DIR=${OUT_DIR:-/data/the-stack-py}
BUCKET=${OBS_BUCKET:-}
SHARD_SIZE=${SHARD_SIZE:-1000}
DATASET=${DATASET:-bigcode/the-stack-dedup}
LANG=${LANG:-py}
LICENSES=${LICENSES:-"MIT Apache-2.0 BSD-3-Clause"}

if [ -z "$BUCKET" ]; then
  echo "ERROR: OBS_BUCKET not set. Export OBS_BUCKET=obs://your-bucket/the-stack/"
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$(dirname "$0")/.."

echo "Starting stream fetch -> $OUT_DIR"
python3 tools/stack_streamer.py --dataset "$DATASET" --lang "$LANG" --licenses $LICENSES \
  --shard-size "$SHARD_SIZE" --out-dir "$OUT_DIR" --max-files 0 --progress

# Upload with obsutil (assumes obsutil is installed and configured)
if ! command -v obsutil >/dev/null 2>&1; then
  echo "obsutil not found. Install and configure obsutil per Huawei docs"
  exit 1
fi

echo "Uploading $OUT_DIR to $BUCKET"
obsutil cp -r "$OUT_DIR/" "$BUCKET" -u

echo "Upload complete. Files available at: $BUCKET"
