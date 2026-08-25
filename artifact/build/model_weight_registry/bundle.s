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
    while i < len(shape) {
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
    while i >= 0 {
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

struct model_weight_registry {
    int context
    string backend
    string dtype
    []string name
    []int buffer
    []int element
    int count
    int capacity
    bool sealed
    bool valid
    string error_message
}

struct model_weight_lookup {
    int buffer
    int element
    bool found
}

func new_model_weight_registry(int context, string backend, string dtype, int capacity) model_weight_registry {
    if context <= 0 || capacity <= 0 || len(backend) == 0 || len(dtype) == 0 {
        return model_weight_registry {context: context, backend: backend, dtype: dtype, name: [], buffer: [], element: [], count: 0, capacity: capacity, sealed: false, valid: false, error_message: "invalid_weight_registry"}
    }
    model_weight_registry {context: context, backend: backend, dtype: dtype, name: []string{cap: capacity}, buffer: []int{cap: capacity}, element: []int{cap: capacity}, count: 0, capacity: capacity, sealed: false, valid: true, error_message: ""}
}

func model_weight_find(model_weight_registry registry, string name) int {
    int index = 0
    while index < registry.count {
        if registry.name[index] == name { return index }
        index = index + 1
    }
    -1
}

func model_weight_register(model_weight_registry registry, string name, device_tensor tensor) model_weight_registry {
    if !registry.valid || registry.sealed || len(name) == 0 || registry.count >= registry.capacity || model_weight_find(registry, name) >= 0 {
        registry.valid = false
        registry.error_message = "weight_registration_rejected"
        return registry
    }
    if !tensor.valid || tensor.context != registry.context || tensor.backend != registry.backend || tensor.dtype != registry.dtype {
        registry.valid = false
        registry.error_message = "weight_tensor_mismatch"
        return registry
    }
    registry.name[registry.count] = name
    registry.buffer[registry.count] = tensor.buffer
    registry.element[registry.count] = tensor.storage_bytes
    registry.count = registry.count + 1
    registry
}

func model_weight_seal(model_weight_registry registry, int required_count) model_weight_registry {
    if !registry.valid || required_count <= 0 || registry.count != required_count {
        registry.valid = false
        registry.error_message = "incomplete_weight_registry"
        return registry
    }
    registry.sealed = true
    registry
}

func model_weight_get(model_weight_registry registry, string name) model_weight_lookup {
    int index = model_weight_find(registry, name)
    if !registry.valid || !registry.sealed || index < 0 { return model_weight_lookup {buffer: 0, element: 0, found: false} }
    model_weight_lookup {buffer: registry.buffer[index], element: registry.element[index], found: true}
}

func main() {
    device_tensor tensor = device_tensor {buffer: 17, context: 3, device_id: 0, backend: "cuda", dtype: "bf16", shape: [8, 8], strides: [8, 1], offset_bytes: 0, storage_bytes: 128, owns_storage: false, valid: true, error_message: ""}
    model_weight_registry registry = new_model_weight_registry(3, "cuda", "bf16", 2)
    registry = model_weight_register(registry, "model.embed_tokens.weight", tensor)
    tensor.buffer = 18
    registry = model_weight_register(registry, "lm_head.weight", tensor)
    registry = model_weight_seal(registry, 2)
    model_weight_lookup embedding = model_weight_get(registry, "model.embed_tokens.weight")
    model_weight_lookup head = model_weight_get(registry, "lm_head.weight")
    if registry.valid && registry.sealed && embedding.found && embedding.buffer == 17 && head.found && head.buffer == 18 { print("PASS: S model weight Device ABI registry\n") }
    else { print("FAIL: S model weight Device ABI registry\n") }
}
