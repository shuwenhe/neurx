package neurx.compute.gpu_gemm_engine

use neurx.compute.cublas_binding
use neurx.device.cuda_runtime_binding
use neurx.device.cuda_stream_manager
use neurx.device.cuda_memory_pool
use std.vec.vec

struct gpu_matrix {
    int64 device_ptr
    int rows
    int cols
    int64 size_bytes
}

struct gpu_gemm_engine {
    cublas_handle_wrapper handle
    stream_pool* streams
    memory_pool* memory
    int device_id
    bool is_initialized
}

func new_gpu_gemm_engine(int device_id, int max_streams) (gpu_gemm_engine*, bool, string) {
    engine := box[gpu_gemm_engine]()
    
    ok, err := cuda_set_device(device_id)
    if !ok {
        return 0, false, err
    }
    
    handle, ok, err := cublas_create()
    if !ok {
        return 0, false, err
    }
    
    engine.handle = handle
    engine.device_id = device_id
    engine.is_initialized = true
    
    stream_pool := box[stream_pool](new_stream_pool(max_streams))
    ok, err = stream_pool_init(stream_pool)
    if !ok {
        return 0, false, err
    }
    engine.streams = stream_pool
    
    memory_pool := box[memory_pool](new_memory_pool(80 * 1024 * 1024 * 1024))
    engine.memory = memory_pool
    
    return engine, true, ""
}

func gpu_matrix_create(gpu_gemm_engine* engine, int rows, int cols) (gpu_matrix, bool, string) {
    size_bytes := rows * cols * 4
    
    ptr, ok, err := memory_pool_alloc(engine.memory, size_bytes as int64)
    if !ok {
        return gpu_matrix{}, false, err
    }
    
    return gpu_matrix{
        device_ptr: ptr,
        rows: rows,
        cols: cols,
        size_bytes: size_bytes as int64,
    }, true, ""
}

func gpu_matrix_free(gpu_gemm_engine* engine, gpu_matrix* matrix) (bool, string) {
    return memory_pool_free(engine.memory, matrix.device_ptr)
}

func gpu_matrix_h2d(gpu_gemm_engine* engine, int64 host_data, gpu_matrix* matrix) (bool, string) {
    return cuda_memcpy_h2d(host_data, matrix.device_ptr, matrix.size_bytes)
}

func gpu_matrix_d2h(gpu_gemm_engine* engine, gpu_matrix* matrix, int64 host_data) (bool, string) {
    return cuda_memcpy_d2h(matrix.device_ptr, host_data, matrix.size_bytes)
}

func gpu_gemm(gpu_gemm_engine* engine,
             gpu_matrix a, gpu_matrix b,
             gpu_matrix* c,
             float alpha, float beta) (bool, string) {
    
    if a.cols != b.rows {
        return false, "dimension mismatch: A.cols != B.rows"
    }
    if a.rows != c.rows || b.cols != c.cols {
        return false, "output dimension mismatch"
    }
    
    ok, err := cublas_sgemm(
        engine.handle.handle,
        0, 0,
        a.rows, b.cols, a.cols,
        alpha,
        a.device_ptr, a.rows,
        b.device_ptr, b.rows,
        beta,
        c.device_ptr, c.rows
    )
    
    return ok, err
}

func gpu_gemm_batch(gpu_gemm_engine* engine,
                   vec[gpu_matrix] a_batch,
                   vec[gpu_matrix] b_batch,
                   vec[gpu_matrix]* c_batch,
                   float alpha, float beta) (bool, string) {
    
    if a_batch.len() != b_batch.len() || b_batch.len() != c_batch.len() {
        return false, "batch size mismatch"
    }
    
    for i := 0; i < a_batch.len(); i = i + 1 {
        ok, err := gpu_gemm(engine, a_batch[i], b_batch[i], &c_batch[i], alpha, beta)
        if !ok {
            return false, err
        }
    }
    
    return true, ""
}

func gpu_linear(engine: gpu_gemm_engine*,
               input: gpu_matrix,
               weight: gpu_matrix,
               bias: gpu_matrix*,
               output: gpu_matrix*) (bool, string) {
    
    if input.cols != weight.cols {
        return false, "weight dimension mismatch"
    }
    if output.rows != input.rows || output.cols != weight.rows {
        return false, "output dimension mismatch"
    }
    
    ok, err := cublas_matmul_tb(
        engine.handle.handle,
        input.device_ptr, input.rows, input.cols,
        weight.device_ptr, weight.rows, weight.cols,
        output.device_ptr
    )
    
    if !ok {
        return false, err
    }
    
    return true, ""
}

func gpu_transpose(gpu_gemm_engine* engine,
                  gpu_matrix input,
                  gpu_matrix* output) (bool, string) {
    
    if input.rows != output.cols || input.cols != output.rows {
        return false, "output shape should be transposed input"
    }
    
    ok, err := cublas_sgemm(
        engine.handle.handle,
        1, 0,
        input.cols, input.rows, input.rows,
        1.0,
        input.device_ptr, input.rows,
        input.device_ptr, input.rows,
        0.0,
        output.device_ptr, input.cols
    )
    
    return ok, err
}

func gpu_gemm_engine_finalize(gpu_gemm_engine* engine) (bool, string) {
    if !engine.is_initialized {
        return true, ""
    }
    
    ok, err := stream_pool_finalize(engine.streams)
    if !ok {
        return false, err
    }
    
    ok, err = memory_pool_finalize(engine.memory)
    if !ok {
        return false, err
    }
    
    ok, err = cublas_destroy(&engine.handle)
    engine.is_initialized = false
    
    return ok, err
}

func gpu_gemm_engine_get_memory_stats(gpu_gemm_engine* engine) (int64, int64, int, int) {
    return memory_pool_stats(engine.memory)
}

func gpu_gemm_engine_synchronize(gpu_gemm_engine* engine) (bool, string) {
    return cuda_device_synchronize()
}
