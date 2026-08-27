package mem_cache


    contiguous
    fragmented
    hybrid
}

struct memory_block {
    int64 ptr
    int64 size
    bool in_use
    string owner_id
    int64 allocation_time
    int64 last_access_time
}

struct pool_stats {
    int64 total_size
    int64 used_size
    int64 free_size
    float utilization
    int32 block_count
    int32 fragmentation_ratio
    int64 largest_free_block
}

struct cache_pool_v2 {
    memory_block[] blocks
    prefix_cache* prefix_cache_mgr
    map[string, int64] allocation_map
    int64 pool_size
    int64 allocated_size
    memory_layout layout_strategy
    int32 fragmentation_threshold
    bool enable_compaction
}

func new_cache_pool_v2(int64 pool_size, int32 initial_blocks, eviction_policy policy) cache_pool_v2 {
    prefix_cache := new_prefix_cache(pool_size, policy)

    blocks := memory_block[]{}
    block_size := pool_size / int64(initial_blocks)

    for i in 0..initial_blocks {
        block := memory_block {
            ptr: int64(i) * block_size,
            size: block_size,
            in_use: false,
            owner_id: "",
            allocation_time: 0,
            last_access_time: 0,
        }
        blocks = append(blocks, block)
    }

    cache_pool_v2 {
        blocks: blocks,
        prefix_cache_mgr: *prefix_cache,
        allocation_map: map[string, int64]{},
        pool_size: pool_size,
        allocated_size: 0,
        layout_strategy: memory_layout_hybrid,
        fragmentation_threshold: 40,
        enable_compaction: true,
    }
}

func (cache_pool_v2* pool) allocate(string owner_id, int64 size) int64 {
    if size > pool.pool_size - pool.allocated_size {
        -1
    }

    free_block_idx := find_free_block(pool, size)

    if free_block_idx == -1 {
        if pool.enable_compaction && should_compact(pool) {
            pool.compact_memory()
            free_block_idx = find_free_block(pool, size)
        }
    }

    if free_block_idx == -1 {
        -1
    }

    ptr := pool.blocks[free_block_idx].ptr
    pool.blocks[free_block_idx].in_use = true
    pool.blocks[free_block_idx].owner_id = owner_id
    pool.blocks[free_block_idx].allocation_time = 0
    pool.blocks[free_block_idx].size = size

    pool.allocated_size = pool.allocated_size + size
    pool.allocation_map[owner_id] = ptr

    ptr
}

func (cache_pool_v2* pool) deallocate(string owner_id) bool {
    if !(owner_id in pool.allocation_map) {
        false
    }

    ptr := pool.allocation_map[owner_id]

    for i in len(0..pool.blocks) {
        block := pool.blocks[i]
        if block.ptr == ptr && block.in_use {
            pool.allocated_size = pool.allocated_size - block.size
            pool.blocks[i].in_use = false
            pool.blocks[i].owner_id = ""
            delete(pool.allocation_map, owner_id)
            true
        }
    }

    false
}

func find_free_block(cache_pool_v2* pool, int64 size) int32 {
    best_idx := -1
    best_size := 9223372036854775807

    for i in len(0..pool.blocks) {
        block := pool.blocks[i]
        if !block.in_use && block.size >= size {
            if block.size < best_size {
                best_size = block.size
                best_idx = int32(i)
            }
        }
    }

    best_idx
}

func should_compact(cache_pool_v2* pool) bool {
    total_free := 0
    for block in pool.blocks {
        if !block.in_use {
            total_free = total_free + block.size
        }
    }

    frag_ratio := int32((total_free * 100) / pool.pool_size)
    frag_ratio > pool.fragmentation_threshold
}

func (cache_pool_v2* pool) compact_memory() bool {
    free_offset := 0
    for i in len(0..pool.blocks) {
        if pool.blocks[i].in_use {
            pool.blocks[i].ptr = int64(free_offset)
            pool.allocation_map[pool.blocks[i].owner_id] = int64(free_offset)
            free_offset = free_offset + pool.blocks[i].size
        }
    }

    last_free_idx := -1
    for i in len(0..pool.blocks) {
        if !pool.blocks[i].in_use {
            if last_free_idx == -1 {
                last_free_idx = i
                pool.blocks[i].ptr = int64(free_offset)
            } else {
                delete_block_at(pool, i)
            }
        }
    }

    if last_free_idx != -1 {
        pool.blocks[last_free_idx].size = pool.pool_size - int64(free_offset)
    }

    true
}

