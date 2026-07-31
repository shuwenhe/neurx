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

struct LayoutInfo {
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

    to_layout(tensor: Tensor, target_layout: LayoutType) -> Tensor

    is_zero_copy_conversion(from_layout: LayoutType, to_layout: LayoutType) -> bool

    contiguous(tensor: Tensor) -> Tensor
    contiguous_f(tensor: Tensor) -> Tensor
}

interface ILayoutOptimization {

    get_optimal_layout(device: Device, shape: []i64, dtype: DType) -> LayoutType

    is_optimal_layout(device: Device, tensor: Tensor) -> bool

    reshape_preserving_layout(tensor: Tensor, new_shape: []i64) -> Tensor
}

interface ILayoutCompatibility {

    compatible(layout1: LayoutType, layout2: LayoutType) -> bool

    common_layout(layout1: LayoutType, layout2: LayoutType) -> LayoutType

    supports_layout(op_name: string, layout: LayoutType) -> bool
}

interface IBlockedLayout {

    tile_size() -> []i64

    to_blocked(tensor: Tensor, tile_size: []i64) -> Tensor

    from_blocked(tensor: Tensor) -> Tensor
}

interface ISparseLayout {

    sparse_format() -> string

    sparsity() -> f64

    to_sparse(tensor: Tensor, format: string) -> Tensor
}
