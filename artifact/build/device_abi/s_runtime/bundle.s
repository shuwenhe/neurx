package main
extern "libc:neurx_device_probe" func neurx_device_probe(string backend) int
extern "libc:neurx_device_create" func neurx_device_create(string backend, int device_id, string options) int
extern "libc:neurx_device_destroy" func neurx_device_destroy(int context) int
extern "libc:neurx_device_alloc" func neurx_device_alloc(int context, int bytes, string memory_kind) int
extern "libc:neurx_device_free" func neurx_device_free(int context, int buffer) int
extern "libc:neurx_device_copy" func neurx_device_copy(int context, int destination, int source, int bytes, int direction) int
extern "libc:neurx_device_stream_create" func neurx_device_stream_create(int context, int priority) int
extern "libc:neurx_device_stream_destroy" func neurx_device_stream_destroy(int context, int stream) int
extern "libc:neurx_device_op_create" func neurx_device_op_create(int context, string op_descriptor) int
extern "libc:neurx_device_op_destroy" func neurx_device_op_destroy(int context, int operation) int
extern "libc:neurx_device_op_launch" func neurx_device_op_launch(int context, int operation, int stream, string bindings) int
extern "libc:neurx_device_synchronize" func neurx_device_synchronize(int context, int stream) int
extern "libc:neurx_device_last_error" func neurx_device_last_error(int context) string
func device_backend_cuda() string { "cuda" }

func device_backend_cann() string { "cann" }

func device_backend_cpu() string { "cpu" }

func device_buffer_alloc(int context, int bytes, string memory_kind) int {

    neurx_device_alloc(context, bytes, memory_kind)
}

func device_buffer_free(int context, int buffer) int {

    neurx_device_free(context, buffer)
}

func device_operation_launch(int context, int operation, int stream, string bindings) int {

    neurx_device_op_launch(context, operation, stream, bindings)
}

func device_stream_synchronize(int context, int stream) int {

    neurx_device_synchronize(context, stream)
}

func device_context_error(int context) string {

    neurx_device_last_error(context)
}

func device_stream_open_handle(int context, int priority) int {

    neurx_device_stream_create(context, priority)
}

func device_stream_close_handle(int context, int stream) int {

    neurx_device_stream_destroy(context, stream)
}

func device_operation_open_handle(int context, string descriptor) int {

    neurx_device_op_create(context, descriptor)
}

func device_operation_close_handle(int context, int operation) int {

    neurx_device_op_destroy(context, operation)
}

func device_copy_host_to_device() int { 1 }

func device_copy_device_to_host() int { 2 }

func device_copy_device_to_device() int { 3 }

struct device_backend_capability {

    string backend
    bool available
    int feature_flags
    string collective_backend
}

func device_feature_fp16() int { 1 }

func device_feature_bf16() int { 2 }

func device_feature_int8() int { 4 }

func device_feature_graph() int { 8 }

func device_feature_paged_attention() int { 16 }

func device_feature_collectives() int { 32 }

func device_feature_enabled(device_backend_capability capability, int feature) bool {

    int quotient = capability.feature_flags / feature
    quotient - (quotient / 2) * 2 == 1
}

struct device_context {

    int handle
    int device_id
    string backend
    device_backend_capability capability
    bool valid
    string error_message
}

struct device_stream {

    int handle
    int context_handle
    bool valid
}

func device_capability_for(string backend, bool available) device_backend_capability {

    if backend == device_backend_cuda() {
        return device_backend_capability {backend: backend, available: available, feature_flags: 63, collective_backend: "nccl"}
    }
    if backend == device_backend_cann() || backend == "ascend" {
        return device_backend_capability {backend: device_backend_cann(), available: available, feature_flags: 63, collective_backend: "hccl"}
    }
    device_backend_capability {backend: device_backend_cpu(), available: available, feature_flags: 36, collective_backend: "gloo"}
}

func device_probe(string backend) device_backend_capability {

    device_capability_for(backend, neurx_device_probe(backend) > 0)
}

