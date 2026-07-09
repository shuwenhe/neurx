#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
S_COMPILER="${S_COMPILER:-/home/shuwen/s/bin/s}"
BUILD_DIR="${NEURX_ROOT}/artifacts/build/shard"
OUTPUT_IR="${BUILD_DIR}/shard.ir"
S_RUNNER_BIN="${NEURX_ROOT}/artifacts/build/s_runner/s_ir_runner"

mkdir -p "${BUILD_DIR}"

if ! command -v "${S_COMPILER}" >/dev/null 2>&1; then
    echo "Error: S compiler not found: ${S_COMPILER}" >&2
    exit 1
fi

"${S_COMPILER}" ir "${SCRIPT_DIR}/shard.s" -o "${OUTPUT_IR}"

if [ ! -x "${S_RUNNER_BIN}" ]; then
    make -C "${NEURX_ROOT}" build-s-ir-runner
fi

cmd="${1:-help}"
shift || true

input="${ENWIKI_BZ2_FILE:-${NEURX_ROOT}/dataset/pretrain/raw/enwiki-latest-pages-articles.xml.bz2}"
output_dir="${ENWIKI_SHARD_DIR:-${NEURX_ROOT}/dataset/pretrain/shard}"
manifest="${ENWIKI_MANIFEST_FILE:-${NEURX_ROOT}/dataset/pretrain/manifest.json}"
docs_per_shard="${DOCS_PER_SHARD:-5000}"
max_pages="${MAX_PAGES:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --shard-dir)
            output_dir="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

NEURX_SHARD_CMD="${cmd}" \
NEURX_HOME="${NEURX_ROOT}" \
NEURX_SHARD_SCRIPT_DIR="${SCRIPT_DIR}" \
ENWIKI_BZ2_FILE="${input}" \
ENWIKI_SHARD_DIR="${output_dir}" \
ENWIKI_MANIFEST_FILE="${manifest}" \
DOCS_PER_SHARD="${docs_per_shard}" \
MAX_PAGES="${max_pages}" \
"${S_RUNNER_BIN}" "${OUTPUT_IR}"
