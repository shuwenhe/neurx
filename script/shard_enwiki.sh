#!/bin/bash

# ============================================================================
# NeurX Wikipedia (enwiki) Shard Processing Shell Script
# 
# Shards Wikipedia XML dataset for efficient training:
# - Decompresses .bz2 file  
# - Splits into manageable shards
# - Generates manifest with metadata
# ============================================================================

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="${NEURX_HOME:-.}"
DATASET_ROOT="${DATASET_ROOT:-${NEURX_ROOT}/dataset/pretrain}"

INPUT_BZ2="${ENWIKI_BZ2_FILE:-${DATASET_ROOT}/raw/enwiki-latest-pages-articles.xml.bz2}"
TEMP_XML="${ENWIKI_TEMP_XML:-${DATASET_ROOT}/tmp/enwiki-latest-pages-articles.xml}"
SHARD_DIR="${ENWIKI_SHARD_DIR:-${DATASET_ROOT}/shard}"
MANIFEST_FILE="${ENWIKI_MANIFEST_FILE:-${DATASET_ROOT}/enwiki_manifest.json}"
TARGET_SHARD_SIZE_MB=${ENWIKI_SHARD_SIZE_MB:-500}  # 500MB shards
CLEANUP_TEMP=${ENWIKI_CLEANUP_TEMP:-true}

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$file"
    else
        stat -c%s "$file"
    fi
}

# ============================================================================
# Main Processing
# ============================================================================

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     NeurX Wikipedia Shard Processing (Shell Script)      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Print configuration
    log_info "Configuration:"
    echo "  • Input file: $INPUT_BZ2"
    echo "  • Temp XML: $TEMP_XML"
    echo "  • Shard dir: $SHARD_DIR"
    echo "  • Manifest: $MANIFEST_FILE"
    echo "  • Target shard size: ${TARGET_SHARD_SIZE_MB} MB"
    echo ""
    
    # Step 1: Check if input file exists
    log_info "Checking input file..."
    if [ ! -f "$INPUT_BZ2" ]; then
        log_error "Input file not found: $INPUT_BZ2"
        return 1
    fi
    log_success "Input file exists"
    echo ""
    
    # Step 2: Create necessary directories
    log_info "Creating directories..."
    mkdir -p "$SHARD_DIR" "$(dirname "$TEMP_XML")" "$(dirname "$MANIFEST_FILE")"
    log_success "Directories created"
    echo ""
    
    # Step 3: Decompress bz2 file
    log_info "Decompressing bz2 file..."
    if ! bzip2 -d -c "$INPUT_BZ2" > "$TEMP_XML"; then
        log_error "Failed to decompress bz2 file"
        return 1
    fi
    log_success "Decompression complete"
    echo ""
    
    # Step 4: Get file size
    log_info "Analyzing file..."
    local file_size_bytes=$(get_file_size "$TEMP_XML")
    local file_size_mb=$((file_size_bytes / 1024 / 1024))
    echo "  • XML file size: ${file_size_mb} MB"
    
    # Calculate shard count
    local shard_count=$(( (file_size_mb + TARGET_SHARD_SIZE_MB - 1) / TARGET_SHARD_SIZE_MB ))
    echo "  • Estimated shards: $shard_count"
    echo ""
    
    # Step 5: Split XML into shards
    log_info "Splitting into shards..."
    cd "$SHARD_DIR" || exit 1
    
    # Use split to divide file into shards
    split -b "${TARGET_SHARD_SIZE_MB}M" "$TEMP_XML" "shard_"
    
    # Add .xml extension to all shards
    for f in shard_*; do
        if [ ! -f "${f}.xml" ]; then
            mv "$f" "${f}.xml"
        fi
    done
    
    cd - > /dev/null || exit 1
    
    local actual_shard_count=$(ls -1 "$SHARD_DIR"/shard_*.xml 2>/dev/null | wc -l)
    echo "  • Generated shards: $actual_shard_count"
    log_success "Splitting complete"
    echo ""
    
    # Step 6: Generate manifest
    log_info "Generating manifest..."
    generate_manifest "$actual_shard_count" || return 1
    log_success "Manifest generated"
    echo ""
    
    # Step 7: Cleanup temp files if requested
    if [ "$CLEANUP_TEMP" == "true" ] || [ "$CLEANUP_TEMP" == "1" ]; then
        log_info "Cleaning up temporary files..."
        rm -f "$TEMP_XML"
        log_success "Cleanup complete"
        echo ""
    fi
    
    echo ""
    log_success "Wikipedia sharding complete"
    return 0
}

# ============================================================================
# Manifest Generation
# ============================================================================

generate_manifest() {
    local shard_count=$1
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local total_size_bytes=$(du -sb "$SHARD_DIR" | awk '{print $1}')
    local total_size_mb=$((total_size_bytes / 1024 / 1024))
    
    # Start JSON manifest
    {
        echo "{"
        echo "  \"dataset_name\": \"enwiki-latest\","
        echo "  \"dataset_version\": \"latest\","
        echo "  \"source_file\": \"$INPUT_BZ2\","
        echo "  \"created_at\": \"$timestamp\","
        echo "  \"total_shards\": $shard_count,"
        echo "  \"total_size_bytes\": $total_size_bytes,"
        echo "  \"total_size_mb\": $total_size_mb,"
        echo "  \"shard_dir\": \"$SHARD_DIR\","
        echo "  \"target_shard_size_mb\": $TARGET_SHARD_SIZE_MB,"
        echo "  \"format\": \"xml\","
        echo "  \"shards\": ["
        
        # Add shard entries
        local first=true
        local shard_id=0
        for shard_file in $(ls -1 "$SHARD_DIR"/shard_*.xml 2>/dev/null | sort); do
            local shard_size=$(get_file_size "$shard_file")
            local shard_size_mb=$((shard_size / 1024 / 1024))
            local basename=$(basename "$shard_file")
            
            if [ "$first" = true ]; then
                first=false
            else
                echo "    },"
            fi
            
            echo "    {"
            echo "      \"shard_id\": $shard_id,"
            echo "      \"filename\": \"$basename\","
            echo "      \"size_bytes\": $shard_size,"
            echo "      \"size_mb\": $shard_size_mb"
            
            ((shard_id++))
        done
        
        if [ $shard_id -gt 0 ]; then
            echo "    }"
        fi
        
        echo "  ]"
        echo "}"
    } > "$MANIFEST_FILE"
    
    # Print summary
    echo "  • Manifest written to: $MANIFEST_FILE"
    echo "  • Total shards: $shard_count"
    echo "  • Total size: ${total_size_mb} MB"
    
    return 0
}

# ============================================================================
# Run Main
# ============================================================================

if main; then
    exit 0
else
    log_error "Sharding process failed"
    exit 1
fi
