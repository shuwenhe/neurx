package neurx.quantization.backend_registry
func quant_none() int { 0 }
func quant_fp8() int { 1 }
func quant_mxfp8() int { 2 }
func quant_mxfp4() int { 3 }
func quant_nvfp4() int { 4 }
func quant_int8() int { 5 }
func quant_int4() int { 6 }
func quant_awq() int { 7 }
func quant_gptq() int { 8 }
func quant_gguf() int { 9 }
func quant_bitsandbytes() int { 10 }
func quant_torchao() int { 11 }
func quant_modelopt() int { 12 }
func quant_quark() int { 13 }
func quant_compressed_tensors() int { 14 }
struct quantization_backend_capability {
    int backend
    string name
    int weight_bits
    int activation_bits
    bool supports_cuda
    bool supports_rocm
    bool supports_cpu
    bool supports_moe
    bool supports_online
    bool supports_quantized_kv
}
struct quantization_request {
    int backend
    string platform
    bool is_moe
    bool online_quantization
    bool quantized_kv_cache
}
struct quantization_selection {
    int backend
    bool supported
    string error_message
}
func quantization_backend_name(int backend) string {
    if backend == quant_fp8() { return "fp8" }
    if backend == quant_mxfp8() { return "mxfp8" }
    if backend == quant_mxfp4() { return "mxfp4" }
    if backend == quant_nvfp4() { return "nvfp4" }
    if backend == quant_int8() { return "int8" }
    if backend == quant_int4() { return "int4" }
    if backend == quant_awq() { return "awq" }
    if backend == quant_gptq() { return "gptq" }
    if backend == quant_gguf() { return "gguf" }
    if backend == quant_bitsandbytes() { return "bitsandbytes" }
    if backend == quant_torchao() { return "torchao" }
    if backend == quant_modelopt() { return "modelopt" }
    if backend == quant_quark() { return "quark" }
    if backend == quant_compressed_tensors() { return "compressed_tensors" }
    "none"
}
func quantization_capability_for(int backend) quantization_backend_capability {
    if backend == quant_fp8() { return quantization_backend_capability {backend: backend, name: "fp8", weight_bits: 8, activation_bits: 8, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: true, supports_quantized_kv: true} }
    if backend == quant_mxfp8() { return quantization_backend_capability {backend: backend, name: "mxfp8", weight_bits: 8, activation_bits: 8, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: true, supports_quantized_kv: true} }
    if backend == quant_mxfp4() { return quantization_backend_capability {backend: backend, name: "mxfp4", weight_bits: 4, activation_bits: 8, supports_cuda: true, supports_rocm: true, supports_cpu: false, supports_moe: true, supports_online: true, supports_quantized_kv: false} }
    if backend == quant_nvfp4() { return quantization_backend_capability {backend: backend, name: "nvfp4", weight_bits: 4, activation_bits: 8, supports_cuda: true, supports_rocm: false, supports_cpu: false, supports_moe: true, supports_online: true, supports_quantized_kv: false} }
    if backend == quant_int8() { return quantization_backend_capability {backend: backend, name: "int8", weight_bits: 8, activation_bits: 8, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: true, supports_quantized_kv: true} }
    if backend == quant_int4() { return quantization_backend_capability {backend: backend, name: "int4", weight_bits: 4, activation_bits: 16, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: false, supports_quantized_kv: false} }
    if backend == quant_awq() { return quantization_backend_capability {backend: backend, name: "awq", weight_bits: 4, activation_bits: 16, supports_cuda: true, supports_rocm: true, supports_cpu: false, supports_moe: true, supports_online: false, supports_quantized_kv: false} }
    if backend == quant_gptq() { return quantization_backend_capability {backend: backend, name: "gptq", weight_bits: 4, activation_bits: 16, supports_cuda: true, supports_rocm: true, supports_cpu: false, supports_moe: true, supports_online: false, supports_quantized_kv: false} }
    if backend == quant_gguf() { return quantization_backend_capability {backend: backend, name: "gguf", weight_bits: 4, activation_bits: 16, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: false, supports_quantized_kv: false} }
    if backend == quant_bitsandbytes() { return quantization_backend_capability {backend: backend, name: "bitsandbytes", weight_bits: 4, activation_bits: 16, supports_cuda: true, supports_rocm: true, supports_cpu: false, supports_moe: true, supports_online: false, supports_quantized_kv: false} }
    if backend == quant_torchao() { return quantization_backend_capability {backend: backend, name: "torchao", weight_bits: 8, activation_bits: 8, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: true, supports_quantized_kv: false} }
    if backend == quant_modelopt() { return quantization_backend_capability {backend: backend, name: "modelopt", weight_bits: 8, activation_bits: 8, supports_cuda: true, supports_rocm: false, supports_cpu: false, supports_moe: true, supports_online: true, supports_quantized_kv: true} }
    if backend == quant_quark() { return quantization_backend_capability {backend: backend, name: "quark", weight_bits: 8, activation_bits: 8, supports_cuda: false, supports_rocm: true, supports_cpu: false, supports_moe: true, supports_online: true, supports_quantized_kv: true} }
    if backend == quant_compressed_tensors() { return quantization_backend_capability {backend: backend, name: "compressed_tensors", weight_bits: 8, activation_bits: 8, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: false, supports_quantized_kv: true} }
    quantization_backend_capability {backend: quant_none(), name: "none", weight_bits: 16, activation_bits: 16, supports_cuda: true, supports_rocm: true, supports_cpu: true, supports_moe: true, supports_online: false, supports_quantized_kv: false}
}
func select_quantization_backend(quantization_request request) quantization_selection {
    bool supported = request.backend >= quant_none() && request.backend <= quant_compressed_tensors()
    if request.platform == "cuda" && request.backend == quant_quark() { supported = false }
    if request.platform == "rocm" && (request.backend == quant_nvfp4() || request.backend == quant_modelopt()) { supported = false }
    if request.platform == "cpu" && (request.backend == quant_mxfp4() || request.backend == quant_nvfp4() || request.backend == quant_awq() || request.backend == quant_gptq() || request.backend == quant_bitsandbytes() || request.backend == quant_modelopt() || request.backend == quant_quark()) { supported = false }
    bool supports_online = request.backend == quant_fp8() || request.backend == quant_mxfp8() || request.backend == quant_mxfp4() || request.backend == quant_nvfp4() || request.backend == quant_int8() || request.backend == quant_torchao() || request.backend == quant_modelopt() || request.backend == quant_quark()
    if request.online_quantization && !supports_online { supported = false }
    bool supports_quantized_kv = request.backend == quant_fp8() || request.backend == quant_mxfp8() || request.backend == quant_int8() || request.backend == quant_modelopt() || request.backend == quant_quark() || request.backend == quant_compressed_tensors()
    if request.quantized_kv_cache && !supports_quantized_kv { supported = false }
    string error_message = ""
    if !supported { error_message = "quantization backend does not support the requested execution mode" }
    quantization_selection {backend: request.backend, supported: supported, error_message: error_message}
}
