#!/bin/bash

# Build script for NeurX CUDA Runtime
# Compiles CUDA kernels and creates S-callable library

set -e

NEURX_ROOT="${1:-.}"
BUILD_DIR="${NEURX_ROOT}/build/cuda"
CUDA_DIR="${NEURX_ROOT}/cuda"
INSTALL_PREFIX="${NEURX_ROOT}/artifacts"

echo "=== Building NeurX CUDA Runtime ==="
echo "Source: $CUDA_DIR"
echo "Build: $BUILD_DIR"
echo "Install: $INSTALL_PREFIX"
echo ""

# Check for CUDA toolkit
if ! command -v nvcc &> /dev/null; then
    echo "ERROR: CUDA toolkit (nvcc) not found"
    echo "Install CUDA Toolkit from https://developer.nvidia.com/cuda-downloads"
    exit 1
fi

CUDA_VERSION=$(nvcc --version | grep release | awk '{print $5}' | tr -d ',')
echo "Found CUDA $CUDA_VERSION"
echo ""

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure CMake
echo "Configuring CMake..."
cmake "$CUDA_DIR" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_FLAGS="-O3 -std=c++14"

# Build
echo "Building CUDA library..."
cmake --build . --config Release -j $(nproc)

# Install
echo "Installing to $INSTALL_PREFIX..."
cmake --install .

# List output files
echo ""
echo "=== Build Complete ==="
echo "Library: $INSTALL_PREFIX/lib/libneurx_cuda_runtime.so"
echo "Header: $INSTALL_PREFIX/include/cuda_runtime_binding.h"
echo ""

# Create S FFI helper
echo "Creating S FFI wrapper..."
cat > "$INSTALL_PREFIX/cuda_runtime_ffi.s" << 'EOF'
// S FFI wrapper for CUDA runtime library
// Links to compiled libneurx_cuda_runtime.so

package neurx.cuda.ffi

// These declarations would be auto-generated
// Currently using shell command wrappers as fallback

func cuda_kernel_exec(string kernel_name, string args) int {
    // Execute CUDA kernel via shell interface
    0  // Placeholder: would call neurx_cuda_runtime.so
}
EOF

echo "FFI wrapper created at $INSTALL_PREFIX/cuda_runtime_ffi.s"
echo ""
echo "Next steps:"
echo "1. Link S trainer with: -L $INSTALL_PREFIX/lib -lneurx_cuda_runtime"
echo "2. Update S scripts to use neural.cuda.runtime functions"
echo "3. Run: make pretrain-gpu"
