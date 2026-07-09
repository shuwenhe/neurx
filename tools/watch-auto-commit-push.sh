#!/bin/sh

set -eu

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

BRANCH="${NEURX_WATCH_BRANCH:-main}"
INTERVAL="${NEURX_WATCH_INTERVAL:-2}"
DEBOUNCE="${NEURX_WATCH_DEBOUNCE:-1}"
PREFIX="${NEURX_AUTO_COMMIT_PREFIX:-chore: auto-save}"

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
    local files_changed="$1"
    local lines_added="$2"
    local lines_removed="$3"
    
    # Analyze changed files to determine commit type
    local has_trainer=0
    local has_examples=0
    local has_readme=0
    local has_tests=0
    local has_model=0
    local has_config=0
    
    if echo "$files_changed" | grep -q "_trainer\.s"; then
        has_trainer=1
    fi
    if echo "$files_changed" | grep -q "_examples\.s"; then
        has_examples=1
    fi
    if echo "$files_changed" | grep -q "README"; then
        has_readme=1
    fi
    if echo "$files_changed" | grep -q "test"; then
        has_tests=1
    fi
    if echo "$files_changed" | grep -q "model/"; then
        has_model=1
    fi
    if echo "$files_changed" | grep -q "config\|\.toml\|\.yaml"; then
        has_config=1
    fi
    
    # Extract component/feature name from path
    local component=""
    if echo "$files_changed" | grep -q "posttrain/alignment/"; then
        component=$(echo "$files_changed" | grep "posttrain/alignment/" | head -1 | sed 's/.*alignment\/\([^/]*\).*/\1/' | sed 's/_trainer\|_examples\|\.s//')
    fi
    
    # Generate meaningful commit message
    if [ "$has_trainer" -eq 1 ] && [ "$has_examples" -eq 1 ] && [ "$has_readme" -eq 1 ]; then
        # Complete feature implementation
        local component_name=$(echo "$component" | sed 's/_/ /g' | tr '[:lower:]' '[:upper:]')
        echo "feat: implement $component_name trainer with comprehensive examples and documentation ($lines_added lines)"
    elif [ "$has_trainer" -eq 1 ]; then
        # Trainer implementation/update
        local component_name=$(echo "$component" | sed 's/_/ /g' | tr '[:lower:]' '[:upper:]')
        echo "feat: implement $component_name trainer ($lines_added lines of production code)"
    elif [ "$has_examples" -eq 1 ]; then
        # Examples for trainer
        local component_name=$(echo "$component" | sed 's/_/ /g' | tr '[:lower:]' '[:upper:]')
        echo "feat: add $component_name training examples ($lines_added lines)"
    elif [ "$has_readme" -eq 1 ]; then
        # Documentation update
        local component_name=$(echo "$files_changed" | sed 's/.*README_//' | sed 's/\.md//')
        if [ -z "$component_name" ] || [ "$component_name" = "README" ]; then
            echo "docs: update documentation and guides ($lines_added lines added)"
        else
            echo "docs: add $component_name documentation ($lines_added lines)"
        fi
    elif [ "$has_model" -eq 1 ] && [ "$has_tests" -eq 1 ]; then
        echo "feat: implement model feature with tests ($lines_added lines)"
    elif [ "$has_model" -eq 1 ]; then
        echo "feat: implement model improvement ($lines_added lines, $lines_removed removed)"
    elif [ "$has_config" -eq 1 ]; then
        echo "chore: update configuration and parameters"
    elif [ "$has_tests" -eq 1 ]; then
        echo "test: add comprehensive test coverage ($lines_added lines)"
    else
        # Fallback: generic message with line count
        if [ "$lines_added" -gt 500 ]; then
            echo "feat: major implementation update ($lines_added lines added)"
        elif [ "$lines_added" -gt 100 ]; then
            echo "feat: add functionality ($lines_added lines)"
        else
            echo "chore: update code ($lines_added added, $lines_removed removed)"
        fi
    fi
}

commit_and_push() {
    if [ -z "$(git status --porcelain)" ]; then
        return 0
    fi

    git add -A

    if git diff --cached --quiet; then
        return 0
    fi

    # Get statistics about changes
    local files_changed=$(git diff --cached --name-only | tr '\n' ' ')
    local stats=$(git diff --cached --numstat | awk '{added+=$1; removed+=$2} END {print added " " removed}')
    local lines_added=$(echo "$stats" | awk '{print $1}' | grep -o '^[0-9]*' || echo "0")
    local lines_removed=$(echo "$stats" | awk '{print $2}' | grep -o '^[0-9]*' || echo "0")
    
    # Generate meaningful commit message
    local message=$(generate_commit_message "$files_changed" "$lines_added" "$lines_removed")
    
    if NEURX_SKIP_AUTO_STAGE=1 NEURX_SKIP_AUTO_PUSH=1 git commit -m "$message"; then
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
        commit_and_push || true
    fi
done
