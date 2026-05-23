#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
fi

S_BIN_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --s-bin)
      S_BIN_OVERRIDE="$2"; shift 2;;
    *)
      echo "Unknown arg: $1"
      exit 1;;
  esac
done

cd "$ROOT_DIR"
source "$ROOT_DIR/workflows/agent/common/find_s.sh"

if [[ -n "$S_BIN_OVERRIDE" ]]; then
  S_BIN="$S_BIN_OVERRIDE"
else
  S_BIN="$(resolve_s_bin "$ROOT_DIR" || true)"
fi

if ! is_runnable_s_candidate "$S_BIN"; then
  echo "[neurx] compile runtime: missing runnable 's' executable"
  exit 1
fi

mkdir -p build/ir

if "$S_BIN" --help 2>&1 | grep -q "<input.s> <output.ir>"; then
  S_MODE="legacy"
else
  S_MODE="modern"
fi

compile_one() {
  local src="$1"
  local base parent module target_dir target

  base="$(basename "$src" .s)"
  parent="$(basename "$(dirname "$src")")"
  module="${src%.s}"
  if [[ "$parent" == "$base" ]]; then
    module="$(dirname "$src")"
  fi
  target_dir="$(dirname "$module")"
  mkdir -p "build/ir/$target_dir"
  target="build/ir/$module.ir"

  echo "Compiling $src -> $target"
  if [[ "$S_MODE" == "legacy" ]]; then
    "$S_BIN" "$src" "$target"
  else
    "$S_BIN" ir "$src" -o "$target"
  fi
}

for root in s ops data tensor ad engine nn opt lf train pretrain runtime distributed serving infer infer/vllm model platform compile reasoning workflows app/web; do
  [[ -d "$root" ]] || continue
  while IFS= read -r src; do
    [[ -n "$src" ]] || continue
    compile_one "$src"
  done < <(find "$root" -type f -name '*.s' | sort)
done

root_dir="$PWD"
artifact_dir="$root_dir/build/ir"
manifest_path="$artifact_dir/manifest.json"
files="$(cd build/ir && find . -type f -name '*.ir' | sed 's#^\./##' | sort)"
{
  echo "{"
  echo "  \"source_root\": \"${root_dir}\","
  echo "  \"artifact_root\": \"${artifact_dir}\","
  echo "  \"ir_files\": ["
  first=1
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if [[ $first -eq 0 ]]; then
      printf ',\n'
    fi
    printf '    "%s"' "$file"
    first=0
  done <<< "$files"
  printf '\n'
  echo "  ]"
  echo "}"
} > "$manifest_path"

echo "runtime manifest: build/ir/manifest.json"
