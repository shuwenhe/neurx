import "device_api"
import "stream_api"
struct memory_ptr {
    addr: i64
    device: device
}
interface i_memory {
    allocate(device: device, size: i64, alignment: i64) -> memory_ptr
    deallocate(ptr: memory_ptr) -> void
    memcpy_h2d(dst: memory_ptr, src: i64, size: i64) -> void
    memcpy_d2h(dst: i64, src: memory_ptr, size: i64) -> void
    memcpy_d2d(dst: memory_ptr, src: memory_ptr, size: i64) -> void
    memcpy_h2d_async(dst: memory_ptr, src: i64, size: i64, stream: stream) -> void
    memcpy_d2h_async(dst: i64, src: memory_ptr, size: i64, stream: stream) -> void
    memcpy_d2d_async(dst: memory_ptr, src: memory_ptr, size: i64, stream: stream) -> void
    memset(ptr: memory_ptr, value: i32, size: i64) -> void
    device_synchronize(device: device) -> void
}
interface i_memory_properties {
    is_valid_ptr(ptr: memory_ptr) -> bool
    get_allocation_size(ptr: memory_ptr) -> i64
    get_device(ptr: memory_ptr) -> device
    is_host_ptr(ptr: memory_ptr) -> bool
    is_device_ptr(ptr: memory_ptr) -> bool
}
interface i_memory_pool {
    create_pool(device: device, size: i64) -> void
    destroy_pool(device: device) -> void
    get_pool_stats(device: device) -> map[string]i64
}
interface i_memory_debug {
    enable_tracking() -> void
    disable_tracking() -> void
    get_memory_leaks() -> []memory_ptr
    print_memory_usage() -> string
}
