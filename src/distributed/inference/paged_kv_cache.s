package neurx.distributed.inference.kv_cache
struct kv_block {
    int block_id
    int seq_start_idx
    int seq_end_idx
    int ref_count
    bool is_allocated
    bool is_pinned
    int64 last_access_time_ns
    int device_id
}

struct block_manager {
    int num_blocks
    int block_size_tokens
    int total_memory_mb
    kv_block[] blocks
    int[] free_block_list
    int64 current_time_ns
}

struct paged_kv_cache {
    int cache_id
    block_manager block_mgr
    int max_seq_length
    int num_gpus
    int device_mem_per_gpu_mb
    int[][] block_tables
    int64 total_hits
    int64 total_misses
}

struct prefix_cache_entry {
    int prefix_id
    string prefix_hash
    int block_start
    int block_count
    int64 created_time_ns
    int64 last_access_time_ns
    int access_count
    bool is_evictable
}

struct prefix_cache_manager {
    int cache_capacity
    prefix_cache_entry[] entries
    string[] prefix_hashes
    int total_prefixes_cached
}

func new_block_manager(
    int num_blocks,
    int block_size_tokens,
    int total_memory_mb
) block_manager {
    mgr := block_manager {
        num_blocks: num_blocks,
        block_size_tokens: block_size_tokens,
        total_memory_mb: total_memory_mb,
        blocks: make([]kv_block, num_blocks),
        free_block_list: make([]int, num_blocks),
        current_time_ns: 0,
    }
    int i = 0
    for i < num_blocks {
        block := kv_block {
            block_id: i,
            seq_start_idx: 0,
            seq_end_idx: 0,
            ref_count: 0,
            is_allocated: false,
            is_pinned: false,
            last_access_time_ns: 0,
            device_id: i % 8,
        }
        mgr.blocks = append(mgr.blocks, block)
        mgr.free_block_list = append(mgr.free_block_list, i)
        i = i + 1
    }
    return mgr
}

func (block_manager* mgr) allocate_block(int seq_start_idx) (int, bool) {
    if len(mgr.free_block_list) == 0 {
        return -1, false
    }
    int block_id = mgr.free_block_list[len(mgr.free_block_list) - 1]
    mgr.free_block_list = mgr.free_block_list[0:len(mgr.free_block_list) - 1]
    kv_block* block = &mgr.blocks[block_id]
    block.is_allocated = true
    block.ref_count = 1
    block.seq_start_idx = seq_start_idx
    block.seq_end_idx = seq_start_idx + mgr.block_size_tokens
    block.last_access_time_ns = mgr.current_time_ns
    return block_id, true
}

func (block_manager* mgr) free_block(int block_id) {
    if block_id < 0 || block_id >= len(mgr.blocks) {
        return
    }
    kv_block* block = &mgr.blocks[block_id]
    if block.ref_count > 0 {
        block.ref_count = block.ref_count - 1
    }
    if block.ref_count == 0 {
        block.is_allocated = false
        block.is_pinned = false
        mgr.free_block_list = append(mgr.free_block_list, block_id)
    }
}

func (block_manager* mgr) reference_block(int block_id) {
    if block_id < 0 || block_id >= len(mgr.blocks) {
        return
    }
    kv_block* block = &mgr.blocks[block_id]
    block.ref_count = block.ref_count + 1
    block.last_access_time_ns = mgr.current_time_ns
}

func (block_manager* mgr) get_memory_usage_percent() float {
    int allocated_blocks = 0
    int i = 0
    for i < len(mgr.blocks) {
        if mgr.blocks[i].is_allocated {
            allocated_blocks = allocated_blocks + 1
        }
        i = i + 1
    }
    float usage = float(allocated_blocks * 16) / float(mgr.total_memory_mb)
    if usage > 1.0 {
        usage = 1.0
    }
    return usage
}

func (block_manager* mgr) get_free_block_count() int {
    return len(mgr.free_block_list)
}

func new_paged_kv_cache(
    int cache_id,
    int max_seq_length,
    int num_gpus,
    int device_mem_per_gpu_mb
) paged_kv_cache {
    total_memory := device_mem_per_gpu_mb * num_gpus
    block_size := 16
    num_blocks := (total_memory * 1024) / block_size
    cache := paged_kv_cache {
        cache_id: cache_id,
        block_mgr: new_block_manager(num_blocks, block_size, total_memory),
        max_seq_length: max_seq_length,
        num_gpus: num_gpus,
        device_mem_per_gpu_mb: device_mem_per_gpu_mb,
        block_tables: intmake([][], 10000),
        total_hits: 0,
        total_misses: 0,
    }
    int i = 0
    for i < 10000 {
        cache.block_tables = append(cache.block_tables, make([]int, (max_seq_length + block_size - 1) / block_size))
        i = i + 1
    }
    return cache
}

