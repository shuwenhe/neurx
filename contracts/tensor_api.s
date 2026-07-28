// Tensor API - Public Handle to Tensor Implementation
//
// Tensor is a lightweight PUBLIC HANDLE to TensorImpl.
// Users interact with Tensor (not TensorImpl).
// All actual data and computation lives in TensorImpl.
//
// Architecture:
// Tensor (Handle) → TensorImpl (Implementation) → Storage → Allocator
//
// Benefits of this separation:
// - Zero-copy operations (view, reshape, transpose share Storage)
// - Easy gradient tracking (metadata in TensorImpl)
// - Version counter (detect in-place modifications)
// - Separate from implementation changes

import "tensor_impl_api"
import "storage_api"
import "device_api"
import "dtype_api"

struct Tensor {
    impl: TensorImpl  // Reference to internal implementation
}

interface ITensor {
    // === Metadata Access ===
    shape() -> []i64
    dtype() -> DType
    device() -> Device
    metadata() -> TensorMetadata
    storage() -> Storage
    
    numel() -> i64          // Total elements
    ndim() -> i64           // Number of dimensions
    nbytes() -> i64         // Total bytes
    
    // === Stride and Layout ===
    stride() -> []i64
    offset() -> i64
    is_contiguous() -> bool
    contiguous() -> Tensor
    
    // === Shape Operations (Zero-Copy via Stride) ===
    reshape(new_shape: []i64) -> Tensor
    view(new_shape: []i64) -> Tensor
    squeeze(dim: i64) -> Tensor
    unsqueeze(dim: i64) -> Tensor
    transpose(dim0: i64, dim1: i64) -> Tensor
    permute(dims: []i64) -> Tensor
    
    // === Data Access ===
    data_ptr() -> i64        // Raw pointer (for kernel use only)
    
    // === Gradient Tracking ===
    requires_grad() -> bool
    set_requires_grad(requires: bool) -> void
    is_leaf() -> bool
    
    grad() -> Tensor
    set_grad(grad: Tensor) -> void
    
    backward() -> void
    backward_with_gradient(gradient: Tensor) -> void
    
    // === Version Counter (for in-place detection) ===
    version() -> i64
    bump_version() -> void
}

interface ITensorFactory {
    // === Creation ===
    zeros(shape: []i64, dtype: DType, device: Device) -> Tensor
    ones(shape: []i64, dtype: DType, device: Device) -> Tensor
    full(shape: []i64, fill_value: f64, dtype: DType, device: Device) -> Tensor
    
    // === Random ===
    randn(shape: []i64, dtype: DType, device: Device) -> Tensor
    rand(shape: []i64, dtype: DType, device: Device) -> Tensor
    randint(shape: []i64, low: i64, high: i64, device: Device) -> Tensor
    
    // === Range ===
    arange(start: f64, end: f64, step: f64, dtype: DType, device: Device) -> Tensor
    linspace(start: f64, end: f64, steps: i64, dtype: DType, device: Device) -> Tensor
    
    // === Identity ===
    eye(n: i64, m: i64, dtype: DType, device: Device) -> Tensor
    
    // === From Data ===
    from_array(data: []f64, shape: []i64, dtype: DType, device: Device) -> Tensor
}

interface ITensorCloning {
    // Clone (deep copy)
    clone(tensor: Tensor) -> Tensor
    
    // Clone with different dtype
    clone_with_dtype(tensor: Tensor, dtype: DType) -> Tensor
    
    // Clone with different device
    clone_with_device(tensor: Tensor, device: Device) -> Tensor
}

interface ITensorComparison {
    // Compare tensors
    equal(t1: Tensor, t2: Tensor) -> bool
    
    // Allclose (with tolerance)
    allclose(t1: Tensor, t2: Tensor, rtol: f64, atol: f64) -> bool
    
    // Element-wise comparison
    less(t1: Tensor, t2: Tensor) -> Tensor
    greater(t1: Tensor, t2: Tensor) -> Tensor
    equal_element(t1: Tensor, t2: Tensor) -> Tensor
}

interface ITensorDebug {
    // Print tensor info
    print_shape(tensor: Tensor) -> void
    print_info(tensor: Tensor) -> void
    
    // Print values (small tensors only)
    print_values(tensor: Tensor) -> void
    
    // Get string representation
    to_string(tensor: Tensor) -> string
    
    // Validate tensor integrity
    is_valid(tensor: Tensor) -> bool
}
