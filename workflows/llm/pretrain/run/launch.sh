#!/usr/bin/env bash
set -euo pipefail

# Minimal launcher for LLM pretrain workflow (local testing)
# Reuses the config-driven runner so the workflow shape stays in one place.

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/workflows/llm/pretrain/run/run_with_config.sh" \
  --config "$ROOT_DIR/workflows/llm/pretrain/config/sample.yaml"
