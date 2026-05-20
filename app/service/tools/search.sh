#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:-}"
ROOT="${2:-.}"

if [[ -z "$QUERY" ]]; then
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  rg -n --hidden --glob '!app/build/**' --glob '!.git/**' "$QUERY" "$ROOT"
else
  grep -RIn --exclude-dir=.git --exclude-dir=build "$QUERY" "$ROOT"
fi
