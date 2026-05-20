#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="${1:-}"

if [[ -z "$SOURCE_FILE" || ! -f "$SOURCE_FILE" ]]; then
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

python3 -m py_compile "$SOURCE_FILE"
