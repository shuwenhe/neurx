import "tensor_impl_api"
import "storage_api"
import "device_api"
import "dtype_api"

struct tensor {
    impl: tensor_impl
}
interface i_tensor {
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
    squeeze(i64 dim) -> tensor
    unsqueeze(i64 dim) -> tensor
    transpose(i64 dim0, i64 dim1) -> tensor
    permute(dims: []i64) -> tensor
    data_ptr() -> i64
    requires_grad() -> bool
    set_requires_grad(bool requires) -> void
    is_leaf() -> bool
    grad() -> tensor
    set_grad(grad: tensor) -> void
    backward() -> void
    backward_with_gradient(gradient: tensor) -> void
    version() -> i64
    bump_version() -> void
}
interface i_tensor_factory {
    zeros(shape: []i64, dtype: DType, device: device) -> tensor
    ones(shape: []i64, dtype: DType, device: device) -> tensor
    full(shape: []i64, f64 fill_value, dtype: DType, device: device) -> tensor
    randn(shape: []i64, dtype: DType, device: device) -> tensor
    rand(shape: []i64, dtype: DType, device: device) -> tensor
    randint(shape: []i64, i64 low, i64 high, device: device) -> tensor
    arange(f64 start, f64 end, f64 step, dtype: DType, device: device) -> tensor
    linspace(f64 start, f64 end, i64 steps, dtype: DType, device: device) -> tensor
    eye(i64 n, i64 m, dtype: DType, device: device) -> tensor
    from_array(data: []f64, shape: []i64, dtype: DType, device: device) -> tensor
}
interface i_tensor_cloning {
    clone(tensor: tensor) -> tensor
    clone_with_dtype(tensor: tensor, dtype: DType) -> tensor
    clone_with_device(tensor: tensor, device: device) -> tensor
}
interface i_tensor_comparison {
    equal(t1: tensor, t2: tensor) -> bool
    allclose(t1: tensor, t2: tensor, f64 rtol, f64 atol) -> bool
    less(t1: tensor, t2: tensor) -> tensor
    greater(t1: tensor, t2: tensor) -> tensor
    equal_element(t1: tensor, t2: tensor) -> tensor
}
interface i_tensor_debug {
    print_shape(tensor: tensor) -> void
    print_info(tensor: tensor) -> void
    print_values(tensor: tensor) -> void
    to_string(tensor: tensor) -> string
    is_valid(tensor: tensor) -> bool
}
