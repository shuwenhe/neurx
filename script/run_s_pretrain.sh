#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

exec make -C "$NEURX_DIR" run-s-pretrain-s
