#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$SOURCE_FILE" || ! -f "$SOURCE_FILE" ]]; then
  exit 1
fi

if ! command -v g++ >/dev/null 2>&1; then
  exit 0
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$(dirname "$SOURCE_FILE")/a.out"
fi

g++ "$SOURCE_FILE" -o "$OUTPUT_FILE"
