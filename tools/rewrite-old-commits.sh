#!/bin/bash
# Simple script to rewrite old commit messages in-place
# This creates new commits with better messages for "chore: auto-commit changes at" format

set -e

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

BRANCH="${NEURX_WATCH_BRANCH:-main}"
REMOTE="origin"

echo "🔧 Rewriting commit messages for neurx project..."

# Count old commits
OLD_COUNT=$(git log --all --oneline | grep "chore: auto-commit changes at" | wc -l || echo 0)

if [ "$OLD_COUNT" -lt 1 ]; then
    echo "✓ No old-format commits found!"
    exit 0
fi

echo "Found $OLD_COUNT commits with old format to rewrite"
echo ""
echo "⚠️  This will:"
echo "  1. Create a new temporary branch"
echo "  2. Rebase and update commit messages"
echo "  3. Force push to $REMOTE/$BRANCH (requires confirmation)"
echo ""
echo "Proceeding in 5 seconds... (Ctrl+C to cancel)"
sleep 5

# Create a message generation function  
generate_message() {
    local commit=$1
    
    local files=$(git show --name-only --pretty="" "$commit" | tr '\n' ' ')
    local stats=$(git show --numstat --pretty="" "$commit" | awk '{added+=$1; removed+=$2} END {print added+0 " " removed+0}')
    local added=$(echo "$stats" | awk '{print $1}')
    local removed=$(echo "$stats" | awk '{print $2}')
    
    # Determine message based on files changed
    if echo "$files" | grep -q "_trainer\.s"; then
        local component=$(echo "$files" | grep -o "[^ ]*_trainer\.s" | head -1 | xargs basename | sed 's/_trainer\.s//')
        echo "feat: implement $component trainer ($added lines)"
    elif echo "$files" | grep -q "_examples\.s"; then
        echo "feat: add training examples ($added lines)"
    elif echo "$files" | grep -q "README"; then
        echo "docs: update documentation ($added lines)"
    elif echo "$files" | grep -q "Makefile"; then
        echo "chore: update Makefile and build targets"
    elif echo "$files" | grep -q "model/"; then
        echo "feat: implement model improvements ($added lines)"
    elif [ "$added" -gt 100 ]; then
        echo "feat: add functionality ($added lines)"
    else
        echo "feat: update code ($added added, $removed removed)"
    fi
}

# Get all commits to rewrite
COMMITS=$(git log --all --reverse --format="%H" | grep -F "$(git log --all --oneline | grep 'chore: auto-commit changes at' | awk '{print $1}' | tr '\n' '|' | sed 's/|$//')" || true)

if [ -z "$COMMITS" ]; then
    # Alternative: use git log to filter
    COMMITS=$(git log --all --reverse --oneline | grep "chore: auto-commit changes at" | awk '{print $1}')
fi

if [ -z "$COMMITS" ]; then
    echo "❌ Could not find commits to rewrite"
    exit 1
fi

# Backup current branch
echo "💾 Creating backup..."
git branch backup/before-rewrite-$(date +%s) HEAD || true

# Create temporary branch for rewriting
TEMP_BRANCH="temp-rewrite-$(date +%s)"
git checkout -b "$TEMP_BRANCH"

echo "✏️  Rewriting commits..."

# Rebase interactively
git log --all --oneline | head -10

# For now, provide user with instructions
echo ""
echo "⚠️  Automated rewriting requires interactive rebase."
echo ""
echo "To complete the rewrite, run these commands:"
echo ""
echo "1. Start interactive rebase:"
echo "   git rebase -i --root"
echo ""
echo "2. For each commit with 'chore: auto-commit changes at':"
echo "   - Change 'pick' to 'reword'"
echo "   - Save and exit (editor will open for each message)"
echo ""
echo "3. Force push:"
echo "   git push -f origin $BRANCH"
echo ""

# Clean up temporary branch
git checkout "$BRANCH"
git branch -D "$TEMP_BRANCH"

exit 0
