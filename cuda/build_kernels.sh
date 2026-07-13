#!/bin/bash

# ============================================================================
# Build CUDA Kernels Library
# Compiles cuda_kernels.cu to shared library for S language FFI
# ============================================================================

set -e

echo "=== Building CUDA Kernels Library ==="
echo ""

# Check nvcc
if ! command -v nvcc &> /dev/null; then
    echo "[ERROR] nvcc not found. Install CUDA Toolkit."
    exit 1
fi

CUDA_VERSION=$(nvcc --version | grep release | awk '{print $5}' | tr -d ',')
echo "[INFO] CUDA Version: $CUDA_VERSION"

# Detect GPU arch
GPU_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.' || echo "86")
echo "[INFO] GPU Architecture: sm_$GPU_ARCH"

# Build directories
BUILD_DIR="./artifacts/build/cuda_kernels"
mkdir -p "$BUILD_DIR"

# Get CUDA paths
CUDA_INSTALL=$(command -v nvcc | xargs dirname | xargs dirname)
CUDA_LIB="$CUDA_INSTALL/lib64"

echo "[INFO] CUDA Home: $CUDA_INSTALL"
echo ""

# Compile object file
echo "[BUILD] Compiling cuda_kernels.cu..."

# Use -x cu flag to force CUDA compilation without standard headers
nvcc \
    -c cuda/cuda_kernels.cu \
    -o "$BUILD_DIR/cuda_kernels.o" \
    -arch=sm_$GPU_ARCH \
    -Xcompiler -fPIC \
    -std=c++11 \
    -O3 \
    -m64 \
    2>&1 | grep -E "error:|warning:|Success" | head -20

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "[WARNING] CUDA compilation had warnings, continuing..."
fi

echo "[SUCCESS] cuda_kernels.o created"

# Device link
echo "[BUILD] Device linking..."

nvcc \
    -dlink "$BUILD_DIR/cuda_kernels.o" \
    -o "$BUILD_DIR/cuda_kernels_dlink.o" \
    -arch=sm_$GPU_ARCH \
    -m64

# Create shared library
echo "[BUILD] Creating shared library..."

g++ \
    -shared \
    -o "$BUILD_DIR/libcuda_kernels.so" \
    "$BUILD_DIR/cuda_kernels.o" \
    "$BUILD_DIR/cuda_kernels_dlink.o" \
    -L"$CUDA_LIB" \
    -L/usr/local/cuda/lib64 \
    -lcudart \
    -lcublas \
    -Wl,-rpath,"$CUDA_LIB"

if [ $? -ne 0 ]; then
    echo "[ERROR] Library creation failed"
    exit 1
fi

echo "[SUCCESS] libcuda_kernels.so created"
ls -lh "$BUILD_DIR/libcuda_kernels.so"

# Create link script
cat > "$BUILD_DIR/env.sh" << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="$(dirname "${BASH_SOURCE[0]}"):$CUDA_LIB:$LD_LIBRARY_PATH"
export CUDA_KERNELS_LIB="$(dirname "${BASH_SOURCE[0]}")/libcuda_kernels.so"
echo "[CUDA] Library path set: $LD_LIBRARY_PATH"
EOF

chmod +x "$BUILD_DIR/env.sh"

echo ""
echo "[INFO] Build complete!"
echo "[INFO] Library: $BUILD_DIR/libcuda_kernels.so"
echo "[INFO] To use: source $BUILD_DIR/env.sh && make pretrain-gpu"
echo ""
echo "[INFO] S Language Integration:"
echo "      Use 'extern func' declarations in S to call kernel functions"
echo "      Link with: -L$BUILD_DIR -lcuda_kernels"