func device_open(string backend, int device_id, string options) device_context {

    device_backend_capability capability = device_probe(backend)
    if !capability.available {
        return device_context {handle: 0, device_id: device_id, backend: backend, capability: capability, valid: false, error_message: "backend_unavailable"}
    }
    int handle = neurx_device_create(backend, device_id, options)
    if handle <= 0 {
        return device_context {handle: 0, device_id: device_id, backend: backend, capability: capability, valid: false, error_message: neurx_device_last_error(0)}
    }
    device_context {handle: handle, device_id: device_id, backend: backend, capability: capability, valid: true, error_message: ""}
}

func device_close(device_context context) int {

    if !context.valid { return 0 }
    neurx_device_destroy(context.handle)
}

func device_new_stream(device_context context, int priority) device_stream {

    if !context.valid { return device_stream {handle: 0, context_handle: 0, valid: false} }
    int handle = neurx_device_stream_create(context.handle, priority)
    device_stream {handle: handle, context_handle: context.handle, valid: handle > 0}
}

func device_release_stream(device_stream stream) int {

    if !stream.valid { return 0 }
    neurx_device_stream_destroy(stream.context_handle, stream.handle)
}

struct device_operation {

    int handle
    int context_handle
    string descriptor
    bool valid
}

func device_new_operation(device_context context, string descriptor) device_operation {

    if !context.valid || len(descriptor) == 0 {
        return device_operation {handle: 0, context_handle: 0, descriptor: descriptor, valid: false}
    }
    int handle = neurx_device_op_create(context.handle, descriptor)
    device_operation {handle: handle, context_handle: context.handle, descriptor: descriptor, valid: handle > 0}
}

func device_release_operation(device_operation operation) int {
    if !operation.valid { return 0 }
    neurx_device_op_destroy(operation.context_handle, operation.handle)
}

struct device_tensor {
    int buffer
    int context
    int device_id
    string backend
    string dtype
    int[] shape
    int[] strides
    int offset_bytes
    int storage_bytes
    bool owns_storage
    bool valid
    string error_message
}

func tensor_dtype_bytes(string dtype) int {
    if dtype == "fp32" || dtype == "int32" { return 4 }
    if dtype == "fp16" || dtype == "bf16" { return 2 }
    if dtype == "int8" || dtype == "uint8" { return 1 }
    0
}

func tensor_numel(int[] shape) int {
    if len(shape) == 0 { return 0 }
    int elements = 1
    int i = 0
    for i < len(shape) {
        if shape[i] <= 0 { return 0 }
        elements = elements * shape[i]
        i = i + 1
    }
    elements
}

func tensor_contiguous_strides(int[] shape) []int {
    int[] strides = make([]int, len(shape))
    int stride = 1
    int i = len(shape) - 1
    for i >= 0 {
        strides[i] = stride
        stride = stride * shape[i]
        i = i - 1
    }
    strides
}

func tensor_invalid(string backend, string dtype, string error_message) device_tensor {
    device_tensor {buffer: 0, context: 0, device_id: 0, backend: backend, dtype: dtype, shape: [], strides: [], offset_bytes: 0, storage_bytes: 0, owns_storage: false, valid: false, error_message: error_message}
}

func tensor_empty(device_context context, int[] shape, string dtype) device_tensor {
    if !context.valid { return tensor_invalid(context.backend, dtype, "invalid_context") }
    int element_bytes = tensor_dtype_bytes(dtype)
    int elements = tensor_numel(shape)
    if element_bytes <= 0 || elements <= 0 { return tensor_invalid(context.backend, dtype, "invalid_tensor_layout") }
    int bytes = elements * element_bytes
    int buffer = device_buffer_alloc(context.handle, bytes, "device")
    if buffer <= 0 { return tensor_invalid(context.backend, dtype, "device_allocation_failed") }
    device_tensor {buffer: buffer, context: context.handle, device_id: context.device_id, backend: context.backend, dtype: dtype, shape: shape, strides: tensor_contiguous_strides(shape), offset_bytes: 0, storage_bytes: bytes, owns_storage: true, valid: true, error_message: ""}
}

func tensor_view(device_tensor source, int[] shape, int offset_elements) device_tensor {
    int bytes = tensor_dtype_bytes(source.dtype)
    int view_bytes = tensor_numel(shape) * bytes
    int offset = source.offset_bytes + offset_elements * bytes
    if !source.valid || offset < 0 || offset + view_bytes > source.storage_bytes {
        return tensor_invalid(source.backend, source.dtype, "view_out_of_bounds")
    }
    device_tensor {buffer: source.buffer, context: source.context, device_id: source.device_id, backend: source.backend, dtype: source.dtype, shape: shape, strides: tensor_contiguous_strides(shape), offset_bytes: offset, storage_bytes: source.storage_bytes, owns_storage: false, valid: true, error_message: ""}
}

