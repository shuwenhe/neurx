#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

rules=(
  'core:(inference|serving|training|trainer|posttrain|pretrain|agent)'
  'compiler:(serving|training|trainer|posttrain|pretrain|agent)'
  'runtime:(serving|api|training|trainer|posttrain|pretrain|agent)'
  'models:(serving|api|agent)'
  'inference:(training|trainer|posttrain|pretrain|serving|api|agent)'
)

failed=0
for rule in "${rules[@]}"; do
  domain=${rule%%:*}
  forbidden=${rule#*:}
  matches=$(rg -n \
    "^use neurx\.${forbidden}(\.|$)|^import \"${forbidden}/" \
    "src/$domain" --glob '*.s' || true)
  if [[ -n "$matches" ]]; then
    printf 'forbidden dependencies in src/%s:\n%s\n' "$domain" "$matches" >&2
    failed=1
  fi
done

if (( failed != 0 )); then
  exit 1
fi

printf 'Dependency direction checks passed.\n'
