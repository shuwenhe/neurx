#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="${1:-}"

if [[ -z "$SOURCE_FILE" || ! -f "$SOURCE_FILE" ]]; then
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

node --check "$SOURCE_FILE"
