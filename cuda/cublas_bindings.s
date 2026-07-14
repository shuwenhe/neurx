// ============================================================================
// NeurX CUDA Runtime Bindings - cuBLAS Matrix Operations
// Language: S with C FFI
// Purpose: Actual GPU matrix operations for training
// ============================================================================

package neurx.cuda_bindings

use std.io.println

// ============================================================================
// External C/CUDA Functions (FFI Bindings)
// ============================================================================

// CUDA Memory Management
extern func cuda_malloc(int size) int64
extern func cuda_free(int64 ptr) int
extern func cuda_memcpy_h2d(int64 dst, int src_ptr, int size) int
extern func cuda_memcpy_d2h(int dst_ptr, int64 src, int size) int
extern func cuda_device_synchronize() int

// cuBLAS Initialization
extern func cublasCreate() int64  // returns handle
extern func cublasDestroy(int64 handle) int
extern func cublasSetStream(int64 handle, int64 stream) int

// Matrix Operations: y = alpha*op(A)*op(B) + beta*C
// Single precision (float)
extern func cublasSgemm(
    int64 handle,           // cuBLAS handle
    int transa,             // transpose mode for A (0=no, 1=yes)
    int transb,             // transpose mode for B
    int m,                  // rows of op(A) and C
    int n,                  // cols of op(B) and C
    int k,                  // cols of op(A) and rows of op(B)
    float alpha,            // scalar multiplier
    int64 A,                // device pointer to A
    int lda,                // leading dimension of A
    int64 B,                // device pointer to B
    int ldb,                // leading dimension of B
    float beta,             // scalar for C
    int64 C,                // device pointer to C (in/out)
    int ldc                 // leading dimension of C
) int

// Matrix-Vector: y = alpha*op(A)*x + beta*y
extern func cublasSgemv(
    int64 handle,
    int trans,
    int m,
    int n,
    float alpha,
    int64 A,
    int lda,
    int64 x,
    int incx,
    float beta,
    int64 y,
    int incy
) int

// Vector dot product
extern func cublasSdot(
    int64 handle,
    int n,
    int64 x,
    int incx,
    int64 y,
    int incy,
    float* result          // output scalar
) int

// Vector element-wise multiply: y *= x
extern func cublasStrmm(
    int64 handle,
    int side,
    int uplo,
    int transa,
    int diag,
    int m,
    int n,
    float alpha,
    int64 A,
    int lda,
    int64 B,
    int ldb
) int

// ============================================================================
// GPU Tensor Buffer - Wrapper for GPU Memory
// ============================================================================

struct gpu_tensor {
    int64 device_ptr       // GPU memory address
    int size               // Total elements
    int rows               // Matrix rows (for GEMM)
    int cols               // Matrix columns
    bool is_allocated      // Whether memory is allocated
}

// ============================================================================
// CUDA Context Wrapper
// ============================================================================

struct cuda_context {
    int64 cublas_handle    // cuBLAS library handle
    bool initialized       // Context initialized flag
}

// ============================================================================
// Matrix Operations Layer
// ============================================================================

// Forward: C = A @ B  (matrix multiply)
func gpu_matrix_multiply(
    cuda_context ctx,
    gpu_tensor A,
    gpu_tensor B,
    gpu_tensor* C
) int {
    if !ctx.initialized {
        println("[ERROR] CUDA context not initialized")
        return -1
    }
    
    if A.cols != B.rows {
        println("[ERROR] Matrix dimension mismatch: A.cols=" + int_to_str(A.cols) + " != B.rows=" + int_to_str(B.rows))
        return -1
    }
    
    // Call cuBLAS: C = alpha*A*B + beta*C
    int status = cublasSgemm(
        ctx.cublas_handle,
        0,                      // No transpose A
        0,                      // No transpose B
        A.rows,                 // M rows of A
        B.cols,                 // N cols of B
        A.cols,                 // K inner dimension
        1.0,                    // alpha = 1.0
        A.device_ptr,           // A on GPU
        A.cols,                 // lda
        B.device_ptr,           // B on GPU
        B.cols,                 // ldb
        0.0,                    // beta = 0.0 (don't accumulate)
        C.device_ptr,           // C on GPU (output)
        C.cols                  // ldc
    )
    
    if status != 0 {
        println("[ERROR] cublasSgemm failed with status " + int_to_str(status))
        return status
    }
    
    // Synchronize device
    cuda_device_synchronize()
    
    status
}

