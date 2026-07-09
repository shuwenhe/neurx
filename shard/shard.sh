#!/bin/bash

# ============================================================================
# NeurX Shard Manager - Unified interface for all sharding operations
# 
# Usage: shard/shard.sh [command] [options]
# 
# Commands:
#   wikipedia    - Shard Wikipedia dump (ENWIKI)
#   verify       - Verify shard integrity
#   list         - List available shards
#   clean        - Clean up shard files
#   help         - Show this help message
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
    echo -e "${RED}✗${NC} $1" >&2
}

show_help() {
    cat << 'EOF'
NeurX Shard Manager

Usage: shard/shard.sh [command] [options]

Commands:
  wikipedia               Shard Wikipedia dump (ENWIKI)
    Options:
      --input FILE        Input bz2 file (default: from ENWIKI_BZ2_FILE env)
      --output DIR        Output directory (default: from ENWIKI_SHARD_DIR env)
      --manifest FILE     Manifest file (default: from ENWIKI_MANIFEST_FILE env)
      --docs-per-shard N  Documents per shard (default: 5000)
      --max-pages N       Max pages to process for testing (default: 0=unlimited)
  
  verify                  Verify shard integrity
    Options:
      --shard-dir DIR     Shard directory (default: from ENWIKI_SHARD_DIR env)
  
  list                    List available shards
    Options:
      --shard-dir DIR     Shard directory (default: from ENWIKI_SHARD_DIR env)
  
  clean                   Clean up shard files
    Options:
      --shard-dir DIR     Shard directory (default: from ENWIKI_SHARD_DIR env)
  
  help                    Show this help message

Environment Variables:
  NEURX_HOME              Project root (default: current directory)
  ENWIKI_BZ2_FILE         Wikipedia dump file
  ENWIKI_SHARD_DIR        Output directory for shards
  ENWIKI_MANIFEST_FILE    Output manifest file
  DOCS_PER_SHARD          Documents per shard (default: 5000)
  MAX_PAGES               Max pages to process (default: 0)

Examples:
  # Shard Wikipedia dump
  ./shard/shard.sh wikipedia

  # Verify shards
  ./shard/shard.sh verify

  # List shards
  ./shard/shard.sh list

  # Clean up
  ./shard/shard.sh clean
EOF
}

# ============================================================================
# Command: wikipedia
# ============================================================================

cmd_wikipedia() {
    local input="${ENWIKI_BZ2_FILE:-${NEURX_ROOT}/dataset/pretrain/raw/enwiki-latest-pages-articles.xml.bz2}"
    local output_dir="${ENWIKI_SHARD_DIR:-${NEURX_ROOT}/dataset/pretrain/shard}"
    local manifest="${ENWIKI_MANIFEST_FILE:-${NEURX_ROOT}/dataset/pretrain/manifest.json}"
    local docs_per_shard="${DOCS_PER_SHARD:-5000}"
    local max_pages="${MAX_PAGES:-0}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input)
                input="$2"
                shift 2
                ;;
            --output)
                output_dir="$2"
                shift 2
                ;;
            --manifest)
                manifest="$2"
                shift 2
                ;;
            --docs-per-shard)
                docs_per_shard="$2"
                shift 2
                ;;
            --max-pages)
                max_pages="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    log_info "Sharding Wikipedia dataset"
    cd "${NEURX_ROOT}"
    
    python3 "${SCRIPT_DIR}/shard_wikipedia_enwiki.py" \
        --input "${input}" \
        --output-dir "${output_dir}" \
        --manifest "${manifest}" \
        --docs-per-shard "${docs_per_shard}" \
        ${max_pages:+--max-pages "${max_pages}"}
    
    log_success "Wikipedia sharding complete"
}

# ============================================================================
# Command: verify
# ============================================================================

cmd_verify() {
    local shard_dir="${ENWIKI_SHARD_DIR:-${NEURX_ROOT}/dataset/pretrain/shard}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shard-dir)
                shard_dir="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    if [ ! -d "${shard_dir}" ]; then
        log_error "Shard directory not found: ${shard_dir}"
        return 1
    fi
    
    log_info "Verifying shards in ${shard_dir}"
    
    local total=0
    local valid=0
    local invalid=0
    
    for shard_file in "${shard_dir}"/shard_*.jsonl; do
        if [ ! -f "${shard_file}" ]; then
            continue
        fi
        
        total=$((total + 1))
        local line_count=$(wc -l < "${shard_file}")
        
        # Try to parse each line as JSON
        if tail -n 5 "${shard_file}" | python3 -c "import sys, json; [json.loads(line) for line in sys.stdin]" 2>/dev/null; then
            valid=$((valid + 1))
            log_success "$(basename "${shard_file}"): ${line_count} documents"
        else
            invalid=$((invalid + 1))
            log_error "$(basename "${shard_file}"): Invalid JSON detected"
        fi
    done
    
    echo ""
    log_info "Verification Results:"
    echo "  Total shards: ${total}"
    echo "  Valid shards: ${valid}"
    echo "  Invalid shards: ${invalid}"
    
    if [ "${invalid}" -gt 0 ]; then
        return 1
    fi
}

# ============================================================================
# Command: list
# ============================================================================

cmd_list() {
    local shard_dir="${ENWIKI_SHARD_DIR:-${NEURX_ROOT}/dataset/pretrain/shard}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shard-dir)
                shard_dir="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    if [ ! -d "${shard_dir}" ]; then
        log_error "Shard directory not found: ${shard_dir}"
        return 1
    fi
    
    log_info "Listing shards in ${shard_dir}"
    echo ""
    
    printf "%-30s %10s %15s\n" "Shard File" "Lines" "Size (MB)"
    printf "%-30s %10s %15s\n" "--------------------" "----------" "---------------"
    
    local total_size=0
    local total_lines=0
    
    for shard_file in "${shard_dir}"/shard_*.jsonl; do
        if [ ! -f "${shard_file}" ]; then
            continue
        fi
        
        local filename=$(basename "${shard_file}")
        local line_count=$(wc -l < "${shard_file}")
        local file_size=$(($(stat -c%s "${shard_file}" 2>/dev/null || stat -f%z "${shard_file}") / 1024 / 1024))
        
        printf "%-30s %10d %15d\n" "${filename}" "${line_count}" "${file_size}"
        
        total_size=$((total_size + file_size))
        total_lines=$((total_lines + line_count))
    done
    
    echo ""
    printf "%-30s %10d %15d\n" "TOTAL" "${total_lines}" "${total_size}"
}

# ============================================================================
# Command: clean
# ============================================================================

cmd_clean() {
    local shard_dir="${ENWIKI_SHARD_DIR:-${NEURX_ROOT}/dataset/pretrain/shard}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shard-dir)
                shard_dir="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    if [ ! -d "${shard_dir}" ]; then
        log_error "Shard directory not found: ${shard_dir}"
        return 1
    fi
    
    log_warn "Cleaning shard files in ${shard_dir}"
    
    local count=0
    for shard_file in "${shard_dir}"/shard_*.jsonl; do
        if [ -f "${shard_file}" ]; then
            rm -f "${shard_file}"
            count=$((count + 1))
        fi
    done
    
    if [ "${count}" -gt 0 ]; then
        log_success "Removed ${count} shard files"
    else
        log_info "No shard files found to remove"
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    if [ $# -eq 0 ]; then
        show_help
        return 0
    fi
    
    local command="$1"
    shift || true
    
    case "${command}" in
        wikipedia|shard)
            cmd_wikipedia "$@"
            ;;
        verify)
            cmd_verify "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: ${command}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
