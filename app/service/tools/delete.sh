#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-}"
RECURSIVE_FLAG="${2:-0}"

if [[ -z "$TARGET_PATH" ]]; then
  exit 1
fi

if [[ ! -e "$TARGET_PATH" ]]; then
  printf 'already absent: %s\n' "$TARGET_PATH"
  exit 0
fi

if [[ -d "$TARGET_PATH" ]]; then
  if [[ "$RECURSIVE_FLAG" != "1" && "$RECURSIVE_FLAG" != "true" && "$RECURSIVE_FLAG" != "yes" ]]; then
    rmdir "$TARGET_PATH"
    exit 0
  fi
  rm -rf -- "$TARGET_PATH"
  exit 0
fi

rm -f -- "$TARGET_PATH"
