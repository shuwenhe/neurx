#!/bin/bash
set -euo pipefail

# run_fetch_and_upload_tencent.sh
# Usage: set COS_BUCKET and optionally HF_HUB_TOKEN, then run on a CVM instance.
# Example:
#   export COS_BUCKET=cos://my-bucket/the-stack/
#   export HF_HUB_TOKEN=hf_xxx
#   bash dataset/run_fetch_and_upload_tencent.sh

OUT_DIR=${OUT_DIR:-/data/the-stack-py}
BUCKET=${COS_BUCKET:-}
SHARD_SIZE=${SHARD_SIZE:-1000}
DATASET=${DATASET:-bigcode/the-stack-dedup}
LANG=${LANG:-py}
LICENSES=${LICENSES:-"MIT Apache-2.0 BSD-3-Clause"}

if [ -z "$BUCKET" ]; then
  echo "ERROR: COS_BUCKET not set. Export COS_BUCKET=cos://your-bucket/the-stack/"
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$(dirname "$0")/.."

echo "Starting stream fetch -> $OUT_DIR"
python3 tools/stack_streamer.py --dataset "$DATASET" --lang "$LANG" --licenses $LICENSES \
  --shard-size "$SHARD_SIZE" --out-dir "$OUT_DIR" --max-files 0 --progress

# Upload with coscmd (assumes coscmd is installed and configured)
if ! command -v coscmd >/dev/null 2>&1; then
  echo "coscmd not found. Install with: pip3 install --user coscmd"
  exit 1
fi

echo "Uploading $OUT_DIR to $BUCKET"
coscmd upload -r "$OUT_DIR/" "$BUCKET"

echo "Upload complete. Files available at: $BUCKET"
