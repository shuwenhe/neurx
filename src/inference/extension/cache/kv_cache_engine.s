struct cache_memory_pool {
    []kv_cache_block blocks
    int num_blocks
    int max_blocks
    int64 total_memory_bytes
    int64 used_memory_bytes
}

struct kv_cache_engine {
    cache_memory_pool memory_pool
    cache_index index
    int hidden_dim
    int num_layers
    int64 current_time_ms
    int64 total_hits
    int64 total_misses
}

func create_kv_cache_engine(int max_blocks, int hidden_dim_val, int num_layers_val, int max_cache_entries) kv_cache_engine {
    kv_cache_engine engine = kv_cache_engine{}
    engine.hidden_dim = hidden_dim_val
    engine.num_layers = num_layers_val
    engine.current_time_ms = 0
    engine.total_hits = 0
    engine.total_misses = 0
    engine.memory_pool.max_blocks = max_blocks
    engine.memory_pool.num_blocks = 0
    engine.memory_pool.total_memory_bytes = int64(max_blocks * hidden_dim_val * 2 * 4 * 100)
    engine.memory_pool.used_memory_bytes = 0
    engine.memory_pool.blocks = make([]kv_cache_block, max_blocks)
    engine.index = create_cache_index(max_cache_entries)
    print("[KVCacheEngine] Initialized: max_blocks=" + int_to_string(max_blocks) + ", hidden_dim=" + int_to_string(hidden_dim_val) + ", layers=" + int_to_string(num_layers_val) + "\n")
    return engine
}

func kv_cache_engine_allocate_block(kv_cache_engine engine, int layer_id, int token_count) int {
    if engine.memory_pool.num_blocks >= engine.memory_pool.max_blocks {
        print("[KVCacheEngine] Memory pool full, cannot allocate block\n")
        return -1
    }
    kv_cache_block block = create_kv_cache_block(engine.memory_pool.num_blocks, layer_id, token_count, engine.hidden_dim)
    int64 block_size = cache_block_size_bytes(block)
    if engine.memory_pool.used_memory_bytes + block_size > engine.memory_pool.total_memory_bytes {
        print("[KVCacheEngine] Insufficient memory, evicting LRU entries\n")
        return -1
    }
    engine.memory_pool.blocks[engine.memory_pool.num_blocks] = block
    int block_id = engine.memory_pool.num_blocks
    engine.memory_pool.num_blocks = engine.memory_pool.num_blocks + 1
    engine.memory_pool.used_memory_bytes = engine.memory_pool.used_memory_bytes + block_size
    print("[KVCacheEngine] Allocated block " + int_to_string(block_id) + ", memory usage: " + int_to_string(engine.memory_pool.used_memory_bytes) + "/" + int_to_string(engine.memory_pool.total_memory_bytes) + "\n")
    return block_id
}

func kv_cache_engine_get_block(kv_cache_engine engine, int block_id) kv_cache_block {
    if block_id < 0 || block_id >= engine.memory_pool.num_blocks {
        print("[KVCacheEngine] Invalid block_id: " + int_to_string(block_id) + "\n")
        return kv_cache_block{}
    }
    kv_cache_block block = engine.memory_pool.blocks[block_id]
    cache_block_increment_hits(block)
    cache_block_update_timestamp(block, engine.current_time_ms)
    engine.memory_pool.blocks[block_id] = block
    return block
}

func kv_cache_engine_store_kv(kv_cache_engine engine, int[] prompt_tokens, float[] kv_data, int layer_id) int {
    string prefix_hash = compute_prefix_hash(prompt_tokens, 100)
    int cached_block_id = kv_cache_engine_allocate_block(engine, layer_id, len(prompt_tokens))
    if cached_block_id < 0 {
        print("[KVCacheEngine] Failed to allocate block for layer " + int_to_string(layer_id) + "\n")
        return -1
    }
    kv_cache_block block = engine.memory_pool.blocks[cached_block_id]
    block.kv_data = kv_data
    engine.memory_pool.blocks[cached_block_id] = block
    int[] block_ids = make([]int, 1)
    block_ids[0] = cached_block_id
    cache_index_store_blocks(engine.index, prefix_hash, block_ids)
    print("[KVCacheEngine] Stored KV for prefix " + prefix_hash + " in block " + int_to_string(cached_block_id) + "\n")
    return cached_block_id
}

