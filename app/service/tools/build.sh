#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${1:-.}"
shift || true

if [[ $# -eq 0 ]]; then
  set -- make
fi

cd "$WORKDIR"
if [[ $# -eq 1 ]]; then
  bash -lc "$1"
  exit $?
fi
"$@"
