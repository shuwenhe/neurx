package neurx.device.cuda_memory_pool

use neurx.device.cuda_runtime_binding
use std.vec.vec

struct memory_block {
    int64 device_ptr
    int64 size
    bool is_free
    int allocation_id
}

struct memory_pool {
    vec[memory_block] blocks
    int64 total_allocated
    int64 max_pool_size
    int next_allocation_id
}

func new_memory_pool(int64 max_size) memory_pool {
    return memory_pool{
        blocks: vec[memory_block](),
        total_allocated: 0,
        max_pool_size: max_size,
        next_allocation_id: 1,
    }
}

func memory_pool_alloc(memory_pool* pool, int64 size) (int64, bool, string) {
    // Try to find a free block large enough
    for i := 0; i < pool.blocks.len(); i = i + 1 {
        if pool.blocks[i].is_free && pool.blocks[i].size >= size {
            ptr := pool.blocks[i].device_ptr
            old_size := pool.blocks[i].size
            pool.blocks[i].is_free = false
            pool.blocks[i].allocation_id = pool.next_allocation_id
            pool.next_allocation_id = pool.next_allocation_id + 1
            
            // If there's leftover space, create a new free block
            if old_size > size {
                new_block := memory_block{
                    device_ptr: ptr + size,
                    size: old_size - size,
                    is_free: true,
                    allocation_id: 0,
                }
                pool.blocks.push(new_block)
            }
            
            return ptr, true, ""
        }
    }
    
    // No suitable free block found, allocate new memory
    if pool.total_allocated + size > pool.max_pool_size {
        return 0, false, "pool size exceeded"
    }
    
    ptr, ok, err := cuda_malloc(size)
    if !ok {
        return 0, false, err
    }
    
    block := memory_block{
        device_ptr: ptr,
        size: size,
        is_free: false,
        allocation_id: pool.next_allocation_id,
    }
    pool.next_allocation_id = pool.next_allocation_id + 1
    pool.blocks.push(block)
    pool.total_allocated = pool.total_allocated + size
    
    return ptr, true, ""
}

func memory_pool_free(memory_pool* pool, int64 ptr) (bool, string) {
    for i := 0; i < pool.blocks.len(); i = i + 1 {
        if pool.blocks[i].device_ptr == ptr {
            if pool.blocks[i].is_free {
                return false, "block already free"
            }
            pool.blocks[i].is_free = true
            pool.blocks[i].allocation_id = 0
            return true, ""
        }
    }
    return false, "ptr not found in pool"
}

func memory_pool_defragment(memory_pool* pool) (bool, string) {
    // Simple defragmentation: merge adjacent free blocks
    i := 0
    for i < pool.blocks.len() - 1 {
        if pool.blocks[i].is_free && pool.blocks[i + 1].is_free {
            pool.blocks[i].size = pool.blocks[i].size + pool.blocks[i + 1].size
            pool.blocks[i + 1] = pool.blocks[pool.blocks.len() - 1]
            pool.blocks.pop()
        } else {
            i = i + 1
        }
    }
    return true, ""
}

func memory_pool_get_total_allocated(memory_pool* pool) int64 {
    return pool.total_allocated
}

func memory_pool_get_total_free(memory_pool* pool) int64 {
    total_free := 0
    for i := 0; i < pool.blocks.len(); i = i + 1 {
        if pool.blocks[i].is_free {
            total_free = total_free + pool.blocks[i].size as int
        }
    }
    return total_free as int64
}

func memory_pool_stats(memory_pool* pool) (int64, int64, int, int) {
    total_allocated := 0
    total_free := 0
    used_blocks := 0
    free_blocks := 0
    
    for i := 0; i < pool.blocks.len(); i = i + 1 {
        if pool.blocks[i].is_free {
            total_free = total_free + pool.blocks[i].size
            free_blocks = free_blocks + 1
        } else {
            total_allocated = total_allocated + pool.blocks[i].size
            used_blocks = used_blocks + 1
        }
    }
    
    return total_allocated, total_free, used_blocks, free_blocks
}

func memory_pool_finalize(memory_pool* pool) (bool, string) {
    for i := 0; i < pool.blocks.len(); i = i + 1 {
        if !pool.blocks[i].is_free {
            // Free allocated block
            ok, err := cuda_free(pool.blocks[i].device_ptr)
            if !ok {
                return false, err
            }
        }
    }
    pool.total_allocated = 0
    return true, ""
}
