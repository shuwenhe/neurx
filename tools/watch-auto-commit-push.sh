#!/bin/sh

set -eu

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

BRANCH="${NEURX_WATCH_BRANCH:-main}"
INTERVAL="${NEURX_WATCH_INTERVAL:-2}"
DEBOUNCE="${NEURX_WATCH_DEBOUNCE:-1}"
PREFIX="${NEURX_AUTO_COMMIT_PREFIX:-feat: auto-save}"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<'EOF'
usage: tools/watch-auto-commit-push.sh

Environment:
  NEURX_WATCH_BRANCH=main          Branch to watch and push
  NEURX_WATCH_INTERVAL=2           Poll interval fallback in seconds
  NEURX_WATCH_DEBOUNCE=1           Delay before commit after change detection
  NEURX_AUTO_COMMIT_PREFIX=...     Commit message prefix
EOF
    exit 0
fi

current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ "$current_branch" != "$BRANCH" ]; then
    echo "watcher: current branch is '$current_branch', expected '$BRANCH'" >&2
    exit 1
fi

have_inotifywait=0
if command -v inotifywait >/dev/null 2>&1; then
    have_inotifywait=1
fi

generate_commit_message() {
    changed_paths="$1"
    lines_added="$2"
    lines_removed="$3"

    if echo "$changed_paths" | grep -q 'script/'; then
        echo "$PREFIX: update training scripts ($lines_added added, $lines_removed removed)"
        return
    fi
    if echo "$changed_paths" | grep -q 'shard/'; then
        echo "$PREFIX: update shard pipeline ($lines_added added, $lines_removed removed)"
        return
    fi
    if echo "$changed_paths" | grep -q 'tools/'; then
        echo "$PREFIX: update tooling ($lines_added added, $lines_removed removed)"
        return
    fi
    if echo "$changed_paths" | grep -q 'docs/'; then
        echo "$PREFIX: update docs ($lines_added added, $lines_removed removed)"
        return
    fi
    echo "$PREFIX: update code ($lines_added added, $lines_removed removed)"
}

commit_changes() {
    if [ -z "$(git status --porcelain)" ]; then
        return 0
    fi

    git add -A
    if git diff --cached --quiet; then
        return 0
    fi

    changed_paths="$(git diff --cached --name-only | tr '\n' ' ')"
    stats="$(git diff --cached --numstat | awk '{added+=$1; removed+=$2} END {print added " " removed}')"
    lines_added="$(echo "$stats" | awk '{print $1}' | grep -o '^[0-9]*' || echo "0")"
    lines_removed="$(echo "$stats" | awk '{print $2}' | grep -o '^[0-9]*' || echo "0")"
    message="$(generate_commit_message "$changed_paths" "$lines_added" "$lines_removed")"

    if NEURX_SKIP_AUTO_PUSH=1 git commit -m "$message"; then
        echo "watcher: committed: $message"
        git push origin "$BRANCH"
    else
        echo "watcher: commit failed" >&2
        return 1
    fi
}

wait_for_change_inotify() {
    inotifywait -q -r \
        -e close_write,create,delete,move,attrib \
        --exclude '(^|/)\.git(/|$)' \
        .
}

wait_for_change_poll() {
    while [ -z "$(git status --porcelain)" ]; do
        sleep "$INTERVAL"
    done
}

echo "watcher: monitoring $ROOT_DIR on branch '$BRANCH'"
echo "watcher: auto-commit prefix '$PREFIX'"
if [ "$have_inotifywait" -eq 1 ]; then
    echo "watcher: using inotifywait"
else
    echo "watcher: inotifywait not found, using polling every ${INTERVAL}s"
fi

while :; do
    if [ "$have_inotifywait" -eq 1 ]; then
        wait_for_change_inotify || true
    else
        wait_for_change_poll
    fi

    sleep "$DEBOUNCE"
    if [ -n "$(git status --porcelain)" ]; then
        commit_changes || true
    fi
done
