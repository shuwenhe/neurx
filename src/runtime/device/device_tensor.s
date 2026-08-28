package neurx.runtime.device.device_tensor
use neurx.runtime.device.device_abi.{device_context, device_buffer_alloc, device_buffer_free}
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
func tensor_contiguous_strides(int[] shape) int[] {
    int[] strides = int[]{cap: len(shape)}
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
