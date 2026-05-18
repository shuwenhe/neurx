#!/usr/bin/env bash
set -euo pipefail

# Minimal launcher for LLM pretrain workflow (local testing)
# - compiles S runtime and modules
# - runs the pretrain IR for a short number of steps

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT_DIR"

# compile runtime and project S modules
make s-compile-runtime

# run the gpt_large_pretrain S entry (IR is generated under build/ir)
s pretrain/llm/gpt_large_pretrain.s build/ir/pretrain/llm/gpt_large_pretrain.ir
