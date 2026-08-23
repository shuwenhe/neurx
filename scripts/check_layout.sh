#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

allowed_dirs=(
  .github apps artifacts assets backends build cmd configs dataset deploy docs examples
  experimental scripts src tests tools workflows
)

failed=0
while IFS= read -r directory; do
  allowed=0
  for expected in "${allowed_dirs[@]}"; do
    if [[ "$directory" == "$expected" ]]; then
      allowed=1
      break
    fi
  done
  if (( allowed == 0 )); then
    printf 'unexpected top-level directory: %s/\n' "$directory" >&2
    failed=1
  fi
done < <(find . -mindepth 1 -maxdepth 1 -type d ! -name '.git' ! -name '.vscode' -printf '%f\n' | sort)

if rg -l 'neurx\.experimental' src --glob '*.s' >/dev/null; then
  printf 'production source must not import neurx.experimental packages\n' >&2
  failed=1
fi

if rg -l '%src/|src/src/|backends/backends/' . \
  --glob '!artifacts/**' --glob '!scripts/check_layout.sh' >/dev/null; then
  printf 'malformed path prefix detected\n' >&2
  failed=1
fi

if (( failed != 0 )); then
  exit 1
fi

printf 'Repository layout checks passed.\n'
