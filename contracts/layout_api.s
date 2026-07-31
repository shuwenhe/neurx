enum LayoutType {
    Dense
    ChannelsLast
    ChannelsFirst
    Blocked
    Sparse
    Packed
}
type Layout interface {
    name() string
}
struct layout_info {
    layout_type: LayoutType
    strides: []i64
    offset: i64
}
interface ILayout {
    layout_type() -> LayoutType
    strides() -> []i64
    offset() -> i64
    is_dense() -> bool
    is_sparse() -> bool
    is_contiguous() -> bool
    is_contiguous_f() -> bool
}
interface ILayoutConversion {
    to_layout(tensor: tensor, target_layout: LayoutType) -> tensor
    is_zero_copy_conversion(from_layout: LayoutType, to_layout: LayoutType) -> bool
    contiguous(tensor: tensor) -> tensor
    contiguous_f(tensor: tensor) -> tensor
}
interface ILayoutOptimization {
    get_optimal_layout(device: device, shape: []i64, dtype: DType) -> LayoutType
    is_optimal_layout(device: device, tensor: tensor) -> bool
    reshape_preserving_layout(tensor: tensor, new_shape: []i64) -> tensor
}
interface ILayoutCompatibility {
    compatible(layout1: LayoutType, layout2: LayoutType) -> bool
    common_layout(layout1: LayoutType, layout2: LayoutType) -> LayoutType
    supports_layout(op_name: string, layout: LayoutType) -> bool
}
interface IBlockedLayout {
    tile_size() -> []i64
    to_blocked(tensor: tensor, tile_size: []i64) -> tensor
    from_blocked(tensor: tensor) -> tensor
}
interface ISparseLayout {
    sparse_format() -> string
    sparsity() -> f64
    to_sparse(tensor: tensor, format: string) -> tensor
}
