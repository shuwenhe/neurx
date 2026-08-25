#!/usr/bin/env bash
# Remove extra blank lines from source files
# Reduces multiple consecutive blank lines to maximum 1

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
    
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT
    
    cat "$file" | 
    sed '/^$/N;/^\n$/!P;D' |
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$temp_file"
    
    if ! cmp -s "$file" "$temp_file"; then
        if [ "$is_dry_run" = "true" ]; then
            echo "[DRY RUN] Would remove blank lines from: $file"
        else
            cp "$temp_file" "$file"
            echo "✅ Removed blank lines from: $file"
        fi
        removed_count=$((removed_count + 1))
    fi
}

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        Removing Extra Blank Lines from NeurX Source Files      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "🔍 DRY RUN MODE - No files will be modified"
        echo ""
    fi
    
    echo "Processing files in: $NEURX_ROOT"
    echo ""
    
    while IFS= read -r file; do
        process_file "$file" "$DRY_RUN"
    done < <(find "$NEURX_ROOT" -type f \( -name "*.s" -o -name "*.cpp" -o -name "*.h" -o -name "*.cu" \) 2>/dev/null)
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                         Summary                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo "Total files processed: $total_files"
    echo "Files modified: $removed_count"
    echo ""
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "Run without 'dry' argument to actually remove blank lines:"
        echo "  bash tool/remove_blank_lines.sh"
    fi
}

main "$@"
