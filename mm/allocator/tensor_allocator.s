package neurx.mm.allocator

use std.vec.vec

struct free_block {
    int block_ptr
    int size_bytes
    int next_block_ptr
}

struct allocated_block {
    int block_ptr
    int size_bytes
    int allocate_time_us
}

struct memory_pool {
    int pool_id
    int total_size_mb
    int allocated_size_mb
    int free_size_mb
    int base_addr
    vec[allocated_block]* allocated_list
    free_block* free_list_head
    int fragmentation_ratio
}

struct tensor_allocator {
    int pool_id
    int alignment_bytes
    bool enable_coalescing
}

struct allocation_result {
    int ptr
    int size_bytes
    int pool_id
}

func create_memory_pool(int size_mb) (memory_pool, string) {
    total_bytes := size_mb * 1024 * 1024
    base_addr := 1000000
    
    initial_free_block := free_block {
        block_ptr: base_addr,
        size_bytes: total_bytes,
        next_block_ptr: 0
    }
    
    allocated_list := vec[allocated_block]()
    
    pool := memory_pool {
        pool_id: 0,
        total_size_mb: size_mb,
        allocated_size_mb: 0,
        free_size_mb: size_mb,
        base_addr: base_addr,
        allocated_list: &mut allocated_list,
        free_list_head: &initial_free_block,
        fragmentation_ratio: 0
    }
    pool, ""
}

func create_tensor_allocator(memory_pool* pool) tensor_allocator {
    tensor_allocator {
        pool_id: pool->pool_id,
        alignment_bytes: 256,
        enable_coalescing: true
    }
}

func allocate_tensor(tensor_allocator* allocator, memory_pool* pool, int size_mb) (allocation_result, string) {
    size_bytes := size_mb * 1024 * 1024
    aligned_size := align_size(size_bytes, allocator->alignment_bytes)
    
    result := find_free_block(pool, aligned_size)
    
    if result.block_ptr == 0 {
        freed := garbage_collection(pool)
        if freed < aligned_size {
            return 0, "Insufficient memory after GC"
        }
        result2 := find_free_block(pool, aligned_size)
        if result2.block_ptr == 0 {
            return 0, "Memory allocation failed"
        }
    }
    
    allocated_block := allocated_block {
        block_ptr: result.block_ptr,
        size_bytes: aligned_size,
        allocate_time_us: get_current_time_us()
    }
    
    pool->allocated_list->push(allocated_block)
    
    pool->allocated_size_mb = pool->allocated_size_mb + (aligned_size / (1024 * 1024))
    pool->free_size_mb = pool->total_size_mb - pool->allocated_size_mb
    
    update_fragmentation_ratio(pool)
    
    (allocation_result {
        ptr: result.block_ptr,
        size_bytes: aligned_size,
        pool_id: allocator->pool_id
    })
}

func deallocate_tensor(tensor_allocator* allocator, memory_pool* pool, int ptr) (int, string) {
    found_idx := -1
    found_size := 0
    
    for i in 0..pool->allocated_list->len() {
        block := pool->allocated_list->get(i)
        if block.block_ptr == ptr {
            found_idx = i
            found_size = block.size_bytes
        }
    }
    
    if found_idx < 0 {
        return 0, "Block not found"
    }
    
    pool->allocated_list->remove(found_idx)
    
    add_free_block(pool, ptr, found_size)
    
    if allocator->enable_coalescing {
        coalesce_free_blocks(pool)
    }
    
    pool->allocated_size_mb = pool->allocated_size_mb - (found_size / (1024 * 1024))
    pool->free_size_mb = pool->total_size_mb - pool->allocated_size_mb
    
    update_fragmentation_ratio(pool)
    found_size, ""
}

func get_pool_stats(memory_pool* pool) memory_pool {
    pool*
}

func find_free_block(memory_pool* pool, int size_needed) (allocation_result, string) {
    current_block := pool->free_list_head
    
    while current_block != 0 as free_block* {
        if current_block->size_bytes >= size_needed {
            return (allocation_result {
                ptr: current_block->block_ptr,
                size_bytes: size_needed,
                pool_id: pool->pool_id
            })
        }
        
        if current_block->next_block_ptr == 0 {
            break
        }
        
        current_block = current_block->next_block_ptr as free_block*
    }
    
    (allocation_result {
        ptr: 0,
        size_bytes: 0,
        pool_id: pool->pool_id
    })
}

func add_free_block(memory_pool* pool, int block_ptr, int size_bytes) (int, string) {
    new_block := free_block {
        block_ptr: block_ptr,
        size_bytes: size_bytes,
        next_block_ptr: pool->free_list_head as int
    }
    
    pool->free_list_head = &new_block
    0, ""
}

func coalesce_free_blocks(memory_pool* pool) (int, string) {
    current := pool->free_list_head
    coalesced := 0
    
    while current != 0 as free_block* {
        if current->next_block_ptr != 0 {
            next := current->next_block_ptr as free_block*
            
            if current->block_ptr + current->size_bytes == next->block_ptr {
                current->size_bytes = current->size_bytes + next->size_bytes
                current->next_block_ptr = next->next_block_ptr
                coalesced = coalesced + 1
            }
        }
        
        if current->next_block_ptr == 0 {
            break
        }
        
        current = current->next_block_ptr as free_block*
    }
    coalesced, ""
}

func garbage_collection(memory_pool* pool) (int, string) {
    freed := 0
    
    candidates := vec[allocated_block]()
    
    for i in 0..pool->allocated_list->len() {
        block := pool->allocated_list->get(i)
        age := get_current_time_us() - block.allocate_time_us
        
        if age > 60000000 {
            candidates.push(block)
            freed = freed + block.size_bytes
        }
    }
    
    for i in 0..candidates.len() {
        block := candidates.get(i)
        deallocate_tensor_internal(pool, block.block_ptr)
    }
    
    if pool->enable_coalescing {
        coalesce_free_blocks(pool)
    }
    freed, ""
}

func deallocate_tensor_internal(memory_pool* pool, int ptr) (int, string) {
    found_idx := -1
    found_size := 0
    
    for i in 0..pool->allocated_list->len() {
        block := pool->allocated_list->get(i)
        if block.block_ptr == ptr {
            found_idx = i
            found_size = block.size_bytes
        }
    }
    
    if found_idx >= 0 {
        pool->allocated_list->remove(found_idx)
        add_free_block(pool, ptr, found_size)
    }
    found_size, ""
}

func align_size(int size, int alignment) int {
    if size % alignment == 0 {
        size
    } else {
        ((size / alignment) + 1) * alignment
    }
}

func update_fragmentation_ratio(memory_pool* pool) {
    if pool->allocated_size_mb > 0 {
        pool->fragmentation_ratio = (pool->free_size_mb * 100) / pool->total_size_mb
    }
}

func get_current_time_us() int {
    0
}

func cleanup_memory_pool(memory_pool* pool) (int, string) {
    pool->allocated_size_mb = 0
    pool->free_size_mb = pool->total_size_mb
    0, ""
}
