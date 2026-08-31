package neurx.inference.runtime.device_transformer
use neurx.runtime.device.device_ops.{device_op, op_embedding, op_rms_norm, op_linear, op_rope, op_paged_attention, op_swiglu, op_residual_add}
use neurx.runtime.device.vendor_lowering.{lowered_op, lower_device_op, lower_vendor_name}

struct transformer_device_config {
    int layers
    int hidden
    int intermediate
    int query_heads
    int kv_heads
    int head_dim
    int vocabulary
    string dtype
    string rms_epsilon
    string rope_theta
    bool attention_bias
}

struct transformer_schedule {
    string backend
    []lowered_op operations
    string[] vendor_operations
    int layer_operations
    bool valid
    string error_message
}

func transformer_schedule_build(string backend, bool available, transformer_device_config config, bool prefill) transformer_schedule {
    if !available { return transformer_schedule {backend: backend, operations: [], vendor_operations: [], layer_operations: 0, valid: false, error_message: "backend_unavailable"} }
    if config.layers <= 0 || config.hidden <= 0 || config.intermediate <= 0 || config.query_heads <= 0 || config.kv_heads <= 0 || config.head_dim <= 0 {
        return transformer_schedule {backend: backend, operations: [], vendor_operations: [], layer_operations: 0, valid: false, error_message: "invalid_transformer_config"}
    }
    []lowered_op operations = make([]lowered_op, config.layers * 14 + 3)
    string[] vendor_operations = make([]string, config.layers * 14 + 3)
    int operation_index = 0
    operations[operation_index] = lower_device_op(backend, available, op_embedding(config.dtype, config.hidden)); operation_index = operation_index + 1
    int layer = 0
    for layer < config.layers {
        operations[operation_index] = lower_device_op(backend, available, op_rms_norm(config.dtype, config.hidden, config.rms_epsilon)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.hidden, config.query_heads * config.head_dim, config.attention_bias)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.hidden, config.kv_heads * config.head_dim, config.attention_bias)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.hidden, config.kv_heads * config.head_dim, config.attention_bias)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_rope(config.dtype, config.query_heads, config.head_dim, config.rope_theta)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_paged_attention(config.dtype, config.query_heads, config.kv_heads, config.head_dim)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.query_heads * config.head_dim, config.hidden, false)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_residual_add(config.dtype, config.hidden)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_rms_norm(config.dtype, config.hidden, config.rms_epsilon)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.hidden, config.intermediate, false)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.hidden, config.intermediate, false)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_swiglu(config.dtype, config.intermediate)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.intermediate, config.hidden, false)); operation_index = operation_index + 1
        operations[operation_index] = lower_device_op(backend, available, op_residual_add(config.dtype, config.hidden)); operation_index = operation_index + 1
        layer = layer + 1
    }
    operations[operation_index] = lower_device_op(backend, available, op_rms_norm(config.dtype, config.hidden, config.rms_epsilon)); operation_index = operation_index + 1
    operations[operation_index] = lower_device_op(backend, available, op_linear(config.dtype, config.hidden, config.vocabulary, false)); operation_index = operation_index + 1
    vendor_operations[0] = lower_vendor_name(backend, "embedding")
    int vendor_layer = 0
    for vendor_layer < config.layers {
        int base = 1 + vendor_layer * 14
        vendor_operations[base] = lower_vendor_name(backend, "rms_norm")
        vendor_operations[base + 1] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 2] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 3] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 4] = lower_vendor_name(backend, "rope")
        vendor_operations[base + 5] = lower_vendor_name(backend, "paged_attention")
        vendor_operations[base + 6] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 7] = lower_vendor_name(backend, "residual_add")
        vendor_operations[base + 8] = lower_vendor_name(backend, "rms_norm")
        vendor_operations[base + 9] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 10] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 11] = lower_vendor_name(backend, "swiglu")
        vendor_operations[base + 12] = lower_vendor_name(backend, "linear")
        vendor_operations[base + 13] = lower_vendor_name(backend, "residual_add")
        vendor_layer = vendor_layer + 1
    }
    vendor_operations[1 + config.layers * 14] = lower_vendor_name(backend, "rms_norm")
    vendor_operations[2 + config.layers * 14] = lower_vendor_name(backend, "linear")
    transformer_schedule {backend: backend, operations: operations, vendor_operations: vendor_operations, layer_operations: 14, valid: true, error_message: ""}
}

func transformer_prefill_schedule(string backend, bool available, transformer_device_config config) transformer_schedule {
    transformer_schedule_build(backend, available, config, true)
}

func transformer_decode_schedule(string backend, bool available, transformer_device_config config) transformer_schedule {
    transformer_schedule_build(backend, available, config, false)
}

func transformer_vendor_at(transformer_schedule schedule, int index) string {
    if index < 0 || index >= len(schedule.vendor_operations) { return "" }
    schedule.vendor_operations[index]
}
