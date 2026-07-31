import "device_api"

enum AllocatorStrategy {
    SimpleAlloc
    PoolAlloc
    CachingAlloc
    ArenaAlloc
    AsyncAlloc
    UnifiedAlloc
}

struct AllocationInfo {
    device: Device
    size: i64
    alignment: i64
    strategy: AllocatorStrategy
}

struct AllocationResult {
    ptr: i64
    allocated_size: i64
    actual_device: Device
}

interface IAllocator {

    allocate(info: AllocationInfo) -> AllocationResult

    deallocate(ptr: i64, size: i64) -> void

    get_allocation_info(ptr: i64) -> AllocationInfo

    strategy() -> AllocatorStrategy

    device() -> Device

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

    allocate_async(info: AllocationInfo) -> AllocationResult

    wait_allocation(ptr: i64) -> void

    deallocate_async(ptr: i64, size: i64) -> void
}

interface IUnifiedAllocator {

    allocate_unified(size: i64) -> AllocationResult

    set_access_mode(ptr: i64, from_device: Device, to_device: Device, enabled: bool) -> void

    advise_memory(ptr: i64, size: i64, advice: string) -> void
}

interface IAllocatorFactory {

    create_allocator(device: Device, strategy: AllocatorStrategy) -> IAllocator

    get_default_allocator(device: Device) -> IAllocator

    set_default_allocator(device: Device, allocator: IAllocator) -> void

    register_allocator(device: Device, name: string, allocator: IAllocator) -> void
}

interface IAllocatorMonitoring {

    on_memory_pressure() -> void

    on_allocate(ptr: i64, size: i64) -> void

    on_deallocate(ptr: i64) -> void
}
