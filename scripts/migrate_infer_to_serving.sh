#!/usr/bin/env bash
set -euo pipefail

# Prepare a non-destructive file move plan from infer/* to serving/*.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFER_DIR="$ROOT_DIR/infer"
SERVING_DIR="$ROOT_DIR/serving"

if [[ ! -d "$INFER_DIR" ]]; then
  echo "infer directory not found: $INFER_DIR"
  exit 1
fi

mkdir -p "$SERVING_DIR"

echo "[plan] source: $INFER_DIR"
echo "[plan] target: $SERVING_DIR"
echo "[plan] operations:"

find "$INFER_DIR" -type f -name "*.s" | sort | while read -r src; do
  rel="${src#"$INFER_DIR"/}"
  dst="$SERVING_DIR/$rel"
  echo "  mv infer/$rel -> serving/$rel"
  mkdir -p "$(dirname "$dst")"
  if [[ ! -f "$dst" ]]; then
    cp "$src" "$dst"
  fi
done

echo
echo "Dry migration files copied to serving/. Review and adjust package names before enabling direct runtime loading."
