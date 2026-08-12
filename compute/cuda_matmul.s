package neurx.compute.cuda_matmul

use neurx.backends.cuda_core

struct cuda_matrix {
    int rows
    int columns
    string dtype
    cuda_buffer storage
}


struct cuda_matmul_result {
    cuda_context context
    cuda_matrix output
    int floating_point_operations
    bool success
    string error_message
}


func cuda_empty_matrix() cuda_matrix {
    cuda_matrix value
    value.rows = 0
    value.columns = 0
    value.dtype = "float32"
    value.storage = neurx.backends.cuda_core.cuda_empty_buffer()
    value
}


func cuda_new_matrix(cuda_context context, int rows, int columns, string dtype) cuda_matmul_result {
    cuda_matmul_result result
    result.context = context
    result.output = cuda_empty_matrix()
    result.floating_point_operations = 0
    result.success = false
    result.error_message = ""
    if rows <= 0 || columns <= 0 {
        result.error_message = "matrix dimensions must be positive"
        return result
    }
    if dtype != "float32" {
        result.error_message = "current cuBLAS path requires float32"
        return result
    }
    int bytes = rows * columns * 4
    cuda_context_result allocation = neurx.backends.cuda_core.cuda_allocate(context, bytes)
    result.context = allocation.context
    if !allocation.success {
        result.error_message = allocation.error_message
        return result
    }
    result.output.rows = rows
    result.output.columns = columns
    result.output.dtype = dtype
    result.output.storage = allocation.buffer
    result.success = true
    result
}


func cuda_matrix_multiply(cuda_context context, cuda_matrix left, cuda_matrix right) cuda_matmul_result {
    cuda_matmul_result result
    result.context = context
    result.output = cuda_empty_matrix()
    result.floating_point_operations = 0
    result.success = false
    result.error_message = ""
    if left.columns != right.rows || left.rows <= 0 || right.columns <= 0 {
        result.error_message = "matrix dimensions do not align"
        return result
    }
    if left.dtype != "float32" || right.dtype != "float32" {
        result.error_message = "current cuBLAS path requires float32"
        return result
    }
    cuda_matmul_result allocation = cuda_new_matrix(context, left.rows, right.columns, "float32")
    result.context = allocation.context
    if !allocation.success {
        result.error_message = allocation.error_message
        return result
    }
    result.output = allocation.output
    result.floating_point_operations = 2 * left.rows * right.columns * left.columns
    result.success = neurx.backends.cuda_core.cuda_sgemm(result.context, left.storage, right.storage, result.output.storage, left.rows, right.columns, left.columns)
    if !result.success { result.error_message = "cuBLAS SGEMM failed" }
    result
}


func cuda_matmul_contract_valid(cuda_matrix left, cuda_matrix right) bool {
    left.rows > 0 && left.columns > 0 && right.rows == left.columns && right.columns > 0
}

