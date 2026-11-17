#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifact/cuda_validation/tmp
export TMPDIR="$PWD/artifact/cuda_validation/tmp"
nvcc -O2 -std=c++17 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 \
  test/cuda_runtime_acceptance.cu -lcuda \
  -o artifact/cuda_validation/cuda_runtime_acceptance
artifact/cuda_validation/cuda_runtime_acceptance
