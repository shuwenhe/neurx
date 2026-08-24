#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

failed=0

report_error() {
  printf 'architecture violation: %s\n' "$1" >&2
  failed=1
}

check_import() {
  local file=$1
  local forbidden=$2
  local match

  match=$(rg -n "^(use|import)[[:space:]]+neurx\.(${forbidden})(\.|\{|\*|$)" "$file" || true)
  if [[ -n "$match" ]]; then
    report_error "$file crosses a forbidden domain boundary"
    printf '%s\n' "$match" >&2
  fi
}

# Validate all S files changed relative to the comparison ref. This lets the
# repository tighten boundaries without making historical debt invisible.
base_ref=${NEURX_ARCH_BASE_REF:-origin/main}
if git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  mapfile -t changed_files < <(
    {
      git diff --name-only --diff-filter=ACMR "$base_ref" -- 'src/**/*.s' 'src/*.s'
      git ls-files --others --exclude-standard -- 'src/**/*.s' 'src/*.s'
    } | sort -u
  )
else
  mapfile -t changed_files < <(rg --files src --glob '*.s')
fi

for file in "${changed_files[@]}"; do
  [[ -f "$file" ]] || continue
  case "$file" in
    src/core/*)
      check_import "$file" 'compiler|runtime|models|inference|training|serving|agent|observability'
      ;;
    src/compiler/*)
      check_import "$file" 'models|inference|training|serving|agent'
      ;;
    src/runtime/*)
      check_import "$file" 'inference|training|serving|agent'
      ;;
    src/distributed/*)
      check_import "$file" 'inference|training|serving|agent'
      ;;
    src/models/*)
      check_import "$file" 'training|serving|agent'
      ;;
    src/inference/*)
      check_import "$file" 'training|serving|agent'
      ;;
    src/training/*)
      check_import "$file" 'serving|agent'
      ;;
  esac
done

# Lifecycle suffixes create parallel "final" implementations. Existing files
# are explicit debt; adding another one requires replacing the canonical file.
debt_file=tools/architecture/lifecycle_filename_debt.txt
mapfile -t lifecycle_files < <(
  rg --files src \
    | rg '(_final|_complete|_fixed|_enhanced|_real)(\.[^.]+)$' \
    | sort
)

for file in "${lifecycle_files[@]}"; do
  if ! rg -Fxq "$file" "$debt_file"; then
    report_error "$file uses a lifecycle suffix; use one canonical implementation name"
  fi
done

if rg -n 'StrictHostKeyChecking=no|rsync[^\n]*--delete' cmd --glob '*.s'; then
  report_error "command entrypoints must not disable SSH verification or delete remote trees"
fi

if rg -n '([0-9]{1,3}\.){3}[0-9]{1,3}' cmd --glob '*.s'; then
  report_error "command entrypoints must not contain deployment-specific IPv4 addresses"
fi

if (( failed != 0 )); then
  exit 1
fi

printf 'Domain boundary checks passed (%d changed S files inspected).\n' "${#changed_files[@]}"
