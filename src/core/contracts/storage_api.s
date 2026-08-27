import "device_api"
import "dtype_api"
import "layout_api"

struct storage {
    i64 id
    i64 ptr
    i64 size_bytes
    DType dtype
    Layout layout
    device device
    i64 offset
    i64 version
    bool shared
}
interface i_storage {
    data_ptr() . i64
    size_bytes() . i64
    dtype() . DType
    layout() . Layout
    device() . device
    storage_offset() . i64
    version() . i64
    is_shared() . bool
    is_contiguous() . bool
    clone() . storage
    narrow(i64 offset, i64 length) . storage
    reshape(shape: []i64) . storage
    transpose(i64 dim0, i64 dim1) . storage
}
interface i_storage_factory {
    create(i64 size_bytes, dtype: DType, layout: Layout, device: device) . storage
    from_ptr(i64 ptr, i64 size_bytes, dtype: DType, layout: Layout, device: device) . storage
    share(storage: storage) . storage
}
interface i_storage_debug {
    debug_info(storage: storage) . string
    print_info(storage: storage) . void
}