func tensor_release(device_tensor tensor) int {
    if !tensor.valid || !tensor.owns_storage { return 0 }
    device_buffer_free(tensor.context, tensor.buffer)
}

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

func binding_buffer(string name, int handle) string {

    "buffer." + name + "=" + op_int_string(handle)
}

func binding_int(string name, int value) string {

    name + "=" + op_int_string(value)
}

func binding_join(string left, string right) string {

    if len(left) == 0 { return right }
    if len(right) == 0 { return left }
    left + ";" + right
}

func embedding_binding(int ids, int weight, int output, int tokens) string {

    binding_buffer("ids", ids) + ";" + binding_buffer("weight", weight) + ";" +
        binding_buffer("output", output) + ";" + binding_int("tokens", tokens)
}

func rms_norm_binding(int input, int weight, int output, int rows) string {

    binding_buffer("input", input) + ";" + binding_buffer("weight", weight) + ";" +
        binding_buffer("output", output) + ";" + binding_int("rows", rows)
}

func linear_binding(int input, int weight, int bias, int output, int rows) string {

    binding_buffer("input", input) + ";" + binding_buffer("weight", weight) + ";" +
        binding_buffer("bias", bias) + ";" + binding_buffer("output", output) + ";" +
        binding_int("rows", rows)
}

func rope_binding(int input, int tokens, int position) string {

    binding_buffer("input", input) + ";" + binding_int("tokens", tokens) + ";" +
        binding_int("position", position)
}

func swiglu_binding(int gate, int up, int output, int elements) string {

    binding_buffer("gate", gate) + ";" + binding_buffer("up", up) + ";" +
        binding_buffer("output", output) + ";" + binding_int("elements", elements)
}

func residual_add_binding(int left, int right, int output, int elements) string {

    binding_buffer("left", left) + ";" + binding_buffer("right", right) + ";" +
        binding_buffer("output", output) + ";" + binding_int("elements", elements)
}

func paged_attention_binding(int query, int key_cache, int value_cache, int block_table,
                             int workspace, int output, int position, int max_sequence,
                             int block_size) string {
    binding_buffer("query", query) + ";" + binding_buffer("key_cache", key_cache) + ";" +
        binding_buffer("value_cache", value_cache) + ";" + binding_buffer("block_table", block_table) + ";" +
        binding_buffer("workspace", workspace) + ";" +
        binding_buffer("output", output) + ";" + binding_int("position", position) + ";" +
        binding_int("max_sequence", max_sequence) + ";" + binding_int("block_size", block_size)
}

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

struct transformer_execution_plan {
    int context_handle
    int stream_handle
    int[] operation_handle
    int operation_count
    string backend
    bool valid
    string error_message
}

struct transformer_execution_result {
    bool success
    int completed_operations
    int failed_operation
    string error_message
}

func transformer_plan_invalid(string backend, string message) transformer_execution_plan {
    transformer_execution_plan {context_handle: 0, stream_handle: 0, operation_handle: [], operation_count: 0, backend: backend, valid: false, error_message: message}
}

func transformer_descriptor_plan_compile(device_context context, string backend, string[] descriptor, int stream_priority) transformer_execution_plan {
    if !context.valid { return transformer_plan_invalid(backend, "invalid_device_context") }
    if len(descriptor) <= 0 { return transformer_plan_invalid(backend, "empty_descriptor_plan") }
    if context.backend != backend && !(context.backend == "cann" && backend == "ascend") {
        return transformer_plan_invalid(backend, "backend_mismatch")
    }
    int stream_handle = device_stream_open_handle(context.handle, stream_priority)
    if stream_handle <= 0 { return transformer_plan_invalid(backend, "stream_create_failed") }
    int count = len(descriptor)
    int[] compiled = make([]int, count)
    int index = 0
    for index < count {
        if len(descriptor[index]) == 0 {
            int release_index = 0
            for release_index < index { device_operation_close_handle(context.handle, compiled[release_index]); release_index = release_index + 1 }
            device_stream_close_handle(context.handle, stream_handle)
            return transformer_plan_invalid(backend, "empty_descriptor")
        }
        int operation_handle = device_operation_open_handle(context.handle, descriptor[index])
        if operation_handle <= 0 {
            int release_index = 0
            for release_index < index { device_operation_close_handle(context.handle, compiled[release_index]); release_index = release_index + 1 }
            device_stream_close_handle(context.handle, stream_handle)
            return transformer_plan_invalid(backend, "operation_compile_failed_at_" + string(index))
        }
        compiled[index] = operation_handle
        index = index + 1
    }
    transformer_execution_plan {context_handle: context.handle, stream_handle: stream_handle, operation_handle: compiled, operation_count: count, backend: backend, valid: true, error_message: ""}
}

