package neurx.runtime.device.device_ops
use neurx.runtime.device.device_abi.{device_backend_capability, device_feature_enabled, device_feature_paged_attention}

func op_int_string(int value) string {
    if value == 0 { return "0" }
    string output = ""
    int current = value
    for current > 0 { output = string(48 + current % 10) + output; current = current / 10 }
    output
}

struct device_op {
    string kind
    string descriptor
    bool valid
    string error_message
}

func op_descriptor(string kind, string attributes) device_op {
    if kind == "" { return device_op {kind: kind, descriptor: "", valid: false, error_message: "missing_op_kind"} }
    device_op {kind: kind, descriptor: "v1;op=" + kind + ";" + attributes, valid: true, error_message: ""}
}

func op_embedding(string dtype, int hidden) device_op {
    op_descriptor("embedding", "dtype=" + dtype + ";hidden=" + op_int_string(hidden))
}

func op_rms_norm(string dtype, int hidden, string epsilon) device_op {
    op_descriptor("rms_norm", "dtype=" + dtype + ";hidden=" + op_int_string(hidden) + ";epsilon=" + epsilon)
}

func op_linear(string dtype, int input, int output, bool bias) device_op {
    string bias_value = "0"
    if bias { bias_value = "1" }
    op_descriptor("linear", "dtype=" + dtype + ";input=" + op_int_string(input) + ";output=" + op_int_string(output) + ";bias=" + bias_value)
}

func op_rope(string dtype, int heads, int head_dim, string theta) device_op {
    op_descriptor("rope", "dtype=" + dtype + ";heads=" + op_int_string(heads) + ";head_dim=" + op_int_string(head_dim) + ";theta=" + theta)
}

func op_paged_attention(string dtype, int query_heads, int kv_heads, int head_dim) device_op {
    op_descriptor("paged_attention", "dtype=" + dtype + ";query_heads=" + op_int_string(query_heads) + ";kv_heads=" + op_int_string(kv_heads) + ";head_dim=" + op_int_string(head_dim))
}

func op_swiglu(string dtype, int intermediate) device_op {
    op_descriptor("swiglu", "dtype=" + dtype + ";intermediate=" + op_int_string(intermediate))
}

func op_residual_add(string dtype, int elements) device_op {
    op_descriptor("residual_add", "dtype=" + dtype + ";elements=" + op_int_string(elements))
}

func op_backend_supported(device_backend_capability capability, device_op operation) bool {
    if !capability.available || !operation.valid { return false }
    if operation.kind == "paged_attention" && !device_feature_enabled(capability, device_feature_paged_attention()) { return false }
    true
}
