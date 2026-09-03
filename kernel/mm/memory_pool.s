package neurx.kernel.mm.memory_pool

enum allocation_strategy {
    STRATEGY_BUDDY,
    STRATEGY_BITMAP,
    STRATEGY_BEST_FIT,
}

enum pool_type {
    POOL_GPU_DEVICE,
    POOL_GPU_HOST,
    POOL_DMA_BUFFER,
    POOL_UVM,
}

struct memory_block {
    int address
    int size
    bool is_allocated
    int allocation_order
    string owner_id
    int timestamp
}

struct pool_stats {
    int total_bytes
    int used_bytes
    int free_bytes
    int block_count
    int allocated_blocks
    int free_blocks
    int fragmentation_percent
    int peak_used_bytes
}

struct memory_pool {
    string pool_name
    pool_type pool_type_val
    allocation_strategy strategy
    
    int total_bytes
    int used_bytes
    int free_bytes
    
    memory_block[] blocks
    int block_count
    
    pool_stats stats
    
    int alignment_bytes
    bool enable_defrag
    int defrag_threshold_percent
    
    int lock_holder
}

struct pool_registry {
    memory_pool[] pools
    int pool_count
}

pool_registry global_pools = pool_registry {
    pools: make([]memory_pool, 16),
    pool_count: 0,
}

func pool_create(
    string pool_name,
    pool_type pool_type_val,
    allocation_strategy strategy,
    int total_bytes,
    int alignment_bytes
) int {
    if global_pools.pool_count >= len(global_pools.pools) {
        return -1
    }
    
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            return -2
        }
        i = i + 1
    }
    
    memory_pool pool = memory_pool {
        pool_name: pool_name,
        pool_type_val: pool_type_val,
        strategy: strategy,
        total_bytes: total_bytes,
        used_bytes: 0,
        free_bytes: total_bytes,
        blocks: make([]memory_block, 1024),
        block_count: 0,
        alignment_bytes: alignment_bytes,
        enable_defrag: true,
        defrag_threshold_percent: 30,
        lock_holder: -1,
    }
    
    pool.stats = pool_stats {
        total_bytes: total_bytes,
        used_bytes: 0,
        free_bytes: total_bytes,
        block_count: 0,
        allocated_blocks: 0,
        free_blocks: 0,
        fragmentation_percent: 0,
        peak_used_bytes: 0,
    }
    
    pool.blocks[0] = memory_block {
        address: 0,
        size: total_bytes,
        is_allocated: false,
        allocation_order: 0,
        owner_id: "",
        timestamp: 0,
    }
    pool.block_count = 1
    
    global_pools.pools[global_pools.pool_count] = pool
    global_pools.pool_count = global_pools.pool_count + 1
    
    return 0
}

func pool_alloc(string pool_name, int size_bytes, string owner_id) int {

    int pool_idx = -1
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            pool_idx = i
        }
        i = i + 1
    }
    
    if pool_idx < 0 {
        return -1
    }
    
    memory_pool pool = global_pools.pools[pool_idx]
    
    int aligned_size = size_bytes
    if aligned_size % pool.alignment_bytes != 0 {
        aligned_size = aligned_size + (pool.alignment_bytes - (aligned_size % pool.alignment_bytes))
    }
    
    if aligned_size > pool.free_bytes {
        return -2
    }
    
    int best_fit_idx = -1
    int best_fit_waste = pool.total_bytes + 1
    
    i = 0
    for i < pool.block_count {
        if !pool.blocks[i].is_allocated && pool.blocks[i].size >= aligned_size {
            int waste = pool.blocks[i].size - aligned_size
            if waste < best_fit_waste {
                best_fit_waste = waste
                best_fit_idx = i
            }
        }
        i = i + 1
    }
    
    if best_fit_idx < 0 {
        return -3
    }
    
    memory_block best_block = pool.blocks[best_fit_idx]
    int alloc_address = best_block.address
    
    pool.blocks[best_fit_idx].is_allocated = true
    pool.blocks[best_fit_idx].size = aligned_size
    pool.blocks[best_fit_idx].owner_id = owner_id
    pool.blocks[best_fit_idx].timestamp = 0
    
    if best_block.size > aligned_size {

        i = pool.block_count
        while i > best_fit_idx + 1 {
            pool.blocks[i] = pool.blocks[i - 1]
            i = i - 1
        }
        
        pool.blocks[best_fit_idx + 1] = memory_block {
            address: alloc_address + aligned_size,
            size: best_block.size - aligned_size,
            is_allocated: false,
            allocation_order: 0,
            owner_id: "",
            timestamp: 0,
        }
        pool.block_count = pool.block_count + 1
    }
    
    pool.used_bytes = pool.used_bytes + aligned_size
    pool.free_bytes = pool.free_bytes - aligned_size
    pool.stats.used_bytes = pool.used_bytes
    pool.stats.free_bytes = pool.free_bytes
    pool.stats.allocated_blocks = pool.stats.allocated_blocks + 1
    
    if pool.used_bytes > pool.stats.peak_used_bytes {
        pool.stats.peak_used_bytes = pool.used_bytes
    }
    
    global_pools.pools[pool_idx] = pool
    
    return alloc_address
}

