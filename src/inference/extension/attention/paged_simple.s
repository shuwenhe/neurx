package neurx.attention.paged_simple

struct cache_stats {
    int total_blocks
    int allocated_blocks
    int freed_blocks
    int evictions
    int cache_hits
    int cache_misses
}

func new_cache_stats(int total) cache_stats {
    cache_stats stats
    stats.total_blocks = total
    stats.allocated_blocks = 0
    stats.freed_blocks = 0
    stats.evictions = 0
    stats.cache_hits = 0
    stats.cache_misses = 0
    return stats
}

func allocate_kv_blocks_impl(int block_size, int num_tokens, int currently_allocated) int[] {
    int blocks_needed
    blocks_needed = (num_tokens + block_size - 1) / block_size
    int[] block_ids = []
    int i
    i = 0
    for i < blocks_needed {
        block_ids = append(block_ids, i)
        i = i + 1
    }
    return block_ids
}

func allocate_kv_blocks_needed(int block_size, int num_tokens) int {
    int blocks_needed
    blocks_needed = (num_tokens + block_size - 1) / block_size
    return blocks_needed
}

func free_kv_blocks(int currently_allocated, int num_blocks) int {
    int result
    result = currently_allocated - num_blocks
    if result < 0 {
        result = 0
    }
    return result
}

func copy_kv_blocks(int[] src_blocks, int[] dst_blocks) int {
    int min_len
    min_len = len(src_blocks)
    if len(dst_blocks) < min_len {
        min_len = len(dst_blocks)
    }
    return min_len
}

func get_cache_utilization(int allocated, int total) float {
    if total <= 0 {
        return 0.0
    }
    return float(allocated) / float(total)
}

func can_allocate(int available, int needed) bool {
    return available >= needed
}

func update_allocation_stats(cache_stats stats, int blocks_allocated, int new_evictions) cache_stats {
    stats.allocated_blocks = stats.allocated_blocks + blocks_allocated
    stats.evictions = stats.evictions + new_evictions
    return stats
}

func update_free_stats(cache_stats stats, int blocks_freed) cache_stats {
    stats.freed_blocks = stats.freed_blocks + blocks_freed
    return stats
}

func record_cache_hit(cache_stats stats) cache_stats {
    stats.cache_hits = stats.cache_hits + 1
    return stats
}

func record_cache_miss(cache_stats stats) cache_stats {
    stats.cache_misses = stats.cache_misses + 1
    return stats
}

func format_cache_stats(cache_stats stats) string {
    string result
    result = "PagedAttention Cache Stats:\n"
    result = result + "  Total Blocks: " + string(stats.total_blocks) + "\n"
    result = result + "  Allocated: " + string(stats.allocated_blocks) + "\n"
    result = result + "  Freed: " + string(stats.freed_blocks) + "\n"
    result = result + "  Evictions: " + string(stats.evictions) + "\n"
    result = result + "  Cache Hits: " + string(stats.cache_hits) + "\n"
    result = result + "  Cache Misses: " + string(stats.cache_misses) + "\n"
    return result
}

func reset_cache_stats(cache_stats stats) cache_stats {
    stats.cache_hits = 0
    stats.cache_misses = 0
    stats.evictions = 0
    return stats
}
