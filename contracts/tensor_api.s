














import "tensor_impl_api"
import "storage_api"
import "device_api"
import "dtype_api"

struct Tensor {
    impl: TensorImpl
}

interface ITensor {

    shape() -> []i64
    dtype() -> DType
    device() -> Device
    metadata() -> TensorMetadata
    storage() -> Storage

    numel() -> i64
    ndim() -> i64
    nbytes() -> i64


    stride() -> []i64
    offset() -> i64
    is_contiguous() -> bool
    contiguous() -> Tensor


    reshape(new_shape: []i64) -> Tensor
    view(new_shape: []i64) -> Tensor
    squeeze(dim: i64) -> Tensor
    unsqueeze(dim: i64) -> Tensor
    transpose(dim0: i64, dim1: i64) -> Tensor
    permute(dims: []i64) -> Tensor


    data_ptr() -> i64


    requires_grad() -> bool
    set_requires_grad(requires: bool) -> void
    is_leaf() -> bool

    grad() -> Tensor
    set_grad(grad: Tensor) -> void

    backward() -> void
    backward_with_gradient(gradient: Tensor) -> void


    version() -> i64
    bump_version() -> void
}

interface ITensorFactory {

    zeros(shape: []i64, dtype: DType, device: Device) -> Tensor
    ones(shape: []i64, dtype: DType, device: Device) -> Tensor
    full(shape: []i64, fill_value: f64, dtype: DType, device: Device) -> Tensor


    randn(shape: []i64, dtype: DType, device: Device) -> Tensor
    rand(shape: []i64, dtype: DType, device: Device) -> Tensor
    randint(shape: []i64, low: i64, high: i64, device: Device) -> Tensor


    arange(start: f64, end: f64, step: f64, dtype: DType, device: Device) -> Tensor
    linspace(start: f64, end: f64, steps: i64, dtype: DType, device: Device) -> Tensor


    eye(n: i64, m: i64, dtype: DType, device: Device) -> Tensor


    from_array(data: []f64, shape: []i64, dtype: DType, device: Device) -> Tensor
}

interface ITensorCloning {

    clone(tensor: Tensor) -> Tensor


    clone_with_dtype(tensor: Tensor, dtype: DType) -> Tensor


    clone_with_device(tensor: Tensor, device: Device) -> Tensor
}

interface ITensorComparison {

    equal(t1: Tensor, t2: Tensor) -> bool


    allclose(t1: Tensor, t2: Tensor, rtol: f64, atol: f64) -> bool


    less(t1: Tensor, t2: Tensor) -> Tensor
    greater(t1: Tensor, t2: Tensor) -> Tensor
    equal_element(t1: Tensor, t2: Tensor) -> Tensor
}

interface ITensorDebug {

    print_shape(tensor: Tensor) -> void
    print_info(tensor: Tensor) -> void


    print_values(tensor: Tensor) -> void


    to_string(tensor: Tensor) -> string


    is_valid(tensor: Tensor) -> bool
}
