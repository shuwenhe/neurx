package neurx.compute.cublas_binding

use neurx.device.cuda_runtime_binding

extern func cublasCreate(void* handle_ptr) -> int
extern func cublasDestroy(int64 handle) -> int
extern func cublasSgemm(int64 handle,
                       int transa, int transb,
                       int m, int n, int k,
                       float alpha,
                       void* a, int lda,
                       void* b, int ldb,
                       float beta,
                       void* c, int ldc) -> int
extern func cublasHgemm(int64 handle,
                       int transa, int transb,
                       int m, int n, int k,
                       void* alpha,
                       void* a, int lda,
                       void* b, int ldb,
                       void* beta,
                       void* c, int ldc) -> int

int CUBLAS_OP_N = 0
int CUBLAS_OP_T = 1
int CUBLAS_OP_C = 2

int CUBLAS_STATUS_SUCCESS = 0
int CUBLAS_STATUS_NOT_INITIALIZED = 1
int CUBLAS_STATUS_ALLOC_FAILED = 3
int CUBLAS_STATUS_INVALID_VALUE = 7
int CUBLAS_STATUS_ARCH_MISMATCH = 8
int CUBLAS_STATUS_MAPPING_ERROR = 11
int CUBLAS_STATUS_EXECUTION_FAILED = 13

struct cublas_handle_wrapper {
    int64 handle
    bool is_valid
}

func cublas_create() (cublas_handle_wrapper, bool, string) {
    handle_ptr := 0
    status := cublasCreate(&handle_ptr)
    if status != CUBLAS_STATUS_SUCCESS {
        return cublas_handle_wrapper{}, false, "cublas create failed"
    }
    return cublas_handle_wrapper{
        handle: handle_ptr as int64,
        is_valid: true,
    }, true, ""
}

func cublas_destroy(cublas_handle_wrapper* wrapper) (bool, string) {
    if !wrapper.is_valid {
        return false, "handle invalid"
    }
    status := cublasDestroy(wrapper.handle)
    wrapper.is_valid = false
    if status != CUBLAS_STATUS_SUCCESS {
        return false, "cublas destroy failed"
    }
    return true, ""
}

func cublas_sgemm(int64 handle,
                 int transa, int transb,
                 int m, int n, int k,
                 float alpha,
                 int64 a_ptr, int lda,
                 int64 b_ptr, int ldb,
                 float beta,
                 int64 c_ptr, int ldc) (bool, string) {
    status := cublasSgemm(handle, transa, transb, m, n, k, alpha,
                         a_ptr as void*, lda,
                         b_ptr as void*, ldb,
                         beta,
                         c_ptr as void*, ldc)
    if status != CUBLAS_STATUS_SUCCESS {
        return false, "sgemm failed"
    }
    return true, ""
}

func cublas_matmul_standard(int64 handle,
                           int64 a_ptr, int a_m, int a_k,
                           int64 b_ptr, int b_k, int b_n,
                           int64 c_ptr) (bool, string) {

    return cublas_sgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N,
                       a_m, b_n, a_k,
                       1.0, a_ptr, a_m,
                       b_ptr, b_k,
                       0.0, c_ptr, a_m)
}

func cublas_matmul_ta(int64 handle,
                     int64 a_ptr, int a_k, int a_m,
                     int64 b_ptr, int b_k, int b_n,
                     int64 c_ptr) (bool, string) {
    return cublas_sgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N,
                       a_m, b_n, a_k,
                       1.0, a_ptr, a_k,
                       b_ptr, b_k,
                       0.0, c_ptr, a_m)
}

func cublas_matmul_tb(int64 handle,
                     int64 a_ptr, int a_m, int a_k,
                     int64 b_ptr, int b_n, int b_k,
                     int64 c_ptr) (bool, string) {
    return cublas_sgemm(handle, CUBLAS_OP_N, CUBLAS_OP_T,
                       a_m, b_n, a_k,
                       1.0, a_ptr, a_m,
                       b_ptr, b_n,
                       0.0, c_ptr, a_m)
}
