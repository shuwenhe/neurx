#!/bin/bash
# 兼容包装器：保留旧入口名，实际调用工业级分割脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/split_industrial_dataset.sh" "$@"
