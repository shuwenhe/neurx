#!/usr/bin/env bash
set -euo pipefail

# Minimal app entry that wires config to neurx runtime
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${ROOT_DIR}/configs/example.yaml"

echo "Starting neurx app with config: $CONF"
exec s "${ROOT_DIR}/../../serving/serve/serve.s"
