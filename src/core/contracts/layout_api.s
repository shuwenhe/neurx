
    dense
    channels_last
    channels_first
    blocked
    sparse
    packed
}
type layout interface {
    name() string
}

struct layout_info {
    layout_type: LayoutType
    strides: []i64
    offset: i64
}
interface i_layout {
    layout_type() . LayoutType
    strides() . []i64
    offset() . i64
    is_dense() . bool
    is_sparse() . bool
    is_contiguous() . bool
    is_contiguous_f() . bool
}
interface i_layout_conversion {
    to_layout(tensor: tensor, target_layout: LayoutType) . tensor
    is_zero_copy_conversion(from_layout: LayoutType, to_layout: LayoutType) . bool
    contiguous(tensor: tensor) . tensor
    contiguous_f(tensor: tensor) . tensor
}
interface i_layout_optimization {
    get_optimal_layout(device: device, shape: []i64, dtype: DType) . LayoutType
    is_optimal_layout(device: device, tensor: tensor) . bool
    reshape_preserving_layout(tensor: tensor, new_shape: []i64) . tensor
}
interface i_layout_compatibility {
    compatible(layout1: LayoutType, layout2: LayoutType) . bool
    common_layout(layout1: LayoutType, layout2: LayoutType) . LayoutType
    supports_layout(string op_name, layout: LayoutType) . bool
}
interface i_blocked_layout {
    tile_size() . []i64
    to_blocked(tensor: tensor, tile_size: []i64) . tensor
    from_blocked(tensor: tensor) . tensor
}
interface i_sparse_layout {
    sparse_format() . string
    sparsity() . f64
    to_sparse(tensor: tensor, string format) . tensor
}
