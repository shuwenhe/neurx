#!/bin/bash
# S Code Standardization - Batch Conversion Script
# This script automates the conversion of all remaining enterprise modules
# From modern S syntax to Go-style S syntax

echo "🔧 NeurX S Language Code Standardization - Batch Converter"
echo "=========================================================="

# Configuration
NEURX_DIR="/Users/feifei/train/neurx"
FILES_TO_CONVERT=(
    "compute/flash_attention.s"
    "train/mixed_precision.s"  
    "distributed/fault_recovery.s"
    "monitoring/distributed_metrics.s"
    "bin/train_enterprise_2t.s"
)

# Global conversion counters
TOTAL_FILES=0
CONVERTED_FILES=0
FAILED_FILES=0

# Function to backup file
backup_file() {
    local file=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$file" "${file}.bak_${timestamp}"
    echo "  ✓ Backup created: ${file}.bak_${timestamp}"
}

# Function to convert single file
convert_file() {
    local filepath=$1
    local filename=$(basename "$filepath")
    
    echo ""
    echo "Converting: $filename"
    echo "─────────────────────────────────────────"
    
    if [ ! -f "$filepath" ]; then
        echo "  ✗ File not found: $filepath"
        ((FAILED_FILES++))
        return 1
    fi
    
    # Create backup
    backup_file "$filepath"
    
    # Apply conversions using sed (platform-aware)
    # Note: macOS sed uses -i '', GNU sed uses -i
    
    local SED_OPTS="-i.bak"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        SED_OPTS="-i .bak"
    fi
    
    # Step 1: Convert module to package
    sed $SED_OPTS 's/^module neurx\./package neurx./g' "$filepath"
    echo "  ✓ Module → Package"
    
    # Step 2: Convert structure to struct  
    sed $SED_OPTS 's/^structure /struct /g' "$filepath"
    sed $SED_OPTS 's/^    structure /    struct /g' "$filepath"
    echo "  ✓ structure → struct"
    
    # Step 3: Convert fn to func
    sed $SED_OPTS 's/^fn /func /g' "$filepath"
    sed $SED_OPTS 's/^    fn /    func /g' "$filepath"
    echo "  ✓ fn → func"
    
    # Step 4: Verify conversion
    local struct_count=$(grep -c "^structure\|^    structure" "$filepath" 2>/dev/null || echo 0)
    local fn_count=$(grep -c "^fn \|^    fn " "$filepath" 2>/dev/null || echo 0)
    local module_count=$(grep -c "^module neurx\." "$filepath" 2>/dev/null || echo 0)
    
    if [ "$struct_count" -eq 0 ] && [ "$fn_count" -eq 0 ] && [ "$module_count" -eq 0 ]; then
        ((CONVERTED_FILES++))
        echo "  ✅ Conversion successful!"
        return 0
    else
        echo "  ⚠ Warning: Some patterns may remain"
        if [ "$struct_count" -gt 0 ]; then echo "    - $struct_count structure declarations found"; fi
        if [ "$fn_count" -gt 0 ]; then echo "    - $fn_count fn declarations found"; fi
        if [ "$module_count" -gt 0 ]; then echo "    - $module_count module declarations found"; fi
        return 0
    fi
}

# Main conversion loop
echo ""
echo "Starting batch conversion of enterprise modules..."
echo ""

for file in "${FILES_TO_CONVERT[@]}"; do
    ((TOTAL_FILES++))
    full_path="$NEURX_DIR/$file"
    convert_file "$full_path"
done

# Summary
echo ""
echo "=========================================================="
echo "📊 Conversion Summary"
echo "=========================================================="
echo "Total files processed: $TOTAL_FILES"
echo "Successfully converted: $CONVERTED_FILES"
echo "Failed: $FAILED_FILES"
echo ""
echo "✅ Conversion complete!"
echo ""
echo "Next steps:"
echo "1. Review converted files for correctness"
echo "2. Check for field-type conversions (may need manual fixes)"
echo "3. Test code compilation with S compiler"
echo "4. Run verification suite"
echo ""