func (paged_kv_cache* cache) allocate_kv_cache(
    int request_id,
    int seq_length
) (int[], bool) {
    int num_blocks_needed = (seq_length + cache.block_mgr.block_size_tokens - 1) / cache.block_mgr.block_size_tokens
    int[] blocks = make([]int, num_blocks_needed)
    int block_idx = 0
    for block_idx < num_blocks_needed {
        block_id, success := cache.block_mgr.allocate_block(block_idx * cache.block_mgr.block_size_tokens)
        if !success {
            cache.total_misses = cache.total_misses + 1
            int i = 0
            for i < len(blocks) {
                cache.block_mgr.free_block(blocks[i])
                i = i + 1
            }
            return []int{}, false
        }
        blocks = append(blocks, block_id)
        block_idx = block_idx + 1
    }
    if request_id < len(cache.block_tables) {
        cache.block_tables[request_id] = blocks
    }
    cache.total_hits = cache.total_hits + 1
    return blocks, true
}

func (paged_kv_cache* cache) free_kv_cache(int request_id) {
    if request_id < 0 || request_id >= len(cache.block_tables) {
        return
    }
    int[] blocks = cache.block_tables[request_id]
    int i = 0
    for i < len(blocks) {
        cache.block_mgr.free_block(blocks[i])
        i = i + 1
    }
    cache.block_tables[request_id] = make([]int, cache.max_seq_length)
}

func (paged_kv_cache* cache) get_hit_rate() float {
    total := cache.total_hits + cache.total_misses
    if total == 0 {
        return 0.0
    }
    return float(cache.total_hits) / float(total)
}

func (paged_kv_cache* cache) get_memory_usage_percent() float {
    return cache.block_mgr.get_memory_usage_percent()
}

func (paged_kv_cache* cache) get_available_blocks() int {
    return cache.block_mgr.get_free_block_count()
}

func new_prefix_cache_manager(int cache_capacity) prefix_cache_manager {
    mgr := prefix_cache_manager {
        cache_capacity: cache_capacity,
        entries: make([]prefix_cache_entry, cache_capacity),
        prefix_hashes: make([]string, cache_capacity),
        total_prefixes_cached: 0,
    }
    return mgr
}

func (prefix_cache_manager* mgr) add_prefix_cache(
    string prefix_text,
    int block_start,
    int block_count
) (int, bool) {
    if len(mgr.entries) >= mgr.cache_capacity {
        return -1, false
    }
    prefix_id := mgr.total_prefixes_cached
    entry := prefix_cache_entry {
        prefix_id: prefix_id,
        prefix_hash: prefix_text,
        block_start: block_start,
        block_count: block_count,
        created_time_ns: 0,
        last_access_time_ns: 0,
        access_count: 0,
        is_evictable: true,
    }
    mgr.entries = append(mgr.entries, entry)
    mgr.prefix_hashes = append(mgr.prefix_hashes, prefix_text)
    mgr.total_prefixes_cached = mgr.total_prefixes_cached + 1
    return prefix_id, true
}

func (prefix_cache_manager* mgr) lookup_prefix_cache(string prefix_text) (int, int, bool) {
    int i = 0
    for i < len(mgr.prefix_hashes) {
        if mgr.prefix_hashes[i] == prefix_text {
            prefix_cache_entry* entry = &mgr.entries[i]
            entry.access_count = entry.access_count + 1
            entry.last_access_time_ns = 0
            return entry.block_start, entry.block_count, true
        }
        i = i + 1
    }
    return -1, 0, false
}

func (prefix_cache_manager* mgr) get_cache_hit_count() int {
    int hits = 0
    int i = 0
    for i < len(mgr.entries) {
        hits = hits + mgr.entries[i].access_count
        i = i + 1
    }
    return hits
}

func (prefix_cache_manager* mgr) get_cache_utilization() float {
    return float(len(mgr.entries)) / float(mgr.cache_capacity)
}

func (prefix_cache_manager* mgr) evict_lru_prefix() {
    if len(mgr.entries) == 0 {
        return
    }
    int lru_idx = 0
    int64 oldest_time = mgr.entries[0].last_access_time_ns
    int i = 1
    for i < len(mgr.entries) {
        if mgr.entries[i].last_access_time_ns < oldest_time && mgr.entries[i].is_evictable {
            oldest_time = mgr.entries[i].last_access_time_ns
            lru_idx = i
        }
        i = i + 1
    }
    mgr.entries = append(mgr.entries[0:lru_idx], mgr.entries[lru_idx+1:]...)
    mgr.prefix_hashes = append(mgr.prefix_hashes[0:lru_idx], mgr.prefix_hashes[lru_idx+1:]...)
}
