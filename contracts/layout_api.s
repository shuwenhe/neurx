// Layout API - Data arrangement and memory format
//
// Layout describes how data is arranged in memory.
// Separate from shape (shape is logical, layout is physical).
//
// Examples:
// - Same shape [N,C,H,W] can be NCHW (contiguous) or NHWC (channels last)
// - Storage is shared, but stride/layout differ
//
// This enables:
// - Zero-copy format conversion (just change layout)
// - Backend-specific optimizations (NCHW for CUDA, NHWC for CPU)
// - Fused layout conversion with computation

enum LayoutType {
    Dense          // contiguous dense array
    ChannelsLast   // NHWC (for images)
    ChannelsFirst  // NCHW (for CUDA)
    Blocked        // tiled/blocked layout
    Sparse         // sparse format
    Packed         // bitpacked
}

type Layout interface {
    name() string
}

struct LayoutInfo {
    layout_type: LayoutType
    strides: []i64
    offset: i64
}

interface ILayout {
    // Properties
    layout_type() -> LayoutType
    strides() -> []i64
    offset() -> i64
    
    // Dense vs sparse
    is_dense() -> bool
    is_sparse() -> bool
    
    // Contiguity
    is_contiguous() -> bool
    is_contiguous_f() -> bool  // Fortran order
}

interface ILayoutConversion {
    // Convert between layouts (zero-copy if possible)
    to_layout(tensor: Tensor, target_layout: LayoutType) -> Tensor
    
    // Check if conversion is zero-copy
    is_zero_copy_conversion(from_layout: LayoutType, to_layout: LayoutType) -> bool
    
    // Make contiguous
    contiguous(tensor: Tensor) -> Tensor
    contiguous_f(tensor: Tensor) -> Tensor
}

interface ILayoutOptimization {
    // Suggest optimal layout for device
    get_optimal_layout(device: Device, shape: []i64, dtype: DType) -> LayoutType
    
    // Check if layout is optimal for device
    is_optimal_layout(device: Device, tensor: Tensor) -> bool
    
    // Reshape with layout preservation
    reshape_preserving_layout(tensor: Tensor, new_shape: []i64) -> Tensor
}

interface ILayoutCompatibility {
    // Check if layouts are compatible
    compatible(layout1: LayoutType, layout2: LayoutType) -> bool
    
    // Get common layout for two tensors
    common_layout(layout1: LayoutType, layout2: LayoutType) -> LayoutType
    
    // Check if operation supports layout
    supports_layout(op_name: string, layout: LayoutType) -> bool
}

interface IBlockedLayout {
    // Tile size for blocked layout
    tile_size() -> []i64
    
    // Convert to blocked layout
    to_blocked(tensor: Tensor, tile_size: []i64) -> Tensor
    
    // Convert from blocked layout
    from_blocked(tensor: Tensor) -> Tensor
}

interface ISparseLayout {
    // Sparse format (CSR, COO, etc.)
    sparse_format() -> string
    
    // Sparsity ratio
    sparsity() -> f64
    
    // Convert to sparse
    to_sparse(tensor: Tensor, format: string) -> Tensor
}
