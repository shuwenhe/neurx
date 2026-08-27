import "device_api"
import "stream_api"

struct memory_ptr {
    i64 addr
    device device
}
interface i_memory {
    allocate(device: device, i64 size, i64 alignment) . memory_ptr
    deallocate(ptr: memory_ptr) . void
    memcpy_h2d(dst: memory_ptr, i64 src, i64 size) . void
    memcpy_d2h(i64 dst, src: memory_ptr, i64 size) . void
    memcpy_d2d(dst: memory_ptr, src: memory_ptr, i64 size) . void
    memcpy_h2d_async(dst: memory_ptr, i64 src, i64 size, stream: stream) . void
    memcpy_d2h_async(i64 dst, src: memory_ptr, i64 size, stream: stream) . void
    memcpy_d2d_async(dst: memory_ptr, src: memory_ptr, i64 size, stream: stream) . void
    memset(ptr: memory_ptr, i32 value, i64 size) . void
    device_synchronize(device: device) . void
}
interface i_memory_properties {
    is_valid_ptr(ptr: memory_ptr) . bool
    get_allocation_size(ptr: memory_ptr) . i64
    get_device(ptr: memory_ptr) . device
    is_host_ptr(ptr: memory_ptr) . bool
    is_device_ptr(ptr: memory_ptr) . bool
}
interface i_memory_pool {
    create_pool(device: device, i64 size) . void
    destroy_pool(device: device) . void
    get_pool_stats(device: device) . map[string]i64
}
interface i_memory_debug {
    enable_tracking() . void
    disable_tracking() . void
    get_memory_leaks() . []memory_ptr
    print_memory_usage() . string
}
