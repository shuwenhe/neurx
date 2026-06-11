#!/usr/bin/env bash
set -euo pipefail

SOURCE_FILE="${1:-}"

if [[ -z "$SOURCE_FILE" || ! -f "$SOURCE_FILE" ]]; then
  exit 1
fi

if ! command -v go >/dev/null 2>&1; then
  exit 0
fi

WORKDIR="$(dirname "$SOURCE_FILE")"
mkdir -p "${WORKDIR}/gocache" "${WORKDIR}/gomodcache"
(cd "$WORKDIR" && GOCACHE="${WORKDIR}/gocache" GOMODCACHE="${WORKDIR}/gomodcache" go build "$(basename "$SOURCE_FILE")")
