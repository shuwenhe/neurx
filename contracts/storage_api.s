import "device_api"
import "dtype_api"
import "layout_api"
struct storage {
    id: i64
    ptr: i64
    size_bytes: i64
    dtype: DType
    layout: Layout
    device: device
    offset: i64
    version: i64
    shared: bool
}
interface i_storage {
    data_ptr() -> i64
    size_bytes() -> i64
    dtype() -> DType
    layout() -> Layout
    device() -> device
    storage_offset() -> i64
    version() -> i64
    is_shared() -> bool
    is_contiguous() -> bool
    clone() -> storage
    narrow(offset: i64, length: i64) -> storage
    reshape(shape: []i64) -> storage
    transpose(dim0: i64, dim1: i64) -> storage
}
interface i_storage_factory {
    create(size_bytes: i64, dtype: DType, layout: Layout, device: device) -> storage
    from_ptr(ptr: i64, size_bytes: i64, dtype: DType, layout: Layout, device: device) -> storage
    share(storage: storage) -> storage
}
interface i_storage_debug {
    debug_info(storage: storage) -> string
    print_info(storage: storage) -> void
}

