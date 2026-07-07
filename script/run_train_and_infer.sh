#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

exec make -C "$NEURX_ROOT" train-and-infer-s MODE="${1:-all}"
