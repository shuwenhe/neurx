package neurx.runtime.device.vendor_lowering
use neurx.runtime.device.device_ops.{device_op}

struct lowered_op {
    string backend
    string vendor_op
    string descriptor
    bool valid
    string error_message
}

func lower_vendor_name(string backend, string kind) string {
    if backend == "cuda" {
        if kind == "linear" { return "cublaslt_matmul" }
        if kind == "paged_attention" { return "cuda_paged_attention" }
        if kind == "rms_norm" { return "cuda_rms_norm" }
        if kind == "rope" { return "cuda_rope" }
        if kind == "swiglu" { return "cuda_swiglu" }
        return "cuda_kernel"
    }
    if backend == "cann" || backend == "ascend" {
        if kind == "linear" { return "aclnn_matmul" }
        if kind == "paged_attention" { return "atb_paged_attention" }
        if kind == "rms_norm" { return "aclnn_rms_norm" }
        if kind == "rope" { return "atb_rope" }
        if kind == "swiglu" { return "atb_swiglu" }
        return "aclnn_custom"
    }
    kind
}

func lower_cuda(device_op operation) lowered_op {
    string vendor = lower_vendor_name("cuda", operation.kind)
    lowered_op {backend: "cuda", vendor_op: vendor, descriptor: operation.descriptor + ";lowering=" + vendor, valid: operation.valid, error_message: operation.error_message}
}

func lower_cann(device_op operation) lowered_op {
    string vendor = lower_vendor_name("cann", operation.kind)
    lowered_op {backend: "cann", vendor_op: vendor, descriptor: operation.descriptor + ";lowering=" + vendor, valid: operation.valid, error_message: operation.error_message}
}

func lower_device_op(string backend, bool available, device_op operation) lowered_op {
    if !available { return lowered_op {backend: backend, vendor_op: "", descriptor: "", valid: false, error_message: "backend_unavailable"} }
    if backend == "cuda" { return lower_cuda(operation) }
    if backend == "cann" || backend == "ascend" { return lower_cann(operation) }
    lowered_op {backend: backend, vendor_op: operation.kind, descriptor: operation.descriptor + ";lowering=reference", valid: operation.valid, error_message: operation.error_message}
}
