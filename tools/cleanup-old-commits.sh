#!/bin/bash
# Cleanup and rewrite old "chore: auto-commit changes at" commits
# This uses git filter-branch to rewrite historical commit messages

set -e

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

BRANCH="main"
TEMP_FILTER="$ROOT_DIR/.git-filter-msg"

echo "🔄 Preparing commit message rewrite..."

# Create a filter script for commit messages
cat > "$TEMP_FILTER" << 'HEREDOC'
#!/bin/bash

# Only process old-format messages
if [[ "$1" =~ ^chore:\ auto-commit\ changes\ at ]]; then
    COMMIT_HASH="$GIT_COMMIT"
    
    # Get files and stats
    FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_HASH" | tr '\n' ' ')
    STATS=$(git diff-tree --no-commit-id --numstat -r "$COMMIT_HASH" | awk '{added+=$1; removed+=$2} END {print added+0 " " removed+0}')
    ADDED=$(echo "$STATS" | awk '{print $1}')
    REMOVED=$(echo "$STATS" | awk '{print $2}')
    
    # Generate new message based on files changed
    if echo "$FILES" | grep -q "_trainer\.s"; then
        COMPONENT=$(echo "$FILES" | grep -o "[^ ]*_trainer\.s" | head -1 | xargs basename | sed 's/_trainer\.s//' | sed 's/_/-/g')
        echo "feat: implement $COMPONENT trainer ($ADDED lines)"
    elif echo "$FILES" | grep -q "_examples\.s"; then
        echo "feat: add training examples ($ADDED lines)"
    elif echo "$FILES" | grep -q "README"; then
        echo "docs: update documentation ($ADDED lines)"
    elif echo "$FILES" | grep -q "Makefile"; then
        echo "chore: update Makefile and build targets"
    elif echo "$FILES" | grep -q "\.md"; then
        echo "docs: update documentation ($ADDED lines)"
    elif echo "$FILES" | grep -q "model/"; then
        if [ "$REMOVED" -gt 10 ]; then
            echo "refactor: optimize model implementation ($ADDED added, $REMOVED removed)"
        else
            echo "feat: implement model improvements ($ADDED lines)"
        fi
    elif [ "$ADDED" -gt 500 ]; then
        echo "feat: major implementation update ($ADDED lines)"
    elif [ "$ADDED" -gt 100 ]; then
        echo "feat: add functionality ($ADDED lines)"
    else
        echo "feat: update code ($ADDED added, $REMOVED removed)"
    fi
else
    # Keep existing message
    cat
fi
HEREDOC

chmod +x "$TEMP_FILTER"

echo "📋 Analyzing commits..."

# Count commits
OLD_COUNT=$(git log --all --oneline | grep -c "chore: auto-commit changes at" || echo 0)

if [ "$OLD_COUNT" -lt 1 ]; then
    echo "✓ No old-format commits found!"
    rm -f "$TEMP_FILTER"
    exit 0
fi

echo "Found $OLD_COUNT commits to rewrite"
echo ""

# Check if filter-branch is safe to run
echo "⚠️  WARNING: This will rewrite git history"
echo ""
echo "Your current branch: $(git rev-parse --abbrev-ref HEAD)"
echo "Commits to rewrite: $OLD_COUNT"
echo ""
echo "This operation:"
echo "  • Will create backup refs (refs/original/)"
echo "  • Requires force-push to remote"
echo "  • Cannot be undone without backup"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    rm -f "$TEMP_FILTER"
    exit 1
fi

echo "🔄 Rewriting commits..."

# Create backup branch
BACKUP_BRANCH="backup/before-msg-rewrite-$(date +%s)"
git branch "$BACKUP_BRANCH" || true

# Use filter-branch to rewrite messages
git filter-branch --msg-filter "$TEMP_FILTER" -- --all 2>&1 | grep -E "^Rewrite|^Ref|^Done" || true

echo ""
echo "✓ Commits rewritten successfully!"
echo ""
echo "📊 Summary:"
echo "  • Backup created: $BACKUP_BRANCH"
echo "  • Commits updated: $OLD_COUNT"
echo ""
echo "⏭️  Next steps:"
echo "  1. Review the changes: git log --oneline -20"
echo "  2. Verify changes look good"
echo "  3. Force push to remote:"
echo "     git push -f origin $(git rev-parse --abbrev-ref HEAD)"
echo ""
echo "To restore if something went wrong:"
echo "  git reset --hard $BACKUP_BRANCH"
echo ""

# Cleanup
rm -f "$TEMP_FILTER"

echo "✅ Done!"
