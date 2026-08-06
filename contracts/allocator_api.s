import "device_api"
enum AllocatorStrategy {
    SimpleAlloc
    PoolAlloc
    CachingAlloc
    ArenaAlloc
    AsyncAlloc
    UnifiedAlloc
}
struct allocation_info {
    device: device
    size: i64
    alignment: i64
    strategy: AllocatorStrategy
}
struct allocation_result {
    ptr: i64
    allocated_size: i64
    actual_device: device
}
interface IAllocator {
    allocate(info: allocation_info) -> allocation_result
    deallocate(ptr: i64, size: i64) -> void
    get_allocation_info(ptr: i64) -> allocation_info
    strategy() -> AllocatorStrategy
    device() -> device
    allocated_bytes() -> i64
    reserved_bytes() -> i64
    free_bytes() -> i64
    set_max_memory(bytes: i64) -> void
    get_max_memory() -> i64
}
interface ICachingAllocator {
    empty_cache() -> void
    cached_blocks() -> []i64
    defragment() -> void
    set_caching_enabled(enabled: bool) -> void
    is_caching_enabled() -> bool
}
interface IArenaAllocator {
    reset_arena() -> void
    arena_size() -> i64
    arena_offset() -> i64
}
interface IAsyncAllocator {
    allocate_async(info: allocation_info) -> allocation_result
    wait_allocation(ptr: i64) -> void
    deallocate_async(ptr: i64, size: i64) -> void
}
interface IUnifiedAllocator {
    allocate_unified(size: i64) -> allocation_result
    set_access_mode(ptr: i64, from_device: device, to_device: device, enabled: bool) -> void
    advise_memory(ptr: i64, size: i64, advice: string) -> void
}
interface IAllocatorFactory {
    create_allocator(device: device, strategy: AllocatorStrategy) -> IAllocator
    get_default_allocator(device: device) -> IAllocator
    set_default_allocator(device: device, allocator: IAllocator) -> void
    register_allocator(device: device, name: string, allocator: IAllocator) -> void
}
interface IAllocatorMonitoring {
    on_memory_pressure() -> void
    on_allocate(ptr: i64, size: i64) -> void
    on_deallocate(ptr: i64) -> void
}
