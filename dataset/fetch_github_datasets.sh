#!/usr/bin/env bash
set -euo pipefail

# fetch_github_datasets.sh
# Usage:
#   ./dataset/fetch_github_datasets.sh human-eval code-search-net
#   ./dataset/fetch_github_datasets.sh --from-file repos.txt
#
# This script clones known GitHub-hosted code datasets into /app/train/neurx/dataset/<name>
# Known dataset keys: human-eval, mbpp, apps, codexglue, code-search-net
# Or supply a file containing one repo per line (owner/repo or full URL) with --from-file

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)/dataset"
mkdir -p "$ROOT_DIR"

clone_repo() {
  repo_url="$1"
  dest="$2"
  if [ -d "$dest" ]; then
    echo "Destination $dest already exists — skipping (use --force to reclone)"
    return
  fi
  git clone --depth 1 "$repo_url" "$dest" || {
    echo "git clone failed for $repo_url, trying full clone"
    git clone "$repo_url" "$dest"
  }
}

known_repo() {
  case "$1" in
    human-eval)
      echo "${NEURX_HUMAN_EVAL_REPO_URL:-https://github.com/human-eval/human-eval.git}"
      ;;
    mbpp)
      echo "https://github.com/google-research/google-research.git"
      ;;
    apps)
      echo "https://github.com/hendrycks/apps.git"
      ;;
    codexglue|codex-glue|codex_glue)
      echo "https://github.com/microsoft/CodeXGLUE.git"
      ;;
    code-search-net|codesearchnet|code_search_net)
      echo "https://github.com/github/CodeSearchNet.git"
      ;;
    codeparrot)
      echo "https://github.com/anton-l/codeparrot.git"
      ;;
    *)
      return 1
      ;;
  esac
}

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 [dataset-key ...] | --from-file list.txt"
  echo "Known keys: human-eval mbpp apps codexglue code-search-net codeparrot"
  exit 1
fi

FORCE=0
if [ "$1" = "--force" ]; then
  FORCE=1
  shift
fi

if [ "$1" = "--from-file" ]; then
  if [ -z "${2:-}" ]; then
    echo "Provide file path after --from-file"
    exit 1
  fi
  list_file="$2"
  if [ ! -f "$list_file" ]; then
    echo "List file not found: $list_file"
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    repo=$(echo "$line" | sed 's/\s.*$//')
    [ -z "$repo" ] && continue
    # normalize owner/repo -> https://github.com/owner/repo.git
    if echo "$repo" | grep -qE '^https?://'; then
      url="$repo"
    else
      url="https://github.com/$repo.git"
    fi
    name=$(basename "$repo" | sed 's/\.git$//')
    dest="$ROOT_DIR/$name"
    if [ $FORCE -eq 1 ] && [ -d "$dest" ]; then
      rm -rf "$dest"
    fi
    clone_repo "$url" "$dest"
  done < "$list_file"
  exit 0
fi

for key in "$@"; do
  url=$(known_repo "$key" || true)
  if [ -n "$url" ]; then
    name=$(echo "$key" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
    dest="$ROOT_DIR/$name"
    if [ $FORCE -eq 1 ] && [ -d "$dest" ]; then
      rm -rf "$dest"
    fi
    echo "Cloning $key -> $dest"
    clone_repo "$url" "$dest"

    # special handling: mbpp is under google-research/mbpp
    if [ "$key" = "mbpp" ]; then
      # move mbpp subset out
      if [ -d "$dest/google-research/mbpp" ]; then
        mv "$dest/google-research/mbpp" "$ROOT_DIR/mbpp"
        rm -rf "$dest"
      fi
    fi
  else
    echo "Unknown dataset key: $key" >&2
  fi
done

echo "All done. Data available under $ROOT_DIR"
