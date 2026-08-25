package main
extern "libc:neurx_device_probe" func neurx_device_probe(string backend) int
extern "libc:neurx_device_create" func neurx_device_create(string backend, int device_id, string options) int
extern "libc:neurx_device_destroy" func neurx_device_destroy(int context) int
extern "libc:neurx_device_alloc" func neurx_device_alloc(int context, int bytes, string memory_kind) int
extern "libc:neurx_device_free" func neurx_device_free(int context, int buffer) int
extern "libc:neurx_device_copy" func neurx_device_copy(int context, int destination, int source, int bytes, int direction) int
extern "libc:neurx_device_write_i32" func neurx_device_write_i32(int context, int buffer, int element, int value) int
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
    []int shape
    []int strides
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

func tensor_numel([]int shape) int {
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

func tensor_contiguous_strides([]int shape) []int {
    []int strides = []int{cap: len(shape)}
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

func tensor_empty(device_context context, []int shape, string dtype) device_tensor {
    if !context.valid { return tensor_invalid(context.backend, dtype, "invalid_context") }
    int element_bytes = tensor_dtype_bytes(dtype)
    int elements = tensor_numel(shape)
    if element_bytes <= 0 || elements <= 0 { return tensor_invalid(context.backend, dtype, "invalid_tensor_layout") }
    int bytes = elements * element_bytes
    int buffer = device_buffer_alloc(context.handle, bytes, "device")
    if buffer <= 0 { return tensor_invalid(context.backend, dtype, "device_allocation_failed") }
    device_tensor {buffer: buffer, context: context.handle, device_id: context.device_id, backend: context.backend, dtype: dtype, shape: shape, strides: tensor_contiguous_strides(shape), offset_bytes: 0, storage_bytes: bytes, owns_storage: true, valid: true, error_message: ""}
}

func tensor_view(device_tensor source, []int shape, int offset_elements) device_tensor {
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

struct transformer_execution_plan {
    int context_handle
    int stream_handle
    []int operation_handle
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

func transformer_descriptor_plan_compile(device_context context, string backend, []string descriptor, int stream_priority) transformer_execution_plan {
    if !context.valid { return transformer_plan_invalid(backend, "invalid_device_context") }
    if len(descriptor) <= 0 { return transformer_plan_invalid(backend, "empty_descriptor_plan") }
    if context.backend != backend && !(context.backend == "cann" && backend == "ascend") {
        return transformer_plan_invalid(backend, "backend_mismatch")
    }
    int stream_handle = device_stream_open_handle(context.handle, stream_priority)
    if stream_handle <= 0 { return transformer_plan_invalid(backend, "stream_create_failed") }
    int count = len(descriptor)
    []int compiled = []int{cap: count}
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

func transformer_plan_binding_valid(transformer_execution_plan plan, []string binding) bool {
    plan.valid && plan.operation_count > 0 && len(binding) == plan.operation_count
}

func transformer_plan_execute(transformer_execution_plan plan, []string binding, bool synchronize) transformer_execution_result {
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

func production_request_free() int { 0 }

func production_request_waiting() int { 1 }

func production_request_prefill() int { 2 }

func production_request_decode() int { 3 }

func production_request_finished() int { 4 }

func production_request_cancelled() int { 5 }

struct production_batch_config {
    int request_capacity
    int page_capacity
    int page_size
    int maximum_pages_per_request
    int maximum_batch_sequences
    int maximum_batch_tokens
}

struct production_batch_runtime {
    production_batch_config config
    []int session_id
    []int request_id
    []int status
    []int prompt_tokens
    []int maximum_new_tokens
    []int generated_tokens
    []int page_count
    []int page_id
    []int page_owner
    int active_requests
    int queued_requests
    int allocated_pages
    int scheduling_round
    int completed_requests
    int rejected_requests
}

struct production_batch_selection {
    production_batch_runtime runtime
    []int prefill_slot
    []int decode_slot
    int prefill_count
    int decode_count
    int prefill_tokens
    int decode_tokens
    bool selected
}

struct production_admission_result {
    production_batch_runtime runtime
    int slot
    bool accepted
    string error_message
}

func production_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int index = 0
    for index < capacity { values[index] = 0; index = index + 1 }
    values
}

func new_production_batch_runtime(production_batch_config config) production_batch_runtime {
    if config.request_capacity <= 0 { config.request_capacity = 1 }
    if config.page_capacity <= 0 { config.page_capacity = 1 }
    if config.page_size <= 0 { config.page_size = 16 }
    if config.maximum_pages_per_request <= 0 { config.maximum_pages_per_request = 1 }
    if config.maximum_batch_sequences <= 0 { config.maximum_batch_sequences = 1 }
    if config.maximum_batch_tokens <= 0 { config.maximum_batch_tokens = 1 }
    production_batch_runtime {config: config, session_id: production_int_array(config.request_capacity), request_id: production_int_array(config.request_capacity), status: production_int_array(config.request_capacity), prompt_tokens: production_int_array(config.request_capacity), maximum_new_tokens: production_int_array(config.request_capacity), generated_tokens: production_int_array(config.request_capacity), page_count: production_int_array(config.request_capacity), page_id: production_int_array(config.request_capacity * config.maximum_pages_per_request), page_owner: production_int_array(config.page_capacity), active_requests: 0, queued_requests: 0, allocated_pages: 0, scheduling_round: 0, completed_requests: 0, rejected_requests: 0}
}

func production_page_offset(production_batch_runtime runtime, int slot, int page_index) int {
    slot * runtime.config.maximum_pages_per_request + page_index
}

func production_find_free_slot(production_batch_runtime runtime) int {
    int slot = 0
    for slot < runtime.config.request_capacity {
        if runtime.status[slot] == production_request_free() || runtime.status[slot] == production_request_finished() || runtime.status[slot] == production_request_cancelled() { return slot }
        slot = slot + 1
    }
    -1
}

func production_free_page_count(production_batch_runtime runtime) int {
    runtime.config.page_capacity - runtime.allocated_pages
}

func production_release_slot_pages(production_batch_runtime runtime, int slot) production_batch_runtime {
    int page_index = 0
    for page_index < runtime.page_count[slot] {
        int offset = production_page_offset(runtime, slot, page_index)
        int page = runtime.page_id[offset]
        if page >= 0 && page < runtime.config.page_capacity && runtime.page_owner[page] == slot + 1 {
            runtime.page_owner[page] = 0
            runtime.allocated_pages = runtime.allocated_pages - 1
        }
        runtime.page_id[offset] = 0
        page_index = page_index + 1
    }
    runtime.page_count[slot] = 0
    runtime
}

func production_admit(production_batch_runtime runtime, int session_id, int request_id, int prompt_tokens, int maximum_new_tokens) production_admission_result {
    production_batch_runtime next = runtime
    if session_id <= 0 || request_id <= 0 || prompt_tokens <= 0 || maximum_new_tokens <= 0 {
        next.rejected_requests = next.rejected_requests + 1
        return production_admission_result {runtime: next, slot: -1, accepted: false, error_message: "invalid_request"}
    }
    int slot = production_find_free_slot(next)
    int required_pages = (prompt_tokens + maximum_new_tokens + next.config.page_size - 1) / next.config.page_size
    if slot < 0 || required_pages > next.config.maximum_pages_per_request || required_pages > production_free_page_count(next) {
        next.rejected_requests = next.rejected_requests + 1
        return production_admission_result {runtime: next, slot: -1, accepted: false, error_message: "kv_capacity_exhausted"}
    }
    next = production_release_slot_pages(next, slot)
    int allocated = 0
    int page = 0
    for page < next.config.page_capacity && allocated < required_pages {
        if next.page_owner[page] == 0 {
            next.page_owner[page] = slot + 1
            next.page_id[production_page_offset(next, slot, allocated)] = page
            next.allocated_pages = next.allocated_pages + 1
            allocated = allocated + 1
        }
        page = page + 1
    }
    next.session_id[slot] = session_id
    next.request_id[slot] = request_id
    next.status[slot] = production_request_waiting()
    next.prompt_tokens[slot] = prompt_tokens
    next.maximum_new_tokens[slot] = maximum_new_tokens
    next.generated_tokens[slot] = 0
    next.page_count[slot] = allocated
    next.queued_requests = next.queued_requests + 1
    production_admission_result {runtime: next, slot: slot, accepted: true, error_message: ""}
}

func production_schedule(production_batch_runtime runtime) production_batch_selection {
    []int prefill = production_int_array(runtime.config.maximum_batch_sequences)
    []int decode = production_int_array(runtime.config.maximum_batch_sequences)
    int prefill_count = 0
    int decode_count = 0
    int token_budget = runtime.config.maximum_batch_tokens
    int slot = 0
    for slot < runtime.config.request_capacity && prefill_count < runtime.config.maximum_batch_sequences {
        if runtime.status[slot] == production_request_waiting() && runtime.prompt_tokens[slot] <= token_budget {
            prefill[prefill_count] = slot
            prefill_count = prefill_count + 1
            token_budget = token_budget - runtime.prompt_tokens[slot]
            runtime.status[slot] = production_request_prefill()
            runtime.queued_requests = runtime.queued_requests - 1
            runtime.active_requests = runtime.active_requests + 1
        }
        slot = slot + 1
    }
    slot = 0
    for slot < runtime.config.request_capacity && decode_count + prefill_count < runtime.config.maximum_batch_sequences && token_budget > 0 {
        if runtime.status[slot] == production_request_decode() {
            decode[decode_count] = slot
            decode_count = decode_count + 1
            token_budget = token_budget - 1
        }
        slot = slot + 1
    }
    int prefill_token_count = 0
    int index = 0
    for index < prefill_count { prefill_token_count = prefill_token_count + runtime.prompt_tokens[prefill[index]]; index = index + 1 }
    runtime.scheduling_round = runtime.scheduling_round + 1
    production_batch_selection {runtime: runtime, prefill_slot: prefill, decode_slot: decode, prefill_count: prefill_count, decode_count: decode_count, prefill_tokens: prefill_token_count, decode_tokens: decode_count, selected: prefill_count + decode_count > 0}
}

func production_mark_prefill_complete(production_batch_runtime runtime, []int slots, int count) production_batch_runtime {
    int index = 0
    for index < count {
        int slot = slots[index]
        if slot >= 0 && slot < runtime.config.request_capacity && runtime.status[slot] == production_request_prefill() { runtime.status[slot] = production_request_decode() }
        index = index + 1
    }
    runtime
}

func production_record_decode(production_batch_runtime runtime, int slot, int token_count, bool stopped) production_batch_runtime {
    production_batch_runtime next = runtime
    if slot < 0 || slot >= next.config.request_capacity || next.status[slot] != production_request_decode() { return next }
    if token_count > 0 { next.generated_tokens[slot] = next.generated_tokens[slot] + token_count }
    if stopped || next.generated_tokens[slot] >= next.maximum_new_tokens[slot] {
        next = production_release_slot_pages(next, slot)
        next.status[slot] = production_request_finished()
        next.active_requests = next.active_requests - 1
        next.completed_requests = next.completed_requests + 1
    }
    next
}

func production_cancel(production_batch_runtime runtime, int session_id) production_batch_runtime {
    production_batch_runtime next = runtime
    int slot = 0
    for slot < next.config.request_capacity {
        if next.session_id[slot] == session_id && next.status[slot] != production_request_free() && next.status[slot] != production_request_finished() {
            if next.status[slot] == production_request_waiting() { next.queued_requests = next.queued_requests - 1 }
            else { next.active_requests = next.active_requests - 1 }
            next = production_release_slot_pages(next, slot)
            next.status[slot] = production_request_cancelled()
            return next
        }
        slot = slot + 1
    }
    next
}

func production_execute_selected(transformer_execution_plan plan, production_batch_selection selected, []string binding, bool synchronize) transformer_execution_result {
    if !selected.selected { return transformer_execution_result {success: false, completed_operations: 0, failed_operation: -1, error_message: "empty_batch"} }
    transformer_plan_execute(plan, binding, synchronize)
}

struct physical_paged_kv {
    device_tensor key
    device_tensor value
    device_tensor block_table
    int page_capacity
    int page_size
    int layers
    int kv_heads
    int head_dim
    bool valid
    string error_message
}

struct packed_batch_tensor {
    device_tensor token
    device_tensor position
    device_tensor slot_mapping
    device_tensor block_table
    int token_host
    int position_host
    int slot_host
    int block_host
    int token_count
    int sequence_count
    int maximum_pages
    bool valid
    string error_message
}

func physical_paged_kv_create(device_context context, int layers, int page_capacity, int page_size, int kv_heads, int head_dim, string dtype) physical_paged_kv {
    if !context.valid || layers <= 0 || page_capacity <= 0 || page_size <= 0 || kv_heads <= 0 || head_dim <= 0 {
        return physical_paged_kv {key: tensor_invalid(context.backend, dtype, "invalid_physical_kv"), value: tensor_invalid(context.backend, dtype, "invalid_physical_kv"), block_table: tensor_invalid(context.backend, "int32", "invalid_physical_kv"), page_capacity: page_capacity, page_size: page_size, layers: layers, kv_heads: kv_heads, head_dim: head_dim, valid: false, error_message: "invalid_physical_kv"}
    }
    device_tensor key = tensor_empty(context, [layers, page_capacity, page_size, kv_heads, head_dim], dtype)
    device_tensor value = tensor_empty(context, [layers, page_capacity, page_size, kv_heads, head_dim], dtype)
    device_tensor table = tensor_empty(context, [page_capacity], "int32")
    bool valid = key.valid && value.valid && table.valid
    physical_paged_kv {key: key, value: value, block_table: table, page_capacity: page_capacity, page_size: page_size, layers: layers, kv_heads: kv_heads, head_dim: head_dim, valid: valid, error_message: if valid { "" } else { "physical_kv_allocation_failed" }}
}

func physical_paged_kv_release(physical_paged_kv cache) int {
    int status = tensor_release(cache.block_table)
    if tensor_release(cache.value) != 0 { status = -1 }
    if tensor_release(cache.key) != 0 { status = -1 }
    status
}

func batch_write_i32(int context, int host, []int values) int {
    int index = 0
    for index < len(values) {
        if neurx_device_write_i32(context, host, index, values[index]) != 0 { return -1 }
        index = index + 1
    }
    0
}

func batch_upload_i32(device_context context, []int values) device_tensor {
    if len(values) <= 0 { return tensor_invalid(context.backend, "int32", "empty_upload") }
    int bytes = len(values) * 4
    int host = device_buffer_alloc(context.handle, bytes, "host")
    if host <= 0 { return tensor_invalid(context.backend, "int32", "host_allocation_failed") }
    []int upload_shape = []int{cap: 1}
    upload_shape[0] = len(values)
    device_tensor output = tensor_empty(context, upload_shape, "int32")
    if !output.valid || batch_write_i32(context.handle, host, values) != 0 || neurx_device_copy(context.handle, output.buffer, host, bytes, device_copy_host_to_device()) != 0 {
        device_buffer_free(context.handle, host)
        if output.valid { tensor_release(output) }
        return tensor_invalid(context.backend, "int32", "upload_failed")
    }
    device_buffer_free(context.handle, host)
    output
}

func pack_batch_tensor(device_context context, production_batch_runtime runtime, []int selected_slot, int selected_count, []int token_id, []int token_start, []int token_count) packed_batch_tensor {
    if selected_count <= 0 || selected_count > len(selected_slot) || selected_count > len(token_start) || selected_count > len(token_count) {
        return packed_batch_tensor {token: tensor_invalid(context.backend, "int32", "invalid_batch"), position: tensor_invalid(context.backend, "int32", "invalid_batch"), slot_mapping: tensor_invalid(context.backend, "int32", "invalid_batch"), block_table: tensor_invalid(context.backend, "int32", "invalid_batch"), token_host: 0, position_host: 0, slot_host: 0, block_host: 0, token_count: 0, sequence_count: 0, maximum_pages: runtime.config.maximum_pages_per_request, valid: false, error_message: "invalid_batch"}
    }
    int total = 0
    int sequence = 0
    for sequence < selected_count { total = total + token_count[sequence]; sequence = sequence + 1 }
    []int tokens = []int{cap: total}
    []int positions = []int{cap: total}
    []int slots = []int{cap: total}
    []int table = []int{cap: selected_count * runtime.config.maximum_pages_per_request}
    int packed = 0
    sequence = 0
    for sequence < selected_count {
        int runtime_slot = selected_slot[sequence]
        int local = 0
        for local < token_count[sequence] {
            tokens[packed] = token_id[token_start[sequence] + local]
            positions[packed] = runtime.prompt_tokens[runtime_slot] + runtime.generated_tokens[runtime_slot] - token_count[sequence] + local
            if positions[packed] < 0 { positions[packed] = local }
            int logical = positions[packed] / runtime.config.page_size
            int page = runtime.page_id[production_page_offset(runtime, runtime_slot, logical)]
            slots[packed] = page * runtime.config.page_size + positions[packed] % runtime.config.page_size
            packed = packed + 1
            local = local + 1
        }
        int page_index = 0
        for page_index < runtime.config.maximum_pages_per_request {
            int page_value = -1
            if page_index < runtime.page_count[runtime_slot] { page_value = runtime.page_id[production_page_offset(runtime, runtime_slot, page_index)] }
            table[sequence * runtime.config.maximum_pages_per_request + page_index] = page_value
            page_index = page_index + 1
        }
        sequence = sequence + 1
    }
    device_tensor token = batch_upload_i32(context, tokens)
    device_tensor position = batch_upload_i32(context, positions)
    device_tensor slot_mapping = batch_upload_i32(context, slots)
    device_tensor block_table = batch_upload_i32(context, table)
    bool valid = token.valid && position.valid && slot_mapping.valid && block_table.valid
    packed_batch_tensor {token: token, position: position, slot_mapping: slot_mapping, block_table: block_table, token_host: 0, position_host: 0, slot_host: 0, block_host: 0, token_count: total, sequence_count: selected_count, maximum_pages: runtime.config.maximum_pages_per_request, valid: valid, error_message: if valid { "" } else { "batch_tensor_upload_failed" }}
}

func packed_batch_tensor_release(packed_batch_tensor batch) int {
    int status = tensor_release(batch.block_table)
    if tensor_release(batch.slot_mapping) != 0 { status = -1 }
    if tensor_release(batch.position) != 0 { status = -1 }
    if tensor_release(batch.token) != 0 { status = -1 }
    status
}

func main() {
    device_context context = device_open("cuda", 0, "{}")
    if !context.valid { print("FAIL: CUDA context\n"); return }
    production_batch_config config = production_batch_config {request_capacity: 4, page_capacity: 16, page_size: 4, maximum_pages_per_request: 8, maximum_batch_sequences: 4, maximum_batch_tokens: 32}
    production_batch_runtime runtime = new_production_batch_runtime(config)
    production_admission_result first = production_admit(runtime, 1, 1, 3, 2)
    runtime = first.runtime
    production_admission_result second = production_admit(runtime, 2, 2, 2, 2)
    runtime = second.runtime
    []int selected = []int{cap: 2}
    selected[0] = first.slot
    selected[1] = second.slot
    []int token = [11, 12, 13, 21, 22]
    []int start = [0, 3]
    []int count = [3, 2]
    physical_paged_kv cache = physical_paged_kv_create(context, 2, 16, 4, 2, 8, "bf16")
    packed_batch_tensor batch = pack_batch_tensor(context, runtime, selected, 2, token, start, count)
    if cache.valid && batch.valid && batch.token_count == 5 && batch.sequence_count == 2 {
        print("PASS: S physical Paged KV and CUDA batch tensor upload\n")
    } else { print("FAIL: S physical Paged KV or batch tensor upload\n") }
    packed_batch_tensor_release(batch)
    physical_paged_kv_release(cache)
    device_close(context)
}
