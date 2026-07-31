import "device_api"
import "stream_api"

struct MemoryPtr {
    addr: i64
    device: Device
}

interface IMemory {

    allocate(device: Device, size: i64, alignment: i64) -> MemoryPtr

    deallocate(ptr: MemoryPtr) -> void

    memcpy_h2d(dst: MemoryPtr, src: i64, size: i64) -> void

    memcpy_d2h(dst: i64, src: MemoryPtr, size: i64) -> void

    memcpy_d2d(dst: MemoryPtr, src: MemoryPtr, size: i64) -> void

    memcpy_h2d_async(dst: MemoryPtr, src: i64, size: i64, stream: Stream) -> void

    memcpy_d2h_async(dst: i64, src: MemoryPtr, size: i64, stream: Stream) -> void

    memcpy_d2d_async(dst: MemoryPtr, src: MemoryPtr, size: i64, stream: Stream) -> void

    memset(ptr: MemoryPtr, value: i32, size: i64) -> void

    device_synchronize(device: Device) -> void
}

interface IMemoryProperties {

    is_valid_ptr(ptr: MemoryPtr) -> bool

    get_allocation_size(ptr: MemoryPtr) -> i64

    get_device(ptr: MemoryPtr) -> Device

    is_host_ptr(ptr: MemoryPtr) -> bool

    is_device_ptr(ptr: MemoryPtr) -> bool
}

interface IMemoryPool {

    create_pool(device: Device, size: i64) -> void

    destroy_pool(device: Device) -> void

    get_pool_stats(device: Device) -> map[string]i64
}

interface IMemoryDebug {

    enable_tracking() -> void

    disable_tracking() -> void

    get_memory_leaks() -> []MemoryPtr

    print_memory_usage() -> string
}
