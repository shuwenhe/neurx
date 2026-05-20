#!/usr/bin/env bash
set -euo pipefail

FILE_PATH="${1:-}"

if [[ -z "$FILE_PATH" ]]; then
  exit 1
fi

mkdir -p "$(dirname "$FILE_PATH")"
cat > "$FILE_PATH"