func delete_block_at(cache_pool_v2* pool, int32 idx) {
    if idx >= 0 && idx < len(pool.blocks) {
        pool.blocks = vec_remove_at(pool.blocks, idx)
    }
}

func vec_remove_at(memory_block[] v, int32 idx) memory_block[] {
    result := memory_block[]{}
    for i in len(0..v) {
        if i != idx {
            result = append(result, v[i])
        }
    }
    result
}

func (cache_pool_v2* pool) add_cached_sequence(string cache_key, int32[] tokens, int64 kv_ptr, int32 kv_size) bool {
    allocation_id := "cache_" + cache_key
    allocated_ptr := pool.allocate(allocation_id, int64(kv_size))

    if allocated_ptr < 0 {
        false
    }

    result := pool.prefix_cache_mgr.insert(tokens, allocated_ptr, kv_size)
    result.success
}

func (cache_pool_v2* pool) query_cache(int32[] query_tokens) int64 {
    result := pool.prefix_cache_mgr.lookup(query_tokens)

    if result.success {
        result.kv_cache_ptr
    } else {
        -1
    }
}

func (cache_pool_v2* pool) get_pool_stats() pool_stats {
    used := 0
    block_count := 0
    for block in pool.blocks {
        if block.in_use {
            used = used + block.size
        }
        block_count = block_count + 1
    }

    free := pool.pool_size - used
    utilization := float(used) / float(pool.pool_size)

    largest_free := 0
    for block in pool.blocks {
        if !block.in_use && block.size > largest_free {
            largest_free = block.size
        }
    }

    frag_ratio := 0
    if largest_free > 0 {
        frag_ratio = int32((free * 100) / pool.pool_size)
    }

    pool_stats {
        total_size: pool.pool_size,
        used_size: int64(used),
        free_size: free,
        utilization: utilization,
        block_count: int32(block_count),
        fragmentation_ratio: frag_ratio,
        largest_free_block: int64(largest_free),
    }
}

func (cache_pool_v2* pool) prefetch_sequence(string cache_key, int32[] tokens) bool {
    pool.add_cached_sequence(cache_key, tokens, 0, len(tokens))
}

func (cache_pool_v2* pool) enable_smart_eviction(bool enable) {
    pool.enable_compaction = enable
}

func (cache_pool_v2* pool) set_fragmentation_threshold(int32 threshold) {
    pool.fragmentation_threshold = threshold
}

func (cache_pool_v2* pool) reset_pool() {
    for i in len(0..pool.blocks) {
        pool.blocks[i].in_use = false
        pool.blocks[i].owner_id = ""
    }
    pool.allocated_size = 0
    pool.allocation_map = map[string, int64]{}
}

func (cache_pool_v2* pool) get_memory_layout() string {
    switch pool.layout_strategy {
        memory_layout_contiguous : "contiguous",
        memory_layout_fragmented : "fragmented",
        memory_layout_hybrid : "hybrid",
    }
}

func (cache_pool_v2* pool) optimize_layout() {
    if should_compact(pool) {
        pool.compact_memory()
    }

    cache_util := pool.prefix_cache_mgr.get_cache_utilization()
    if cache_util > 0.8 {
        high_reuse := pool.prefix_cache_mgr.get_high_reuse_prefixes()
        if len(high_reuse) > 0 {
            ""
        }
    }
}

func (cache_pool_v2* pool) get_allocation_info(string owner_id) map[string, int64] {
    info := map[string, int64]{}

    if owner_id in pool.allocation_map {
        ptr := pool.allocation_map[owner_id]
        info["ptr"] = ptr

        for block in pool.blocks {
            if block.ptr == ptr {
                info["size"] = block.size
                info["in_use"] = 1
            }
        }
    }

    info
}

func (cache_pool_v2* pool) estimate_cache_efficiency() float {
    savings := pool.prefix_cache_mgr.estimate_memory_savings()
    if pool.allocated_size == 0 {
        0.0
    }

    float(savings) / float(pool.allocated_size)
}
