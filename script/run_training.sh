#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================================================="
echo "NeurX 深度学习框架 - S-backed Training Entry"
echo "======================================================================="
echo ""

echo "✓ 使用 NeurX S 调度入口..."
echo "  训练入口: make run-training-s"
echo ""

exec make -C "$NEURX_DIR" run-training-s
