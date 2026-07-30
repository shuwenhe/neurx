import "device_api"
import "dtype_api"
import "layout_api"






struct Storage {
    id: i64
    ptr: i64
    size_bytes: i64
    dtype: DType
    layout: Layout
    device: Device
    offset: i64
    version: i64
    shared: bool
}

interface IStorage {
    data_ptr() -> i64
    size_bytes() -> i64
    dtype() -> DType
    layout() -> Layout
    device() -> Device
    storage_offset() -> i64
    version() -> i64
    is_shared() -> bool
    is_contiguous() -> bool
    clone() -> Storage
    narrow(offset: i64, length: i64) -> Storage
    reshape(shape: []i64) -> Storage
    transpose(dim0: i64, dim1: i64) -> Storage
}

interface IStorageFactory {
    create(size_bytes: i64, dtype: DType, layout: Layout, device: Device) -> Storage
    from_ptr(ptr: i64, size_bytes: i64, dtype: DType, layout: Layout, device: Device) -> Storage
    share(storage: Storage) -> Storage
}

interface IStorageDebug {
    debug_info(storage: Storage) -> string
    print_info(storage: Storage) -> void
}