func pool_free(string pool_name, int address) int {

    int pool_idx = -1
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            pool_idx = i
        }
        i = i + 1
    }
    
    if pool_idx < 0 {
        return -1
    }
    
    memory_pool pool = global_pools.pools[pool_idx]
    
    int block_idx = -1
    i = 0
    for i < pool.block_count {
        if pool.blocks[i].address == address {
            block_idx = i
        }
        i = i + 1
    }
    
    if block_idx < 0 {
        return -2
    }
    
    memory_block block = pool.blocks[block_idx]
    
    if !block.is_allocated {
        return -3
    }
    
    pool.blocks[block_idx].is_allocated = false
    int freed_size = block.size
    pool.blocks[block_idx].owner_id = ""
    
    if block_idx + 1 < pool.block_count && !pool.blocks[block_idx + 1].is_allocated {
        pool.blocks[block_idx].size = pool.blocks[block_idx].size + pool.blocks[block_idx + 1].size
        
        i = block_idx + 1
        while i < pool.block_count - 1 {
            pool.blocks[i] = pool.blocks[i + 1]
            i = i + 1
        }
        pool.block_count = pool.block_count - 1
    }
    
    if block_idx > 0 && !pool.blocks[block_idx - 1].is_allocated {
        pool.blocks[block_idx - 1].size = pool.blocks[block_idx - 1].size + pool.blocks[block_idx].size
        
        i = block_idx
        while i < pool.block_count - 1 {
            pool.blocks[i] = pool.blocks[i + 1]
            i = i + 1
        }
        pool.block_count = pool.block_count - 1
    }
    
    pool.used_bytes = pool.used_bytes - freed_size
    pool.free_bytes = pool.free_bytes + freed_size
    pool.stats.used_bytes = pool.used_bytes
    pool.stats.free_bytes = pool.free_bytes
    pool.stats.allocated_blocks = pool.stats.allocated_blocks - 1
    
    global_pools.pools[pool_idx] = pool
    
    return 0
}

func pool_get_stats(string pool_name) pool_stats {
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            return global_pools.pools[i].stats
        }
        i = i + 1
    }
    return pool_stats {}
}

func pool_calc_fragmentation(string pool_name) int {

    int pool_idx = -1
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            pool_idx = i
        }
        i = i + 1
    }
    
    if pool_idx < 0 {
        return -1
    }
    
    memory_pool pool = global_pools.pools[pool_idx]
    
    int free_fragments = 0
    i = 0
    for i < pool.block_count {
        if !pool.blocks[i].is_allocated {
            free_fragments = free_fragments + 1
        }
        i = i + 1
    }
    
    if free_fragments == 0 {
        return 0
    }
    
    int ideal_fragments = 1
    if pool.free_bytes > 0 {
        int frag_percent = ((free_fragments - ideal_fragments) * 100) / (pool.total_bytes / 4096)
        if frag_percent > 100 { frag_percent = 100 }
        return frag_percent
    }
    
    return 0
}

func pool_defragment(string pool_name) int {

    int pool_idx = -1
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            pool_idx = i
        }
        i = i + 1
    }
    
    if pool_idx < 0 {
        return -1
    }
    
    return 0
}

func pool_dump_info(string pool_name) string {
    int pool_idx = -1
    int i = 0
    for i < global_pools.pool_count {
        if global_pools.pools[i].pool_name == pool_name {
            pool_idx = i
        }
        i = i + 1
    }
    
    if pool_idx < 0 {
        return "Pool not found: " + pool_name
    }
    
    memory_pool pool = global_pools.pools[pool_idx]
    
    string output = ""
    output = output + "Memory Pool: " + pool.pool_name + "\n"
    output = output + "  Total: " + string(pool.total_bytes / 1024 / 1024) + " MB\n"
    output = output + "  Used: " + string(pool.used_bytes / 1024 / 1024) + " MB\n"
    output = output + "  Free: " + string(pool.free_bytes / 1024 / 1024) + " MB\n"
    output = output + "  Utilization: " + string((pool.used_bytes * 100) / pool.total_bytes) + "%\n"
    output = output + "  Blocks: " + string(pool.block_count) + "\n"
    output = output + "  Allocated blocks: " + string(pool.stats.allocated_blocks) + "\n"
    output = output + "  Peak usage: " + string(pool.stats.peak_used_bytes / 1024 / 1024) + " MB\n"
    
    return output
}

func pool_list_all() []string {
    []string result = make([]string, 16)
    int i = 0
    for i < global_pools.pool_count {
        result[i] = global_pools.pools[i].pool_name
        i = i + 1
    }
    return result
}
