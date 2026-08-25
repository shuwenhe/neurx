import "device_api"

    simple_alloc
    pool_alloc
    caching_alloc
    arena_alloc
    async_alloc
    unified_alloc
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
interface i_allocator {
    allocate(info: allocation_info) -> allocation_result
    deallocate(i64 ptr, i64 size) -> void
    get_allocation_info(i64 ptr) -> allocation_info
    strategy() -> AllocatorStrategy
    device() -> device
    allocated_bytes() -> i64
    reserved_bytes() -> i64
    free_bytes() -> i64
    set_max_memory(i64 bytes) -> void
    get_max_memory() -> i64
}
interface i_caching_allocator {
    empty_cache() -> void
    cached_blocks() -> []i64
    defragment() -> void
    set_caching_enabled(bool enabled) -> void
    is_caching_enabled() -> bool
}
interface i_arena_allocator {
    reset_arena() -> void
    arena_size() -> i64
    arena_offset() -> i64
}
interface i_async_allocator {
    allocate_async(info: allocation_info) -> allocation_result
    wait_allocation(i64 ptr) -> void
    deallocate_async(i64 ptr, i64 size) -> void
}
interface i_unified_allocator {
    allocate_unified(i64 size) -> allocation_result
    set_access_mode(i64 ptr, from_device: device, to_device: device, bool enabled) -> void
    advise_memory(i64 ptr, i64 size, string advice) -> void
}
interface i_allocator_factory {
    create_allocator(device: device, strategy: AllocatorStrategy) -> IAllocator
    get_default_allocator(device: device) -> IAllocator
    set_default_allocator(device: device, allocator: IAllocator) -> void
    register_allocator(device: device, string name, allocator: IAllocator) -> void
}
interface i_allocator_monitoring {
    on_memory_pressure() -> void
    on_allocate(i64 ptr, i64 size) -> void
    on_deallocate(i64 ptr) -> void
}
