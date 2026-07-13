#!/bin/bash

# ============================================================================
# NeurX CUDA Runtime Compilation - Alternative with nvcc plugin
# ============================================================================

set -e

echo "=== NeurX CUDA Runtime Build (Alternative) ==="
echo ""

# Check CUDA installation
if ! command -v nvcc &> /dev/null; then
    echo "[ERROR] nvcc not found. Install CUDA Toolkit."
    exit 1
fi

# Variables
BUILD_DIR="./artifacts/build/cuda_runtime"
mkdir -p "$BUILD_DIR"

# Get CUDA paths
CUDA_INSTALL=$(command -v nvcc | xargs dirname | xargs dirname)
CUDA_LIB="$CUDA_INSTALL/lib64"
GPU_ARCH="89"  # RTX 4060 Ti

echo "[INFO] CUDA: $CUDA_INSTALL"
echo "[INFO] CUDA Lib: $CUDA_LIB"
echo "[INFO] GPU Architecture: sm_$GPU_ARCH"

# Create header-only version of wrapper
cat > "$BUILD_DIR/cuda_api.h" << 'EOF'
#ifndef CUDA_API_H
#define CUDA_API_H

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>

// Memory management
int64_t cuda_malloc_api(int size) {
    void *ptr = NULL;
    cudaMalloc(&ptr, size);
    return (int64_t)ptr;
}

int cuda_free_api(int64_t ptr) {
    if (ptr) cudaFree((void*)ptr);
    return 0;
}

int cuda_memcpy_h2d_api(int64_t dst, int src_ptr, int size) {
    cudaMemcpy((void*)dst, (void*)src_ptr, size, cudaMemcpyHostToDevice);
    return 0;
}

int cuda_memcpy_d2h_api(int dst_ptr, int64_t src, int size) {
    cudaMemcpy((void*)dst_ptr, (void*)src, size, cudaMemcpyDeviceToHost);
    return 0;
}

int cuda_synchronize_api() {
    cudaDeviceSynchronize();
    return 0;
}

// cuBLAS wrappers
int64_t cublas_create_api() {
    cublasHandle_t handle;
    cublasCreate_v2(&handle);
    return (int64_t)handle;
}

int cublas_destroy_api(int64_t handle) {
    cublasDestroy_v2((cublasHandle_t)handle);
    return 0;
}

int cublas_sgemm_api(
    int64_t handle, int ta, int tb,
    int m, int n, int k,
    float alpha, int64_t A, int lda,
    int64_t B, int ldb, float beta,
    int64_t C, int ldc
) {
    cublasOperation_t opa = (ta == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublasOperation_t opb = (tb == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublasSgemm_v2(
        (cublasHandle_t)handle, opa, opb, m, n, k,
        &alpha, (const float*)A, lda,
        (const float*)B, ldb,
        &beta, (float*)C, ldc
    );
    return 0;
}

#endif
EOF

echo "[CREATE] Header file: cuda_api.h"

# Compile header-only implementation with nvcc + CUDA
nvcc \
    --lib \
    --gpu-architecture sm_${GPU_ARCH} \
    --compiler-options "-fPIC" \
    -o "$BUILD_DIR/libcuda_api.a" \
    "$BUILD_DIR/cuda_api.h" \
    2>/dev/null || true

# Alternative: Create minimal stub library
echo "[CREATE] Creating stub library for FFI..."

gcc \
    -shared \
    -fPIC \
    -o "$BUILD_DIR/libcuda_runtime.so" \
    -L"$CUDA_LIB" \
    -L/usr/local/cuda/lib64 \
    -lcudart \
    -lcublas \
    -Wl,-rpath,"$CUDA_LIB" \
    <<'GCCCODE'
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>

int64_t cuda_malloc(int size) {
    void *ptr = NULL;
    cudaMalloc(&ptr, size);
    return (int64_t)ptr;
}

int cuda_free(int64_t ptr) {
    cudaFree((void*)ptr);
    return 0;
}

int cuda_memcpy_h2d(int64_t dst, int src_ptr, int size) {
    cudaMemcpy((void*)dst, (void*)src_ptr, size, cudaMemcpyHostToDevice);
    return 0;
}

int cuda_memcpy_d2h(int dst_ptr, int64_t src, int size) {
    cudaMemcpy((void*)dst_ptr, (void*)src, size, cudaMemcpyDeviceToHost);
    return 0;
}

int cuda_device_synchronize() {
    cudaDeviceSynchronize();
    return 0;
}

int64_t cublasCreate() {
    cublasHandle_t handle;
    cublasCreate_v2(&handle);
    return (int64_t)handle;
}

int cublasDestroy(int64_t handle) {
    cublasDestroy_v2((cublasHandle_t)handle);
    return 0;
}

int cublasSgemm(int64_t h, int ta, int tb, int m, int n, int k,
                float alpha, int64_t A, int lda,
                int64_t B, int ldb, float beta,
                int64_t C, int ldc) {
    cublasOperation_t opa = (ta == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublasOperation_t opb = (tb == 0) ? CUBLAS_OP_N : CUBLAS_OP_T;
    cublasSgemm_v2((cublasHandle_t)h, opa, opb, m, n, k,
                   &alpha, (const float*)A, lda,
                   (const float*)B, ldb,
                   &beta, (float*)C, ldc);
    return 0;
}
GCCCODE

if [ $? -eq 0 ]; then
    echo "[SUCCESS] libcuda_runtime.so created"
    ls -lh "$BUILD_DIR/libcuda_runtime.so"
else
    echo "[ERROR] Failed to create library"
    exit 1
fi

# Create link script
cat > "$BUILD_DIR/link.sh" << EOF
#!/bin/bash
export LD_LIBRARY_PATH="$CUDA_LIB:$BUILD_DIR:\$LD_LIBRARY_PATH"
echo "CUDA Runtime Library Path:"
echo "  \$LD_LIBRARY_PATH"
EOF

chmod +x "$BUILD_DIR/link.sh"

echo ""
echo "[INFO] Build complete!"
echo "[INFO] To use: source $BUILD_DIR/link.sh"
echo "[INFO] Library: $BUILD_DIR/libcuda_runtime.so"
