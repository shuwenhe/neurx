#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${NEURX_7B_CONFIG:-$SCRIPT_DIR/configs/7b_training.json}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Missing 7B config: $CONFIG_FILE" >&2
    exit 1
fi

export NEURX_7B_CONFIG="$CONFIG_FILE"
exec bash "$SCRIPT_DIR/LAUNCH_7B_TRAINING.sh"
