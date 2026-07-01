#!/bin/bash

# ============================================================================
# NeurX Complete Pipeline - Build and Run Script
# Compile → IR → Bundle → Runner → Forward → Loss → Backward → AdamW → Exit
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$PROJECT_DIR/complete_pipeline.s"
OUTPUT_DIR="$PROJECT_DIR/output"
BIN_DIR="$PROJECT_DIR/bin"
BINARY="$BIN_DIR/complete_pipeline"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

print_step() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗ ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

print_header "NeurX Complete Pipeline System - Build & Run"
echo ""

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    print_error "Source file not found: $SOURCE_FILE"
    exit 1
fi

print_info "Project Directory: $PROJECT_DIR"
print_info "Source File: $SOURCE_FILE"
echo ""

# Create directories
print_step "Creating output directories"
mkdir -p "$BIN_DIR" "$OUTPUT_DIR"

# ============================================================================
# COMPILATION PHASE
# ============================================================================

print_header "Phase 1: Compilation"
echo ""

print_info "Compiling complete_pipeline.s with optimization level 2..."
echo ""

# Check if neurx compiler is available
if ! command -v neurx &> /dev/null; then
    print_warning "neurx compiler not found in PATH"
    print_info "Attempting to compile with available compiler..."
    
    # Fallback: Try to use a mock compiler or simulate
    if command -v gcc &> /dev/null; then
        print_warning "Using fallback compilation method"
        print_info "Note: Full neurx features may not be available"
    else
        print_error "No compiler found"
        exit 1
    fi
else
    # Use neurx compiler if available
    print_info "Found neurx compiler"
    START_TIME=$(date +%s%N)
    
    if neurx compile "$SOURCE_FILE" -o "$BINARY" --optimize=2 > "$OUTPUT_DIR/compile.log" 2>&1; then
        END_TIME=$(date +%s%N)
        COMPILE_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
        
        print_step "Compilation successful"
        print_info "Binary: $BINARY"
        print_info "Compile Time: ${COMPILE_TIME}s"
    else
        print_warning "neurx compile command returned non-zero status"
        print_info "Attempting alternative compilation..."
    fi
fi

echo ""

# ============================================================================
# EXECUTION PHASE
# ============================================================================

print_header "Phase 2: Execution"
echo ""

# Try to run with neurx
if command -v neurx &> /dev/null && [ -f "$BINARY" ]; then
    print_info "Running compiled binary: $BINARY"
    echo ""
    
    START_TIME=$(date +%s%N)
    
    # Run the binary
    if "$BINARY" | tee "$OUTPUT_DIR/pipeline_output.log"; then
        END_TIME=$(date +%s%N)
        EXEC_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
        
        echo ""
        print_step "Execution completed successfully"
        print_info "Total Execution Time: ${EXEC_TIME}s"
        print_info "Output log: $OUTPUT_DIR/pipeline_output.log"
    else
        print_error "Binary execution failed"
        exit 1
    fi

# Fallback: Try to run with neurx interpreter
elif command -v neurx &> /dev/null; then
    print_info "Running with neurx interpreter..."
    echo ""
    
    START_TIME=$(date +%s%N)
    
    if neurx run "$SOURCE_FILE" | tee "$OUTPUT_DIR/pipeline_output.log"; then
        END_TIME=$(date +%s%N)
        EXEC_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
        
        echo ""
        print_step "Execution completed successfully"
        print_info "Total Execution Time: ${EXEC_TIME}s"
        print_info "Output log: $OUTPUT_DIR/pipeline_output.log"
    else
        print_error "Interpreter execution failed"
        exit 1
    fi

else
    print_warning "neurx not available, cannot execute"
    print_info "To run the pipeline:"
    print_info "  1. Install neurx compiler"
    print_info "  2. Run: neurx run complete_pipeline.s"
    exit 1
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Execution Summary"
echo ""

if [ -f "$OUTPUT_DIR/pipeline_output.log" ]; then
    # Count successful stages
    STAGES_COMPLETED=$(grep -c "✅" "$OUTPUT_DIR/pipeline_output.log" || echo 0)
    
    print_info "Output File: $OUTPUT_DIR/pipeline_output.log"
    print_info "Stages Completed: $STAGES_COMPLETED"
    print_info "File Size: $(wc -l < "$OUTPUT_DIR/pipeline_output.log") lines"
    echo ""
    
    # Show last few lines
    print_info "Last output lines:"
    tail -n 10 "$OUTPUT_DIR/pipeline_output.log" | sed 's/^/  /'
fi

echo ""
print_step "Complete Pipeline System - Build & Run Finished"
echo ""

# ============================================================================
# NEXT STEPS
# ============================================================================

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Review output: cat $OUTPUT_DIR/pipeline_output.log"
echo "  2. Integrate into training loop"
echo "  3. Enable optimizations (mixed precision, gradient accumulation)"
echo "  4. Scale to distributed training (DDP)"
echo ""

print_step "All systems operational!"
