// Allocator API - Memory allocation strategies
//
// Separation of concerns:
// - Memory: raw resource management (allocation/deallocation/copy)
// - Allocator: strategy layer (caching, arena, async, etc.)
//
// Allocator -> Memory (delegate raw operations)
//
// This allows:
// - Swapping allocators without changing Device
// - Different strategies per device type
// - Caching without touching Storage/Tensor code
// - Arena allocation for training efficiency

import "device_api"

enum AllocatorStrategy {
    SimpleAlloc       // naive malloc/free
    PoolAlloc        // memory pool
    CachingAlloc     // caching allocator (PyTorch-style)
    ArenaAlloc       // arena allocation
    AsyncAlloc       // async allocation
    UnifiedAlloc     // unified memory (CUDA)
}

struct AllocationInfo {
    device: Device
    size: i64
    alignment: i64
    strategy: AllocatorStrategy
}

struct AllocationResult {
    ptr: i64           // allocated pointer
    allocated_size: i64
    actual_device: Device
}

interface IAllocator {
    // Allocate memory
    allocate(info: AllocationInfo) -> AllocationResult
    
    // Deallocate memory
    deallocate(ptr: i64, size: i64) -> void
    
    // Get allocation info
    get_allocation_info(ptr: i64) -> AllocationInfo
    
    // Strategy type
    strategy() -> AllocatorStrategy
    
    // Device this allocator serves
    device() -> Device
    
    // Statistics
    allocated_bytes() -> i64
    reserved_bytes() -> i64
    free_bytes() -> i64
    
    // Configuration
    set_max_memory(bytes: i64) -> void
    get_max_memory() -> i64
}

interface ICachingAllocator {
    // Cache management
    empty_cache() -> void
    
    // Get cached blocks
    cached_blocks() -> []i64
    
    // Clear unused blocks
    defragment() -> void
    
    // Enable/disable caching
    set_caching_enabled(enabled: bool) -> void
    is_caching_enabled() -> bool
}

interface IArenaAllocator {
    // Arena management
    reset_arena() -> void
    
    // Get arena size
    arena_size() -> i64
    
    // Current position in arena
    arena_offset() -> i64
}

interface IAsyncAllocator {
    // Allocate asynchronously
    allocate_async(info: AllocationInfo) -> AllocationResult
    
    // Wait for allocation to complete
    wait_allocation(ptr: i64) -> void
    
    // Deallocate asynchronously
    deallocate_async(ptr: i64, size: i64) -> void
}

interface IUnifiedAllocator {
    // CUDA Unified Memory
    allocate_unified(size: i64) -> AllocationResult
    
    // Set access mode
    set_access_mode(ptr: i64, from_device: Device, to_device: Device, enabled: bool) -> void
    
    // Advise memory location
    advise_memory(ptr: i64, size: i64, advice: string) -> void
}

interface IAllocatorFactory {
    // Create allocator for device
    create_allocator(device: Device, strategy: AllocatorStrategy) -> IAllocator
    
    // Get default allocator for device
    get_default_allocator(device: Device) -> IAllocator
    
    // Set default allocator
    set_default_allocator(device: Device, allocator: IAllocator) -> void
    
    // Register custom allocator
    register_allocator(device: Device, name: string, allocator: IAllocator) -> void
}

interface IAllocatorMonitoring {
    // Memory pressure callback
    on_memory_pressure() -> void
    
    // Allocation hook
    on_allocate(ptr: i64, size: i64) -> void
    
    // Deallocation hook
    on_deallocate(ptr: i64) -> void
}
