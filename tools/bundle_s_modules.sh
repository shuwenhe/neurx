#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <output.s> <entry.s> <dependency.s>..." >&2
  exit 2
fi

output=$1
entry=$2
shift 2
temporary="${output}.tmp"

mkdir -p "$(dirname "$output")"
printf 'package main\n\n' >"$temporary"

for source in "$@"; do
  awk '
    /^package[[:space:]]/ { next }
    /^use[[:space:]]+neurx\.moe\.core/ { next }
    /^use[[:space:]]+neurx\.attention\.nda/ { next }
    { print }
  ' "$source" >>"$temporary"
  printf '\n' >>"$temporary"
done

awk '
  /^package[[:space:]]/ { next }
  /^use[[:space:]]+neurx\.moe\.core/ { next }
  /^use[[:space:]]+neurx\.attention\.nda/ { next }
  { print }
' "$entry" >>"$temporary"

mv "$temporary" "$output"
