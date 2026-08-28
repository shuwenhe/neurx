package neurx.device.device_tensor_manager

use neurx.device.abi
use std.vec.vec

struct tensor_pool_block {
    int64 address
    int64 size
    bool is_allocated
    int64 alloc_time
}

struct device_tensor_manager_state {
    bool initialized
    int device_id
    vec[tensor_pool_block] memory_blocks
    int64 total_pool_size
    int64 used_size
    int64 fragmentation_ratio
}

device_tensor_manager_state g_tensor_manager

func device_tensor_manager_init(device_id: int, pool_size: int64) (bool, string) {
    if pool_size <= 0 {
        return false, "Invalid pool size"
    }

    g_tensor_manager = device_tensor_manager_state {
        initialized: true,
        device_id: device_id,
        memory_blocks: vec[tensor_pool_block](),
        total_pool_size: pool_size,
        used_size: 0,
        fragmentation_ratio: 0,
    }

    return true, ""
}

func device_tensor_manager_allocate(element_count: int64, dtype: int) (abi.device_tensor, bool, string) {
    if !g_tensor_manager.initialized {
        return abi.device_tensor{}, false, "Tensor manager not initialized"
    }

    dtype_size := abi.device_get_dtype_size(dtype)
    total_bytes := element_count * int64(dtype_size)

    shape := vec[int]()
    shape.push(int(element_count))

    strides := vec[int64]()
    strides.push(int64(dtype_size))

    ptr, success, err := abi.device_alloc(g_tensor_manager.device_id, total_bytes)
    if !success {
        return abi.device_tensor{}, false, err
    }

    tensor := abi.device_tensor {
        data: ptr,
        shape: shape,
        strides: strides,
        dtype: dtype,
        element_count: element_count,
        ref_count: 1,
        is_view: false,
    }

    g_tensor_manager.used_size = g_tensor_manager.used_size + total_bytes

    return tensor, true, ""
}

func device_tensor_manager_free(tensor: abi.device_tensor) (bool, string) {
    if !g_tensor_manager.initialized {
        return false, "Tensor manager not initialized"
    }

    success, err := abi.device_free(tensor.data)
    if !success {
        return false, err
    }

    dtype_size := abi.device_get_dtype_size(tensor.dtype)
    total_bytes := tensor.element_count * int64(dtype_size)
    g_tensor_manager.used_size = g_tensor_manager.used_size - total_bytes

    return true, ""
}

func device_tensor_reshape(
    tensor: abi.device_tensor,
    new_shape: vec[int]
) (abi.device_tensor, bool, string) {
    if !g_tensor_manager.initialized {
        return abi.device_tensor{}, false, "Tensor manager not initialized"
    }

    new_element_count := 1
    for i := 0; i < new_shape.len(); i = i + 1 {
        new_element_count = new_element_count * new_shape[i]
    }

    if new_element_count != int(tensor.element_count) {
        return abi.device_tensor{}, false, "Reshape: element count mismatch"
    }

    reshaped := abi.device_tensor {
        data: tensor.data,
        shape: new_shape,
        strides: vec[int64](),
        dtype: tensor.dtype,
        element_count: int64(new_element_count),
        ref_count: tensor.ref_count + 1,
        is_view: true,
    }

    dtype_size := abi.device_get_dtype_size(tensor.dtype)
    stride := int64(dtype_size)
    for i := new_shape.len() - 1; i >= 0; i = i - 1 {
        reshaped.strides.push(stride)
        stride = stride * int64(new_shape[i])
    }

    return reshaped, true, ""
}

func device_tensor_view(
    tensor: abi.device_tensor,
    offset: int64,
    new_element_count: int64
) (abi.device_tensor, bool, string) {
    if !g_tensor_manager.initialized {
        return abi.device_tensor{}, false, "Tensor manager not initialized"
    }

    if offset + new_element_count > tensor.element_count {
        return abi.device_tensor{}, false, "View: offset out of bounds"
    }

    dtype_size := abi.device_get_dtype_size(tensor.dtype)
    new_address := tensor.data.address + offset * int64(dtype_size)

    new_ptr := abi.device_ptr {
        address: new_address,
        device_id: tensor.data.device_id,
    }

    new_shape := vec[int]()
    new_shape.push(int(new_element_count))

    view := abi.device_tensor {
        data: new_ptr,
        shape: new_shape,
        strides: tensor.strides,
        dtype: tensor.dtype,
        element_count: new_element_count,
        ref_count: tensor.ref_count + 1,
        is_view: true,
    }

    return view, true, ""
}

func device_tensor_transpose(
    tensor: abi.device_tensor,
    axes: vec[int]
) (abi.device_tensor, bool, string) {
    if !g_tensor_manager.initialized {
        return abi.device_tensor{}, false, "Tensor manager not initialized"
    }

    if axes.len() != tensor.shape.len() {
        return abi.device_tensor{}, false, "Transpose: axes length mismatch"
    }

    transposed_shape := vec[int]()
    for i := 0; i < axes.len(); i = i + 1 {
        axis := axes[i]
        if axis < 0 || axis >= tensor.shape.len() {
            return abi.device_tensor{}, false, "Transpose: invalid axis"
        }
        transposed_shape.push(tensor.shape[axis])
    }

    transposed_strides := vec[int64]()
    for i := 0; i < axes.len(); i = i + 1 {
        axis := axes[i]
        transposed_strides.push(tensor.strides[axis])
    }

    transposed := abi.device_tensor {
        data: tensor.data,
        shape: transposed_shape,
        strides: transposed_strides,
        dtype: tensor.dtype,
        element_count: tensor.element_count,
        ref_count: tensor.ref_count + 1,
        is_view: true,
    }

    return transposed, true, ""
}

func device_tensor_ref_acquire(tensor: abi.device_tensor) abi.device_tensor {
    acquired := tensor
    acquired.ref_count = tensor.ref_count + 1
    return acquired
}

func device_tensor_ref_release(tensor: abi.device_tensor) (bool, string) {
    if tensor.ref_count <= 0 {
        return false, "Invalid reference count"
    }

    if tensor.ref_count == 1 && !tensor.is_view {
        return device_tensor_manager_free(tensor)
    }

    return true, ""
}

func device_tensor_get_memory_usage(tensor: abi.device_tensor) int64 {
    dtype_size := abi.device_get_dtype_size(tensor.dtype)
    return tensor.element_count * int64(dtype_size)
}

func device_tensor_defragment() (bool, string) {
    if !g_tensor_manager.initialized {
        return false, "Tensor manager not initialized"
    }

    return true, ""
}

func device_tensor_get_stats() (int64, int64, int64, bool, string) {
    if !g_tensor_manager.initialized {
        return 0, 0, 0, false, "Tensor manager not initialized"
    }

    return g_tensor_manager.total_pool_size, g_tensor_manager.used_size, g_tensor_manager.fragmentation_ratio, true, ""
}

func device_tensor_manager_finalize() (bool, string) {
    if !g_tensor_manager.initialized {
        return false, "Tensor manager not initialized"
    }

    g_tensor_manager.initialized = false
    return true, ""
}