// Backward: Gradient w.r.t. A = grad_C @ B^T
func gpu_matrix_multiply_backward_A(
    cuda_context ctx,
    gpu_tensor grad_C,
    gpu_tensor B,
    gpu_tensor* grad_A
) int {
    if !ctx.initialized {
        return -1
    }
    
    // grad_A = grad_C @ B^T
    // Use cublasSgemm with transB=1
    int status = cublasSgemm(
        ctx.cublas_handle,
        0,                      // No transpose grad_C
        1,                      // TRANSPOSE B
        grad_C.rows,            // M
        B.rows,                 // N (B.rows becomes N due to transpose)
        grad_C.cols,            // K
        1.0,                    // alpha
        grad_C.device_ptr,      // grad_C
        grad_C.cols,            // lda
        B.device_ptr,           // B
        B.cols,                 // ldb
        0.0,                    // beta
        grad_A.device_ptr,      // grad_A output
        grad_A.cols             // ldc
    )
    
    cuda_device_synchronize()
    status
}

// Backward: Gradient w.r.t. B = A^T @ grad_C
func gpu_matrix_multiply_backward_B(
    cuda_context ctx,
    gpu_tensor A,
    gpu_tensor grad_C,
    gpu_tensor* grad_B
) int {
    if !ctx.initialized {
        return -1
    }
    
    // grad_B = A^T @ grad_C
    int status = cublasSgemm(
        ctx.cublas_handle,
        1,                      // TRANSPOSE A
        0,                      // No transpose grad_C
        A.cols,                 // M (A.cols due to transpose)
        grad_C.cols,            // N
        A.rows,                 // K
        1.0,                    // alpha
        A.device_ptr,           // A
        A.cols,                 // lda
        grad_C.device_ptr,      // grad_C
        grad_C.cols,            // ldb
        0.0,                    // beta
        grad_B.device_ptr,      // grad_B output
        grad_B.cols             // ldc
    )
    
    cuda_device_synchronize()
    status
}

// ============================================================================
// Initialization & Cleanup
// ============================================================================

func init_cuda_context() cuda_context {
    println("[CUDA] Initializing cuBLAS context...")
    
    int64 handle = cublasCreate()
    
    cuda_context{
        cublas_handle: handle,
        initialized: handle != 0,
    }
}

func destroy_cuda_context(cuda_context* ctx) int {
    if !ctx.initialized {
        return 0
    }
    
    println("[CUDA] Destroying cuBLAS context...")
    int status = cublasDestroy(ctx.cublas_handle)
    ctx.initialized = false
    status
}

// ============================================================================
// Memory Management
// ============================================================================

func allocate_gpu_tensor(int rows, int cols) gpu_tensor {
    int size = rows * cols
    int bytes = size * 4  // float32 = 4 bytes
    
    println("[CUDA] Allocating GPU memory: " + int_to_str(rows) + "x" + int_to_str(cols) + " (" + int_to_str(bytes) + " bytes)")
    
    int64 ptr = cuda_malloc(bytes)
    
    if ptr == 0 {
        println("[ERROR] CUDA malloc failed")
    }
    
    gpu_tensor{
        device_ptr: ptr,
        size: size,
        rows: rows,
        cols: cols,
        is_allocated: ptr != 0,
    }
}

func free_gpu_tensor(gpu_tensor* tensor) int {
    if tensor.is_allocated && tensor.device_ptr != 0 {
        println("[CUDA] Freeing GPU memory: " + int_to_str(tensor.size) + " elements")
        cuda_free(tensor.device_ptr)
        tensor.is_allocated = false
    }
    0
}

// ============================================================================
// Helper Functions
// ============================================================================

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool neg = value < 0
    if neg { value = 0 - value }
    string out = ""
    while value > 0 {
        int quotient = 0
        int digit = value
        while digit >= 10 {
            digit = digit - 10
            quotient = quotient + 1
        }
        out = string_char(digit + 48) + out
        value = quotient
    }
    if neg { out = "-" + out }
    out
}

func string_char(int c) string {
    string(c)
}
