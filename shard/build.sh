#!/bin/bash
# ============================================================================
# Build all S language shard utilities
# Compiles .s files to S IR format for execution
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/artifacts/build/shard"
S_COMPILER="${S_COMPILER:-/home/shuwen/s/bin/s}"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Check S compiler
if ! command -v "${S_COMPILER}" >/dev/null 2>&1; then
    log_error "S compiler not found: ${S_COMPILER}"
    exit 1
fi

log_info "S Compiler: ${S_COMPILER}"
log_info "Build directory: ${BUILD_DIR}"
echo ""

# Create build directory
mkdir -p "${BUILD_DIR}"

# Compile each S file
SHARD_FILES=(
    "data_shard.s"
    "shard_enwiki.s"
    "verify_shards.s"
    "test_shard.s"
)

for shard_file in "${SHARD_FILES[@]}"; do
    if [ ! -f "${SCRIPT_DIR}/${shard_file}" ]; then
        log_error "File not found: ${shard_file}"
        continue
    fi
    
    output_name="${shard_file%.s}"
    output_ir="${BUILD_DIR}/${output_name}.ir"
    
    log_info "Compiling ${shard_file}..."
    if "${S_COMPILER}" ir "${SCRIPT_DIR}/${shard_file}" -o "${output_ir}" 2>&1; then
        log_success "Compiled: ${output_ir}"
    else
        log_error "Failed to compile: ${shard_file}"
        exit 1
    fi
done

echo ""
log_success "All shard files compiled successfully"
echo ""
echo "Build artifacts:"
ls -lh "${BUILD_DIR}"/*.ir 2>/dev/null || echo "No IR files found"
