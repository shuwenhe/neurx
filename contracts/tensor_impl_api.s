// TensorImpl API - Internal representation of Tensor data
// 
// Tensor is just a Handle (public API)
// TensorImpl is the actual implementation (internal)
//
// Tensor → TensorImpl → Storage → Allocator
//
// This design allows:
// - Zero-copy operations (view, reshape, transpose share Storage)
// - Gradient tracking (per TensorImpl)
// - Version counter (detect in-place modifications)
// - Autograd metadata (separate from Tensor)

import "storage_api"
import "dtype_api"
import "layout_api"
import "device_api"

struct VersionCounter {
    version: i64
}

struct AutogradMeta {
    requires_grad: bool
    is_leaf: bool
    grad_fn: func(grad_output: Tensor) -> []Tensor
    saved_tensors: []Tensor
}

struct TensorMetadata {
    shape: []i64
    stride: []i64
    offset: i64
    dtype: DType
    layout: Layout
    device: Device
    version_counter: VersionCounter
}

struct TensorImpl {
    // Identity
    id: i64
    
    // Core data
    storage: Storage
    metadata: TensorMetadata
    
    // Computation graph
    autograd_meta: AutogradMeta
    
    // Use counter (for memory management)
    ref_count: i64
}

interface ITensorImpl {
    // Metadata access
    shape() -> []i64
    stride() -> []i64
    dtype() -> DType
    layout() -> Layout
    device() -> Device
    offset() -> i64
    
    // Storage access
    storage() -> Storage
    data_ptr() -> i64  // Raw pointer for kernel
    
    // Version tracking (detect in-place modifications)
    version() -> i64
    bump_version() -> void
    
    // Autograd metadata
    requires_grad() -> bool
    set_requires_grad(requires: bool) -> void
    is_leaf() -> bool
    set_is_leaf(leaf: bool) -> void
    grad_fn() -> func(Tensor) -> []Tensor
    set_grad_fn(fn: func(Tensor) -> []Tensor) -> void
    save_tensor(t: Tensor) -> void
    saved_tensors() -> []Tensor
    clear_saved_tensors() -> void
    
    // Reference counting
    incref() -> void
    decref() -> void
    ref_count() -> i64
}

interface ITensorImplFactory {
    // Create TensorImpl from Storage
    create(storage: Storage, metadata: TensorMetadata) -> TensorImpl
    
    // Create with empty autograd_meta
    create_leaf(storage: Storage, metadata: TensorMetadata) -> TensorImpl
    
    // Clone TensorImpl (deep copy)
    clone(impl: TensorImpl) -> TensorImpl
    
    // View (share Storage, different stride)
    view(impl: TensorImpl, new_shape: []i64, new_stride: []i64) -> TensorImpl
    
    // Reshape (share Storage if contiguous)
    reshape(impl: TensorImpl, new_shape: []i64) -> TensorImpl
}

interface ITensorImplLifecycle {
    // Deallocate when ref_count reaches 0
    finalize(impl: TensorImpl) -> void
    
    // Debug: print impl info
    debug_info(impl: TensorImpl) -> string
}
