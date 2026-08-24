#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <output.s> <entry.s> <dependency.s>..." >&2
  exit 2
fi

output=$1
entry=$2
shift 2
mkdir -p "$(dirname "$output")"
{
  echo 'package main'
  for source in "$@"; do
    sed -e '/^package /d' -e '/^use /d' "$source"
  done
  sed -e '/^package /d' -e '/^use /d' "$entry"
} > "$output"
