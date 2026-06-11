#!/usr/bin/env bash
set -euo pipefail

FILE_PATH="${1:-}"
START_LINE="${2:-1}"
LINE_COUNT="${3:-120}"

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 1
fi

END_LINE=$((START_LINE + LINE_COUNT - 1))
sed -n "${START_LINE},${END_LINE}p" "$FILE_PATH"
