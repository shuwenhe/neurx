#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# First compile and run the training status entry to verify setup
echo "Building and verifying training setup..."
make -C "$NEURX_ROOT" run-large-pretrain-s

# Now launch the actual training
echo ""
echo "✅ Setup verified. Starting actual training..."
echo ""
echo "Launching training pipeline via make run-training-pipeline-s"
exec make -C "$NEURX_ROOT" run-training-pipeline-s
