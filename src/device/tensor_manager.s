package neurx.device.tensor_manager

use neurx.device.abi
use std.vec.vec

struct tensor_allocation {
    device_ptr ptr
    int element_count
    int dtype
    int device_id
    int64 allocated_bytes
    int ref_count
}

struct device_tensor_manager {
    int device_id
    stream_handle default_stream
    int64 total_allocated_bytes
    int64 max_allocation_bytes
    
    tensor_allocation[] allocations
    int num_allocations
}

func create_device_tensor_manager(
    int device_id,
    int64 max_memory_bytes,
    stream_handle stream
) (device_tensor_manager, bool, string) {
    
    mgr := device_tensor_manager {
        device_id: device_id,
        default_stream: stream,
        total_allocated_bytes: 0,
        max_allocation_bytes: max_memory_bytes,
        
        allocations: make(tensor_allocation[], 1024),
        num_allocations: 0,
    }
    
    return mgr, true, ""
}

func (device_tensor_manager* mgr) allocate_tensor(
    int[] shape,
    int dtype
) (device_tensor, bool, string) {
    
    element_count := 1
    int i = 0
    for i < len(shape) {
        element_count = element_count * shape[i]
        i = i + 1
    }
    
    dtype_size := device_get_dtype_size(dtype)
    total_bytes := element_count * dtype_size
    
    if mgr.total_allocated_bytes + int64(total_bytes) > mgr.max_allocation_bytes {
        return device_tensor{}, false, "Out of device memory"
    }
    
    ptr, success, err := device_alloc(mgr.device_id, int64(total_bytes))
    if !success {
        return device_tensor{}, false, err
    }
    
    alloc := tensor_allocation {
        ptr: ptr,
        element_count: element_count,
        dtype: dtype,
        device_id: mgr.device_id,
        allocated_bytes: int64(total_bytes),
        ref_count: 1,
    }
    
    mgr.allocations[mgr.num_allocations] = alloc
    mgr.num_allocations = mgr.num_allocations + 1
    mgr.total_allocated_bytes = mgr.total_allocated_bytes + int64(total_bytes)
    
    strides := compute_strides(shape)
    tensor := device_tensor {
        data: ptr,
        shape: shape,
        stride: strides,
        dtype: dtype,
        device_id: mgr.device_id,
        element_count: element_count,
    }
    
    return tensor, true, ""
}

func (device_tensor_manager* mgr) free_tensor(device_tensor* tensor) (bool, string) {
    int idx = 0
    int found = -1
    
    for idx < mgr.num_allocations {
        if mgr.allocations[idx].ptr.address == tensor.data.address {
            found = idx
            break
        }
        idx = idx + 1
    }
    
    if found == -1 {
        return false, "Tensor not found in allocations"
    }
    
    alloc := mgr.allocations[found]
    alloc.ref_count = alloc.ref_count - 1
    
    if alloc.ref_count <= 0 {
        success, err := device_free(alloc.ptr)
        if !success {
            return false, err
        }
        
        mgr.total_allocated_bytes = mgr.total_allocated_bytes - alloc.allocated_bytes
        
        if found < mgr.num_allocations - 1 {
            mgr.allocations[found] = mgr.allocations[mgr.num_allocations - 1]
        }
        mgr.num_allocations = mgr.num_allocations - 1
    }
    
    return true, ""
}

func (device_tensor_manager* mgr) add_tensor_ref(device_tensor* tensor) (bool, string) {
    int idx = 0
    int found = -1
    
    for idx < mgr.num_allocations {
        if mgr.allocations[idx].ptr.address == tensor.data.address {
            found = idx
            break
        }
        idx = idx + 1
    }
    
    if found == -1 {
        return false, "Tensor not found in allocations"
    }
    
    mgr.allocations[found].ref_count = mgr.allocations[found].ref_count + 1
    return true, ""
}

func (device_tensor_manager* mgr) get_memory_usage() (int64, int64, float) {
    free_bytes := mgr.max_allocation_bytes - mgr.total_allocated_bytes
    usage_percent := float(mgr.total_allocated_bytes) / float(mgr.max_allocation_bytes)
    
    return mgr.total_allocated_bytes, free_bytes, usage_percent
}

func (device_tensor_manager* mgr) clear_all() (bool, string) {
    int idx = 0
    for idx < mgr.num_allocations {
        device_free(mgr.allocations[idx].ptr)
        idx = idx + 1
    }
    
    mgr.num_allocations = 0
    mgr.total_allocated_bytes = 0
    return true, ""
}

func (device_tensor_manager* mgr) copy_h2d(
    int64 host_ptr,
    device_tensor* device_t
) (bool, string) {
    total_bytes := device_t.element_count * device_get_dtype_size(device_t.dtype)
    return device_memcpy_h2d(device_t.data, host_ptr, int64(total_bytes), mgr.default_stream)
}

func (device_tensor_manager* mgr) copy_d2h(
    device_tensor device_t,
    int64 host_ptr
) (bool, string) {
    total_bytes := device_t.element_count * device_get_dtype_size(device_t.dtype)
    return device_memcpy_d2h(host_ptr, device_t.data, int64(total_bytes), mgr.default_stream)
}

func (device_tensor_manager* mgr) copy_d2d(
    device_tensor* dst,
    device_tensor src
) (bool, string) {
    if dst.element_count != src.element_count {
        return false, "Tensor size mismatch"
    }
    
    total_bytes := src.element_count * device_get_dtype_size(src.dtype)
    return device_memcpy_d2d(dst.data, src.data, int64(total_bytes), mgr.default_stream)
}

func (device_tensor_manager* mgr) zeros(device_tensor* tensor) (bool, string) {
    total_bytes := tensor.element_count * device_get_dtype_size(tensor.dtype)
    return device_memset(tensor.data, 0, int64(total_bytes), mgr.default_stream)
}

func (device_tensor_manager* mgr) ones(device_tensor* tensor) (bool, string) {
    return false, "ones not implemented"
}

func (device_tensor_manager* mgr) fill(device_tensor* tensor, float value) (bool, string) {
    return false, "fill not implemented"
}

func (device_tensor_manager* mgr) reshape(
    device_tensor* tensor,
    int[] new_shape
) (bool, string) {
    
    new_element_count := 1
    int i = 0
    for i < len(new_shape) {
        new_element_count = new_element_count * new_shape[i]
        i = i + 1
    }
    
    if new_element_count != tensor.element_count {
        return false, "Cannot reshape: element count mismatch"
    }
    
    tensor.shape = new_shape
    tensor.stride = compute_strides(new_shape)
    return true, ""
}

func (device_tensor_manager* mgr) view(
    device_tensor tensor,
    int[] view_shape
) (device_tensor, bool, string) {
    
    view_element_count := 1
    int i = 0
    for i < len(view_shape) {
        view_element_count = view_element_count * view_shape[i]
        i = i + 1
    }
    
    if view_element_count != tensor.element_count {
        return device_tensor{}, false, "View shape does not match tensor size"
    }
    
    view_tensor := device_tensor {
        data: tensor.data,
        shape: view_shape,
        stride: compute_strides(view_shape),
        dtype: tensor.dtype,
        device_id: tensor.device_id,
        element_count: tensor.element_count,
    }
    
    mgr.add_tensor_ref(&view_tensor)
    return view_tensor, true, ""
}

func (device_tensor_manager* mgr) get_stats() (int, int64, int64, float) {
    allocated, free, usage := mgr.get_memory_usage()
    return mgr.num_allocations, allocated, free, usage
}

func (device_tensor_manager* mgr) destroy() (bool, string) {
    return mgr.clear_all()
}
