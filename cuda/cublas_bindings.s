package neurx.cuda_bindings
use std.io.println
extern func cuda_malloc(int size) int64
extern func cuda_free(int64 ptr) int
extern func cuda_memcpy_h2d(int64 dst, int src_ptr, int size) int
extern func cuda_memcpy_d2h(int dst_ptr, int64 src, int size) int
extern func cuda_device_synchronize() int
extern func cublas_create() int64
extern func cublas_destroy(int64 handle) int
extern func cublas_set_stream(int64 handle, int64 stream) int
extern func cublas_sgemm(
    int64 handle,
    int transa,
    int transb,
    int m,
    int n,
    int k,
    float alpha,
    int64 A,
    int lda,
    int64 B,
    int ldb,
    float beta,
    int64 C,
    int ldc
) int
extern func cublas_sgemv(
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
extern func cublas_sdot(
    int64 handle,
    int n,
    int64 x,
    int incx,
    int64 y,
    int incy,
    float* result
) int
extern func cublas_strmm(
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

struct gpu_tensor {
    int64 device_ptr
    int size
    int rows
    int cols
    bool is_allocated
}

struct cuda_context {
    int64 cublas_handle
    bool initialized
}

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
        println("[ERROR] matrix dimension mismatch: A.cols=" + int_to_str(A.cols) + " != B.rows=" + int_to_str(B.rows))
        return -1
    }
    int status = cublas_sgemm(
        ctx.cublas_handle,
        0,
        0,
        A.rows,
        B.cols,
        A.cols,
        1.0,
        A.device_ptr,
        A.cols,
        B.device_ptr,
        B.cols,
        0.0,
        C.device_ptr,
        C.cols
    )
    if status != 0 {
        println("[ERROR] cublasSgemm failed with status " + int_to_str(status))
        return status
    }
    cuda_device_synchronize()
    status
}

func gpu_matrix_multiply_backward_a(
    cuda_context ctx,
    gpu_tensor grad_c,
    gpu_tensor B,
    gpu_tensor* grad_a
) int {
    if !ctx.initialized {
        return -1
    }
    int status = cublas_sgemm(
        ctx.cublas_handle,
        0,
        1,
        grad_c.rows,
        B.rows,
        grad_c.cols,
        1.0,
        grad_c.device_ptr,
        grad_c.cols,
        B.device_ptr,
        B.cols,
        0.0,
        grad_a.device_ptr,
        grad_a.cols
    )
    cuda_device_synchronize()
    status
}

func gpu_matrix_multiply_backward_b(
    cuda_context ctx,
    gpu_tensor A,
    gpu_tensor grad_c,
    gpu_tensor* grad_b
) int {
    if !ctx.initialized {
        return -1
    }
    int status = cublas_sgemm(
        ctx.cublas_handle,
        1,
        0,
        A.cols,
        grad_c.cols,
        A.rows,
        1.0,
        A.device_ptr,
        A.cols,
        grad_c.device_ptr,
        grad_c.cols,
        0.0,
        grad_b.device_ptr,
        grad_b.cols
    )
    cuda_device_synchronize()
    status
}

func init_cuda_context() cuda_context {
    println("[CUDA] Initializing cuBLAS context...")
    int64 handle = cublas_create()
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
    int status = cublas_destroy(ctx.cublas_handle)
    ctx.initialized = false
    status
}

func allocate_gpu_tensor(int rows, int cols) gpu_tensor {
    int size = rows * cols
    int bytes = size * 4
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
