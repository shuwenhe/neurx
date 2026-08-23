#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

failed=0
deprecated_dirs=(logging monitoring optim platforms profiler tracing workers)

for directory in "${deprecated_dirs[@]}"; do
  first_file=""
  if [[ -d "$directory" ]]; then
    first_file=$(find "$directory" -type f -print -quit)
  fi
  if [[ -n "$first_file" ]]; then
    printf 'deprecated top-level domain: %s/\n' "$directory" >&2
    failed=1
  fi
done

if (( failed != 0 )); then
  exit 1
fi

printf 'Repository layout checks passed.\n'
