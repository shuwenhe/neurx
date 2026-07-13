#!/bin/bash

# ============================================================================
# NeurX CUDA Runtime Compilation Script
# Compiles C/CUDA wrapper to shared library
# ============================================================================

set -e

echo "=== NeurX CUDA Runtime Build ==="
echo ""

# Check CUDA installation
if ! command -v nvcc &> /dev/null; then
    echo "[ERROR] nvcc not found. Install CUDA Toolkit first."
    echo "  https://developer.nvidia.com/cuda-downloads"
    exit 1
fi

CUDA_VERSION=$(nvcc --version | grep release | awk '{print $5}' | tr -d ',')
echo "[INFO] CUDA Version: $CUDA_VERSION"

# Detect GPU compute capability
echo "[INFO] Detecting GPU architecture..."
GPU_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "[INFO] GPU Compute Capability: $GPU_ARCH (sm_$GPU_ARCH)"

# Create build directory
BUILD_DIR="./artifacts/build/cuda_runtime"
mkdir -p "$BUILD_DIR"

echo ""
echo "[BUILD] Compiling cuda_wrapper_simple.cu..."

# Compile CUDA source to object file
nvcc \
    -c cuda/cuda_wrapper_simple.cu \
    -o "$BUILD_DIR/cuda_wrapper.o" \
    -arch=sm_$GPU_ARCH \
    -dc \
    -Xcompiler -fPIC \
    -std=c++11 \
    -O2 \
    --use_fast_math \
    -m64

if [ $? -ne 0 ]; then
    echo "[ERROR] CUDA compilation failed"
    exit 1
fi

echo "[SUCCESS] cuda_wrapper.o created"

# Link to shared library
echo "[BUILD] Creating shared library..."

CUDA_INSTALL=$(nvcc -v 2>&1 | grep "bin/nvcc" | head -1 | xargs dirname | xargs dirname)
CUDA_LIB="$CUDA_INSTALL/lib64"

# Device link
nvcc \
    -dlink "$BUILD_DIR/cuda_wrapper.o" \
    -o "$BUILD_DIR/cuda_wrapper_dlink.o" \
    -arch=sm_$GPU_ARCH \
    -m64

# Final shared library
g++ \
    -shared \
    -o "$BUILD_DIR/libcuda_runtime.so" \
    "$BUILD_DIR/cuda_wrapper.o" \
    "$BUILD_DIR/cuda_wrapper_dlink.o" \
    -L$CUDA_LIB \
    -L/usr/local/cuda/lib64 \
    -lcuda \
    -lcudart \
    -lcublas \
    -Wl,-rpath,$CUDA_LIB

if [ $? -ne 0 ]; then
    echo "[ERROR] Linking failed"
    exit 1
fi

echo "[SUCCESS] libcuda_runtime.so created"

# Create library information file
cat > "$BUILD_DIR/lib_info.txt" << EOF
NeurX CUDA Runtime Library
Generated: $(date)
CUDA Version: $CUDA_VERSION
GPU Architecture: sm_$GPU_ARCH
Library Path: $(pwd)/$BUILD_DIR/libcuda_runtime.so
EOF

echo ""
echo "[INFO] CUDA Runtime Build Complete!"
echo "[INFO] Library: $BUILD_DIR/libcuda_runtime.so"
echo "[INFO] To use in S training: LD_LIBRARY_PATH=$BUILD_DIR make pretrain-gpu"