func transformer_plan_binding_valid(transformer_execution_plan plan, string[] binding) bool {
    plan.valid && plan.operation_count > 0 && len(binding) == plan.operation_count
}

func transformer_plan_execute(transformer_execution_plan plan, string[] binding, bool synchronize) transformer_execution_result {
    if !plan.valid { return transformer_execution_result {success: false, completed_operations: 0, failed_operation: -1, error_message: plan.error_message} }
    if len(binding) != plan.operation_count {
        return transformer_execution_result {success: false, completed_operations: 0, failed_operation: -1, error_message: "binding_count_mismatch"}
    }
    int index = 0
    for index < plan.operation_count {
        if len(binding[index]) == 0 {
            return transformer_execution_result {success: false, completed_operations: index, failed_operation: index, error_message: "empty_binding"}
        }
        int status = device_operation_launch(plan.context_handle, plan.operation_handle[index], plan.stream_handle, binding[index])
        if status != 0 {
            return transformer_execution_result {success: false, completed_operations: index, failed_operation: index, error_message: device_context_error(plan.context_handle)}
        }
        index = index + 1
    }
    if synchronize {
        int status = device_stream_synchronize(plan.context_handle, plan.stream_handle)
        if status != 0 {
            return transformer_execution_result {success: false, completed_operations: index, failed_operation: -1, error_message: device_context_error(plan.context_handle)}
        }
    }
    transformer_execution_result {success: true, completed_operations: index, failed_operation: -1, error_message: ""}
}

func transformer_plan_synchronize(transformer_execution_plan plan) int {
    if !plan.valid { return -1 }
    device_stream_synchronize(plan.context_handle, plan.stream_handle)
}

func transformer_plan_release(transformer_execution_plan plan) int {
    if !plan.valid { return 0 }
    int status = 0
    int index = plan.operation_count - 1
    for index >= 0 {
        if device_operation_close_handle(plan.context_handle, plan.operation_handle[index]) != 0 { status = -1 }
        index = index - 1
    }
    if device_stream_close_handle(plan.context_handle, plan.stream_handle) != 0 { status = -1 }
    status
}

func main() {
    device_context context = device_open("cuda", 0, "{}")
    if !context.valid { print("FAIL: CUDA context: " + context.error_message + "\n"); return }
    device_tensor left = tensor_empty(context, [1024], "bf16")
    device_tensor right = tensor_empty(context, [1024], "bf16")
    device_tensor output = tensor_empty(context, [1024], "bf16")
    if !left.valid || !right.valid || !output.valid {
        print("FAIL: CUDA tensor allocation\n")
        tensor_release(output); tensor_release(right); tensor_release(left); device_close(context); return
    }
    lowered_op lowered = lower_device_op("cuda", true, op_residual_add("bf16", 1024))
    string[] descriptor = make([]string, 1)
    descriptor[0] = lowered.descriptor
    transformer_execution_plan plan = transformer_descriptor_plan_compile(context, "cuda", descriptor, 0)
    string[] binding = make([]string, 1)
    binding[0] = residual_add_binding(left.buffer, right.buffer, output.buffer, 1024)
    transformer_execution_result result = transformer_plan_execute(plan, binding, true)
    if result.success { print("PASS: S Transformer Executor launched CUDA BF16 Kernel\n") }
    else { print("FAIL: S Transformer Executor: " + result.error_message + "\n") }
    transformer_plan_release(plan)
    tensor_release(output); tensor_release(right); tensor_release(left); device_close(context)
}
