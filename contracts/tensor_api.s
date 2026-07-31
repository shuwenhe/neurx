import "tensor_impl_api"
import "storage_api"
import "device_api"
import "dtype_api"
struct tensor {
    impl: tensor_impl
}
interface ITensor {
    shape() -> []i64
    dtype() -> DType
    device() -> device
    metadata() -> tensor_metadata
    storage() -> storage
    numel() -> i64
    ndim() -> i64
    nbytes() -> i64
    stride() -> []i64
    offset() -> i64
    is_contiguous() -> bool
    contiguous() -> tensor
    reshape(new_shape: []i64) -> tensor
    view(new_shape: []i64) -> tensor
    squeeze(dim: i64) -> tensor
    unsqueeze(dim: i64) -> tensor
    transpose(dim0: i64, dim1: i64) -> tensor
    permute(dims: []i64) -> tensor
    data_ptr() -> i64
    requires_grad() -> bool
    set_requires_grad(requires: bool) -> void
    is_leaf() -> bool
    grad() -> tensor
    set_grad(grad: tensor) -> void
    backward() -> void
    backward_with_gradient(gradient: tensor) -> void
    version() -> i64
    bump_version() -> void
}
interface ITensorFactory {
    zeros(shape: []i64, dtype: DType, device: device) -> tensor
    ones(shape: []i64, dtype: DType, device: device) -> tensor
    full(shape: []i64, fill_value: f64, dtype: DType, device: device) -> tensor
    randn(shape: []i64, dtype: DType, device: device) -> tensor
    rand(shape: []i64, dtype: DType, device: device) -> tensor
    randint(shape: []i64, low: i64, high: i64, device: device) -> tensor
    arange(start: f64, end: f64, step: f64, dtype: DType, device: device) -> tensor
    linspace(start: f64, end: f64, steps: i64, dtype: DType, device: device) -> tensor
    eye(n: i64, m: i64, dtype: DType, device: device) -> tensor
    from_array(data: []f64, shape: []i64, dtype: DType, device: device) -> tensor
}
interface ITensorCloning {
    clone(tensor: tensor) -> tensor
    clone_with_dtype(tensor: tensor, dtype: DType) -> tensor
    clone_with_device(tensor: tensor, device: device) -> tensor
}
interface ITensorComparison {
    equal(t1: tensor, t2: tensor) -> bool
    allclose(t1: tensor, t2: tensor, rtol: f64, atol: f64) -> bool
    less(t1: tensor, t2: tensor) -> tensor
    greater(t1: tensor, t2: tensor) -> tensor
    equal_element(t1: tensor, t2: tensor) -> tensor
}
interface ITensorDebug {
    print_shape(tensor: tensor) -> void
    print_info(tensor: tensor) -> void
    print_values(tensor: tensor) -> void
    to_string(tensor: tensor) -> string
    is_valid(tensor: tensor) -> bool
}
