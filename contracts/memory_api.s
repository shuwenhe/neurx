// Memory API - Raw memory resource management
//
// Separation of concerns:
// - Memory: raw allocation/deallocation/copy
// - Allocator: strategy (caching, arena, etc.)
//
// Memory is purely resource-level.
// Allocator wraps Memory with policies.

import "device_api"
import "stream_api"

struct MemoryPtr {
    addr: i64
    device: Device
}

interface IMemory {
    // Allocation (raw)
    allocate(device: Device, size: i64, alignment: i64) -> MemoryPtr
    
    // Deallocation (raw)
    deallocate(ptr: MemoryPtr) -> void
    
    // Copy host to device
    memcpy_h2d(dst: MemoryPtr, src: i64, size: i64) -> void
    
    // Copy device to host
    memcpy_d2h(dst: i64, src: MemoryPtr, size: i64) -> void
    
    // Copy device to device
    memcpy_d2d(dst: MemoryPtr, src: MemoryPtr, size: i64) -> void
    
    // Async copy h2d
    memcpy_h2d_async(dst: MemoryPtr, src: i64, size: i64, stream: Stream) -> void
    
    // Async copy d2h
    memcpy_d2h_async(dst: i64, src: MemoryPtr, size: i64, stream: Stream) -> void
    
    // Async copy d2d
    memcpy_d2d_async(dst: MemoryPtr, src: MemoryPtr, size: i64, stream: Stream) -> void
    
    // Set memory value
    memset(ptr: MemoryPtr, value: i32, size: i64) -> void
    
    // Device synchronization
    device_synchronize(device: Device) -> void
}

interface IMemoryProperties {
    // Check if pointer is valid
    is_valid_ptr(ptr: MemoryPtr) -> bool
    
    // Get allocation size
    get_allocation_size(ptr: MemoryPtr) -> i64
    
    // Get device for pointer
    get_device(ptr: MemoryPtr) -> Device
    
    // Check if pointer is host memory
    is_host_ptr(ptr: MemoryPtr) -> bool
    
    // Check if pointer is device memory
    is_device_ptr(ptr: MemoryPtr) -> bool
}

interface IMemoryPool {
    // Preallocate memory pool
    create_pool(device: Device, size: i64) -> void
    
    // Destroy pool
    destroy_pool(device: Device) -> void
    
    // Get pool statistics
    get_pool_stats(device: Device) -> map[string]i64
}

interface IMemoryDebug {
    // Enable memory tracking
    enable_tracking() -> void
    
    // Disable memory tracking
    disable_tracking() -> void
    
    // Get memory leak info
    get_memory_leaks() -> []MemoryPtr
    
    // Print memory usage
    print_memory_usage() -> string
}
