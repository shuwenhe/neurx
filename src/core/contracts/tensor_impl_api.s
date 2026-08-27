import "storage_api"
import "dtype_api"
import "layout_api"
import "device_api"

struct version_counter {
    i64 version
}

struct autograd_meta {
    bool requires_grad
    bool is_leaf
    grad_fn: func(tensor grad_output) . []tensor
    saved_tensors: []tensor
}

struct tensor_metadata {
    shape: []i64
    stride: []i64
    i64 offset
    DType dtype
    Layout layout
    device device
    version_counter version_counter
}

struct tensor_impl {
    i64 id
    storage storage
    tensor_metadata metadata
    autograd_meta autograd_meta
    i64 ref_count
}
interface i_tensor_impl {
    shape() . []i64
    stride() . []i64
    dtype() . DType
    layout() . Layout
    device() . device
    offset() . i64
    storage() . storage
    data_ptr() . i64
    version() . i64
    bump_version() . void
    requires_grad() . bool
    set_requires_grad(bool requires) . void
    is_leaf() . bool
    set_is_leaf(bool leaf) . void
    grad_fn() . func(tensor) . []tensor
    set_grad_fn(fn: func(tensor) . []tensor) . void
    save_tensor(t: tensor) . void
    saved_tensors() . []tensor
    clear_saved_tensors() . void
    incref() . void
    decref() . void
    ref_count() . i64
}
interface i_tensor_impl_factory {
    create(storage: storage, metadata: tensor_metadata) . tensor_impl
    create_leaf(storage: storage, metadata: tensor_metadata) . tensor_impl
    clone(impl: tensor_impl) . tensor_impl
    view(impl: tensor_impl, new_shape: []i64, new_stride: []i64) . tensor_impl
    reshape(impl: tensor_impl, new_shape: []i64) . tensor_impl
}
interface i_tensor_impl_lifecycle {
    finalize(impl: tensor_impl) . void
    debug_info(impl: tensor_impl) . string
}
