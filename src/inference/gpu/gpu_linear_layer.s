package neurx.inference.gpu.gpu_linear_layer

use neurx.compute.gpu_gemm_engine
use neurx.device.cuda_runtime_binding
use neurx.inference.runtime.real_text_engine

struct gpu_linear_layer {
    gpu_gemm_engine* gemm_engine
    int64 weight_ptr
    int64 bias_ptr
    int in_features
    int out_features
    bool weights_uploaded
}

func new_gpu_linear_layer(gpu_gemm_engine* engine,
                         safetensors_model model,
                         string weight_name,
                         string bias_name,
                         int in_features,
                         int out_features) (gpu_linear_layer, bool, string) {
    
    layer := gpu_linear_layer{
        gemm_engine: engine,
        in_features: in_features,
        out_features: out_features,
        weights_uploaded: false,
    }
    
    weight_size_bytes := (in_features * out_features * 4) as int64
    weight_ptr, ok, err := cuda_malloc(weight_size_bytes)
    if !ok {
        return layer, false, "failed to allocate weight memory: " + err
    }
    layer.weight_ptr = weight_ptr
    
    bias_size_bytes := (out_features * 4) as int64
    bias_ptr, ok, err := cuda_malloc(bias_size_bytes)
    if !ok {
        cuda_free(weight_ptr)
        return layer, false, "failed to allocate bias memory: " + err
    }
    layer.bias_ptr = bias_ptr
    
    layer.weights_uploaded = true
    return layer, true, ""
}

func gpu_linear_forward(gpu_linear_layer* layer,
                       []float input,
                       []float output) (bool, string) {
    
    if len(input) % layer.in_features != 0 {
        return false, "input size mismatch"
    }
    
    if len(output) % layer.out_features != 0 {
        return false, "output size mismatch"
    }
    
    batch_size := len(input) / layer.in_features
    
    if batch_size <= 0 {
        return false, "invalid batch size"
    }
    
    input_gpu_ptr, ok, err := cuda_malloc((len(input) * 4) as int64)
    if !ok {
        return false, "failed to allocate input GPU memory: " + err
    }
    defer cuda_free(input_gpu_ptr)
    
    ok, err = cuda_memcpy_h2d(input as int64, input_gpu_ptr, (len(input) * 4) as int64)
    if !ok {
        return false, "failed to copy input to GPU: " + err
    }
    
    output_gpu_ptr, ok, err := cuda_malloc((len(output) * 4) as int64)
    if !ok {
        return false, "failed to allocate output GPU memory: " + err
    }
    defer cuda_free(output_gpu_ptr)
    
    input_matrix := gpu_matrix{
        device_ptr: input_gpu_ptr,
        rows: batch_size,
        cols: layer.in_features,
        size_bytes: (len(input) * 4) as int64,
    }
    
    weight_matrix := gpu_matrix{
        device_ptr: layer.weight_ptr,
        rows: layer.out_features,
        cols: layer.in_features,
        size_bytes: (layer.in_features * layer.out_features * 4) as int64,
    }
    
    output_matrix := gpu_matrix{
        device_ptr: output_gpu_ptr,
        rows: batch_size,
        cols: layer.out_features,
        size_bytes: (len(output) * 4) as int64,
    }
    
    ok, err = gpu_gemm(layer.gemm_engine,
                      input_matrix, weight_matrix,
                      &output_matrix,
                      1.0, 0.0)
    
    if !ok {
        return false, "GEMM failed: " + err
    }
    
    ok, err = cuda_memcpy_d2h(output_gpu_ptr, output as int64, (len(output) * 4) as int64)
    if !ok {
        return false, "failed to copy output from GPU: " + err
    }
    
    return true, ""
}

func gpu_linear_free(gpu_linear_layer* layer) (bool, string) {
    if layer.weight_ptr != 0 {
        cuda_free(layer.weight_ptr)
    }
    if layer.bias_ptr != 0 {
        cuda_free(layer.bias_ptr)
    }
    return true, ""
}

func gpu_batch_matmul(gpu_gemm_engine* engine,
                     int64 input_ptr,
                     int64 weight_ptr,
                     int64 output_ptr,
                     int batch,
                     int n,
                     int k,
                     int m) (bool, string) {
    
    int stride_input := n * k * 4
    int stride_output := n * m * 4
    int b := 0
    
    for b < batch {
        input_matrix := gpu_matrix{
            device_ptr: input_ptr + (b * stride_input) as int64,
            rows: n,
            cols: k,
            size_bytes: (n * k * 4) as int64,
        }
        
        weight_matrix := gpu_matrix{
            device_ptr: weight_ptr,
            rows: m,
            cols: k,
            size_bytes: (k * m * 4) as int64,
        }
        
        output_matrix := gpu_matrix{
            device_ptr: output_ptr + (b * stride_output) as int64,
            rows: n,
            cols: m,
            size_bytes: (n * m * 4) as int64,
        }
        
        ok, err := gpu_gemm(engine, input_matrix, weight_matrix, &output_matrix, 1.0, 0.0)
        if !ok {
            return false, "batch gemm failed at batch " + b + ": " + err
        }
        
        b = b + 1
    }
    
    return true, ""
}

func defer_cuda_free(ptr int64) {
    if ptr != 0 {
        cuda_free(ptr)
    }
}
