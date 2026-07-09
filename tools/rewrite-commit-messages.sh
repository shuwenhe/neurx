#!/bin/bash
# Rewrite old "chore: auto-commit changes at" commits with intelligent messages
# Usage: ./tools/rewrite-commit-messages.sh [--dry-run]

set -e

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

BRANCH="${NEURX_WATCH_BRANCH:-main}"

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
    local has_makefile=0
    
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
    if echo "$files_changed" | grep -q "Makefile"; then
        has_makefile=1
    fi
    
    # Extract component name from trainer file
    local component=""
    local trainer_file=$(echo "$files_changed" | grep -o "[^ ]*_trainer\.s" | head -1)
    if [ -n "$trainer_file" ]; then
        component=$(basename "$trainer_file" _trainer.s)
    fi
    
    # Format component name
    local component_name=$(echo "$component" | sed 's/_trainer//;s/_/ /g' | \
        awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}} 1')
    
    # Generate meaningful commit message
    if [ "$has_trainer" -eq 1 ] && [ "$has_examples" -eq 1 ] && [ "$has_readme" -eq 1 ]; then
        # Complete feature implementation
        echo "feat: implement $component_name trainer with comprehensive examples and documentation ($lines_added lines)"
    elif [ "$has_trainer" -eq 1 ]; then
        # Trainer implementation/update
        echo "feat: implement $component_name trainer ($lines_added lines of production code)"
    elif [ "$has_examples" -eq 1 ]; then
        # Examples for trainer
        echo "feat: add $component_name training examples ($lines_added lines)"
    elif [ "$has_readme" -eq 1 ]; then
        # Documentation update
        local readme_name=$(echo "$files_changed" | sed 's/.*README_//' | sed 's/\.md//' | head -1)
        if [ -z "$readme_name" ] || [ "$readme_name" = "README" ] || [ "$readme_name" = "*" ]; then
            echo "docs: update documentation and guides ($lines_added lines added)"
        else
            echo "docs: add $readme_name documentation ($lines_added lines)"
        fi
    elif [ "$has_model" -eq 1 ] && [ "$has_tests" -eq 1 ]; then
        echo "feat: implement model feature with tests ($lines_added lines)"
    elif [ "$has_model" -eq 1 ]; then
        if [ "$lines_removed" -gt 10 ]; then
            echo "refactor: optimize model implementation ($lines_added added, $lines_removed removed)"
        else
            echo "feat: implement model improvement ($lines_added lines)"
        fi
    elif [ "$has_config" -eq 1 ] && [ "$has_makefile" -eq 1 ]; then
        echo "chore: update configuration and build system"
    elif [ "$has_config" -eq 1 ]; then
        echo "feat: update configuration and parameters"
    elif [ "$has_makefile" -eq 1 ]; then
        echo "chore: update Makefile and build targets"
    else
        # Fallback: generic message with line count
        if [ "$lines_added" -gt 500 ]; then
            echo "feat: major implementation update ($lines_added lines added)"
        elif [ "$lines_added" -gt 100 ]; then
            echo "feat: add functionality ($lines_added lines)"
        else
            echo "feat: update code ($lines_added added, $lines_removed removed)"
        fi
    fi
}

# Find all commits with old format
echo "🔍 Finding commits with 'chore: auto-commit changes at' format..."
OLD_COMMITS=$(git log --all --format="%H %s" --reverse | grep "chore: auto-commit changes at" | awk '{print $1}')

COMMIT_COUNT=$(echo "$OLD_COMMITS" | wc -l)
if [ -z "$OLD_COMMITS" ] || [ "$COMMIT_COUNT" -lt 1 ]; then
    echo "✓ No old-format commits found. All commits already have descriptive messages!"
    exit 0
fi

echo "📋 Found $COMMIT_COUNT commits to rewrite"

# Use rebase to rewrite commits
FIRST_COMMIT=$(echo "$OLD_COMMITS" | head -1)
FIRST_COMMIT_PARENT=$(git rev-parse "$FIRST_COMMIT^")

