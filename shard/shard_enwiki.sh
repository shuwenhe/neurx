#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
S_COMPILER="${S_COMPILER:-/home/shuwen/s/bin/s}"
BUILD_DIR="${NEURX_ROOT}/artifacts/build/shard"
OUTPUT_IR="${BUILD_DIR}/shard_enwiki.ir"
S_RUNNER_BIN="${NEURX_ROOT}/artifacts/build/s_runner/s_ir_runner"

mkdir -p "${BUILD_DIR}"

if ! command -v "${S_COMPILER}" >/dev/null 2>&1; then
    echo "Error: S compiler not found: ${S_COMPILER}" >&2
    exit 1
fi

"${S_COMPILER}" ir "${SCRIPT_DIR}/shard_enwiki.s" -o "${OUTPUT_IR}"

if [ ! -x "${S_RUNNER_BIN}" ]; then
    make -C "${NEURX_ROOT}" build-s-ir-runner
fi

NEURX_HOME="${NEURX_ROOT}" \
ENWIKI_BZ2_FILE="${ENWIKI_BZ2_FILE:-}" \
ENWIKI_TEMP_XML="${ENWIKI_TEMP_XML:-}" \
ENWIKI_SHARD_DIR="${ENWIKI_SHARD_DIR:-}" \
ENWIKI_MANIFEST_FILE="${ENWIKI_MANIFEST_FILE:-}" \
"${S_RUNNER_BIN}" "${OUTPUT_IR}"
