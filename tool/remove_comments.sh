#!/usr/bin/env bash
# Remove all comments from source files
# Handles: // single-line comments and /* */ block comments

set -e

NEURX_ROOT="${1:-.}"
DRY_RUN="${2:-false}"

removed_count=0
total_files=0

process_file() {
    local file="$1"
    local is_dry_run="$2"
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    total_files=$((total_files + 1))
    
    # Create temp file
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    
    # Remove comments using perl (more reliable than sed for complex patterns)
    perl -pe '
        # Remove single-line comments (//)
        s|//.*$||;
        # Remove block comments (/* */) - simple version
        s|/\*.*?\*/||g;
    ' "$file" > "$temp_file"
    
    # Check if file changed
    if ! cmp -s "$file" "$temp_file"; then
        if [ "$is_dry_run" = "true" ]; then
            echo "[DRY RUN] Would remove comments from: $file"
        else
            cp "$temp_file" "$file"
            echo "✅ Removed comments from: $file"
        fi
        removed_count=$((removed_count + 1))
    fi
}

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          Removing Comments from NeurX Source Files             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "🔍 DRY RUN MODE - No files will be modified"
        echo ""
    fi
    
    echo "Processing files in: $NEURX_ROOT"
    echo ""
    
    # Find all source files and process them
    while IFS= read -r file; do
        process_file "$file" "$DRY_RUN"
    done < <(find "$NEURX_ROOT" -type f \( -name "*.s" -o -name "*.cpp" -o -name "*.h" -o -name "*.cu" \))
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                         Summary                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo "Total files processed: $total_files"
    echo "Files modified: $removed_count"
    echo ""
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "Run without 'dry' argument to actually remove comments:"
        echo "  bash tool/remove_comments.sh"
    fi
}

main "$@"
