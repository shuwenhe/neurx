












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

    id: i64


    storage: Storage
    metadata: TensorMetadata


    autograd_meta: AutogradMeta


    ref_count: i64
}

interface ITensorImpl {

    shape() -> []i64
    stride() -> []i64
    dtype() -> DType
    layout() -> Layout
    device() -> Device
    offset() -> i64


    storage() -> Storage
    data_ptr() -> i64


    version() -> i64
    bump_version() -> void


    requires_grad() -> bool
    set_requires_grad(requires: bool) -> void
    is_leaf() -> bool
    set_is_leaf(leaf: bool) -> void
    grad_fn() -> func(Tensor) -> []Tensor
    set_grad_fn(fn: func(Tensor) -> []Tensor) -> void
    save_tensor(t: Tensor) -> void
    saved_tensors() -> []Tensor
    clear_saved_tensors() -> void


    incref() -> void
    decref() -> void
    ref_count() -> i64
}

interface ITensorImplFactory {

    create(storage: Storage, metadata: TensorMetadata) -> TensorImpl


    create_leaf(storage: Storage, metadata: TensorMetadata) -> TensorImpl


    clone(impl: TensorImpl) -> TensorImpl


    view(impl: TensorImpl, new_shape: []i64, new_stride: []i64) -> TensorImpl


    reshape(impl: TensorImpl, new_shape: []i64) -> TensorImpl
}

interface ITensorImplLifecycle {

    finalize(impl: TensorImpl) -> void


    debug_info(impl: TensorImpl) -> string
}
