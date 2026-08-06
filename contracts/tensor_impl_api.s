import "storage_api"
import "dtype_api"
import "layout_api"
import "device_api"

struct version_counter {
    version: i64
}

struct autograd_meta {
    requires_grad: bool
    is_leaf: bool
    grad_fn: func(grad_output: tensor) -> []tensor
    saved_tensors: []tensor
}

struct tensor_metadata {
    shape: []i64
    stride: []i64
    offset: i64
    dtype: DType
    layout: Layout
    device: device
    version_counter: version_counter
}

struct tensor_impl {
    id: i64
    storage: storage
    metadata: tensor_metadata
    autograd_meta: autograd_meta
    ref_count: i64
}
interface i_tensor_impl {
    shape() -> []i64
    stride() -> []i64
    dtype() -> DType
    layout() -> Layout
    device() -> device
    offset() -> i64
    storage() -> storage
    data_ptr() -> i64
    version() -> i64
    bump_version() -> void
    requires_grad() -> bool
    set_requires_grad(requires: bool) -> void
    is_leaf() -> bool
    set_is_leaf(leaf: bool) -> void
    grad_fn() -> func(tensor) -> []tensor
    set_grad_fn(fn: func(tensor) -> []tensor) -> void
    save_tensor(t: tensor) -> void
    saved_tensors() -> []tensor
    clear_saved_tensors() -> void
    incref() -> void
    decref() -> void
    ref_count() -> i64
}
interface i_tensor_impl_factory {
    create(storage: storage, metadata: tensor_metadata) -> tensor_impl
    create_leaf(storage: storage, metadata: tensor_metadata) -> tensor_impl
    clone(impl: tensor_impl) -> tensor_impl
    view(impl: tensor_impl, new_shape: []i64, new_stride: []i64) -> tensor_impl
    reshape(impl: tensor_impl, new_shape: []i64) -> tensor_impl
}
interface i_tensor_impl_lifecycle {
    finalize(impl: tensor_impl) -> void
    debug_info(impl: tensor_impl) -> string
}