func kv_cache_engine_query_kv(kv_cache_engine engine, int[] prompt_tokens) []int {
    string prefix_hash = compute_prefix_hash(prompt_tokens, 100)
    int[] cached_blocks = cache_index_get_blocks(engine.index, prefix_hash)
    if len(cached_blocks) == 0 {
        engine.total_misses = engine.total_misses + 1
        print("[KVCacheEngine] Cache miss for prefix " + prefix_hash + "\n")
        return []int{}
    }
    engine.total_hits = engine.total_hits + 1
    print("[KVCacheEngine] Cache hit! Found " + int_to_string(len(cached_blocks)) + " blocks\n")
    return cached_blocks
}

func kv_cache_engine_get_hit_rate(kv_cache_engine engine) float {
    if engine.total_hits + engine.total_misses == 0 {
        return 0.0
    }
    float hit_count = float(engine.total_hits)
    float total_count = float(engine.total_hits + engine.total_misses)
    float hit_rate = hit_count / total_count
    return hit_rate
}

func kv_cache_engine_get_memory_usage_percent(kv_cache_engine engine) int {
    if engine.memory_pool.total_memory_bytes == 0 {
        return 0
    }
    int percent = int(engine.memory_pool.used_memory_bytes * 100 / engine.memory_pool.total_memory_bytes)
    return percent
}

func kv_cache_engine_evict_lru_block(kv_cache_engine engine) int {
    if engine.memory_pool.num_blocks == 0 {
        return -1
    }
    int lru_block_idx = 0
    int64 oldest_time = engine.memory_pool.blocks[0].timestamp
    int i = 1
    for i < engine.memory_pool.num_blocks {
        if engine.memory_pool.blocks[i].timestamp < oldest_time {
            oldest_time = engine.memory_pool.blocks[i].timestamp
            lru_block_idx = i
        }
        i = i + 1
    }
    kv_cache_block evicted_block = engine.memory_pool.blocks[lru_block_idx]
    engine.memory_pool.used_memory_bytes = engine.memory_pool.used_memory_bytes - cache_block_size_bytes(evicted_block)
    i = lru_block_idx
    for i < engine.memory_pool.num_blocks - 1 {
        engine.memory_pool.blocks[i] = engine.memory_pool.blocks[i + 1]
        i = i + 1
    }
    engine.memory_pool.num_blocks = engine.memory_pool.num_blocks - 1
    print("[KVCacheEngine] Evicted LRU block, memory usage: " + int_to_string(engine.memory_pool.used_memory_bytes) + "\n")
    return lru_block_idx
}

func kv_cache_engine_get_stats(kv_cache_engine engine) string {
    float hit_rate = kv_cache_engine_get_hit_rate(engine)
    int memory_percent = kv_cache_engine_get_memory_usage_percent(engine)
    string stats = "[KVCacheEngine Stats] Blocks=" + int_to_string(engine.memory_pool.num_blocks) + "/" + int_to_string(engine.memory_pool.max_blocks) + 
                   ", Hits=" + int_to_string(engine.total_hits) + ", Misses=" + int_to_string(engine.total_misses) +
                   ", HitRate=" + int_to_string(int(hit_rate * 100)) + "%" +
                   ", Memory=" + int_to_string(memory_percent) + "%"
    return stats
}

func kv_cache_engine_tick(kv_cache_engine engine, int64 time_increment_ms) {
    engine.current_time_ms = engine.current_time_ms + time_increment_ms
    cache_index_update_time(engine.index, engine.current_time_ms)
}

func kv_cache_engine_clear(kv_cache_engine engine) {
    engine.memory_pool.num_blocks = 0
    engine.memory_pool.used_memory_bytes = 0
    cache_index_clear(engine.index)
    print("[KVCacheEngine] Cleared all caches\n")
}