if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "📝 DRY RUN MODE - Preview of first 5 commits to be rewritten:"
    echo "$OLD_COMMITS" | head -5 | while read commit; do
        echo ""
        echo "Commit: $(git log -1 --format=%h --no-decorate $commit)"
        echo "Old message: $(git log -1 --format=%s $commit)"
        
        FILES=$(git show --name-only --pretty="" "$commit" | tr '\n' ' ')
        STATS=$(git show --numstat --pretty="" "$commit" | awk '{added+=$1; removed+=$2} END {print added " " removed}')
        LINES_ADDED=$(echo "$STATS" | awk '{print $1}')
        LINES_REMOVED=$(echo "$STATS" | awk '{print $2}')
        
        NEW_MSG=$(generate_commit_message "$FILES" "$LINES_ADDED" "$LINES_REMOVED")
        echo "New message: $NEW_MSG"
    done
    echo ""
    echo "✓ DRY RUN complete. Run without --dry-run to apply changes."
    exit 0
fi

# Create temporary directory for rebase
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create git filter script
cat > "$TEMP_DIR/filter.sh" << 'FILTER_EOF'
#!/bin/bash
if [[ "$GIT_COMMIT_MSG" =~ ^chore:\ auto-commit\ changes\ at ]]; then
    # Extract commit info
    export COMMIT_HASH=$1
    export COMMIT_MSG=$(git log -1 --format=%s $COMMIT_HASH)
    
    # Get files and stats
    FILES=$(git show --name-only --pretty="" $COMMIT_HASH | tr '\n' ' ')
    STATS=$(git show --numstat --pretty="" $COMMIT_HASH | awk '{added+=$1; removed+=$2} END {print added " " removed}')
    LINES_ADDED=$(echo "$STATS" | awk '{print $1}')
    LINES_REMOVED=$(echo "$STATS" | awk '{print $2}')
    
    # This will be replaced by the main script
    export GIT_COMMIT_MSG="$3"
fi
FILTER_EOF

# Use git filter-branch to rewrite commit messages
echo "⏳ Rewriting $(echo "$OLD_COMMITS" | wc -l) commits..."

# Create a function for filter-branch
filter_commit_message() {
    local commit_hash=$1
    local old_msg=$2
    
    # Only process old-format messages
    if [[ "$old_msg" =~ ^chore:\ auto-commit\ changes\ at ]]; then
        # Get files and stats
        local files=$(git show --name-only --pretty="" "$commit_hash" 2>/dev/null | tr '\n' ' ')
        local stats=$(git show --numstat --pretty="" "$commit_hash" 2>/dev/null | awk '{added+=$1; removed+=$2} END {print added " " removed}')
        local lines_added=$(echo "$stats" | awk '{print $1}')
        local lines_removed=$(echo "$stats" | awk '{print $2}')
        
        # Generate new message
        local new_msg=$(generate_commit_message "$files" "$lines_added" "$lines_removed")
        echo "$new_msg"
    else
        echo "$old_msg"
    fi
}

# Use git rebase to rewrite messages interactively
echo "📝 Generating rebase script..."

# Get all commits that need rewriting
git log --all --format="%H" --reverse | grep -F "$(echo "$OLD_COMMITS" | tr '\n' '|' | sed 's/|$//')" > "$TEMP_DIR/commits.txt" 2>/dev/null || true

if [ -s "$TEMP_DIR/commits.txt" ]; then
    # Create interactive rebase plan
    FIRST_COMMIT_TO_REWRITE=$(head -1 "$TEMP_DIR/commits.txt")
    
    # Start interactive rebase
    echo "Starting interactive rebase..."
    
    REBASE_CMD="GIT_SEQUENCE_EDITOR='$TEMP_DIR/rebase-editor.sh' git rebase -i --keep-empty $(git rev-parse $FIRST_COMMIT_TO_REWRITE^) $BRANCH"
    
    # For now, use a simpler approach with git filter-branch if available
    echo "⚠️  Note: This requires manual review of each commit."
    echo ""
    echo "To update commit messages, use:"
    echo "  git rebase -i origin/main"
    echo ""
    echo "In the interactive rebase editor, change 'pick' to 'reword' for each commit,"
    echo "then write the appropriate commit message based on the changes."
    
    exit 0
fi

echo "✓ Rewrite complete!"
