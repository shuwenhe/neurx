kv_cache_engine g_kv_cache_engine = kv_cache_engine{}
int g_cache_enabled = 0
int g_cache_initialized = 0

func init_kv_cache_system(int max_blocks, int hidden_dim, int num_layers, int max_entries) int {
    if g_cache_initialized == 1 {
        print("[KVCacheSystem] Cache already initialized\n")
        return 1
    }
    
    g_kv_cache_engine = create_kv_cache_engine(max_blocks, hidden_dim, num_layers, max_entries)
    g_cache_enabled = 1
    g_cache_initialized = 1
    
    print("[KVCacheSystem] Initialized: max_blocks=" + int_to_string(max_blocks) + ", hidden_dim=" + int_to_string(hidden_dim) + ", max_entries=" + int_to_string(max_entries) + "\n")
    return 1
}

func kv_cache_try_get_cached_blocks(int[] prompt_tokens) int[] {
    if g_cache_enabled == 0 {
        return int[]{cap: 0}
    }
    
    return kv_cache_engine_query_kv(g_kv_cache_engine, prompt_tokens)
}

func kv_cache_store_blocks(int[] prompt_tokens, float[] kv_data, int layer_id) int {
    if g_cache_enabled == 0 {
        return -1
    }
    
    return kv_cache_engine_store_kv(g_kv_cache_engine, prompt_tokens, kv_data, layer_id)
}

func kv_cache_get_block(int block_id) kv_cache_block {
    if g_cache_enabled == 0 {
        return kv_cache_block{}
    }
    
    return kv_cache_engine_get_block(g_kv_cache_engine, block_id)
}

func kv_cache_tick(int64 time_ms) {
    if g_cache_enabled == 0 {
        return
    }
    
    kv_cache_engine_tick(g_kv_cache_engine, time_ms)
}

func kv_cache_get_hit_rate() float {
    if g_cache_enabled == 0 {
        return 0.0
    }
    
    return kv_cache_engine_get_hit_rate(g_kv_cache_engine)
}

func kv_cache_get_stats() string {
    if g_cache_enabled == 0 {
        return "[KVCacheSystem] Cache disabled"
    }
    
    return kv_cache_engine_get_stats(g_kv_cache_engine)
}

func kv_cache_disable() {
    g_cache_enabled = 0
    print("[KVCacheSystem] Cache disabled\n")
}

func kv_cache_enable() {
    if g_cache_initialized == 0 {
        print("[KVCacheSystem] Cannot enable: cache not initialized\n")
        return
    }
    
    g_cache_enabled = 1
    print("[KVCacheSystem] Cache enabled\n")
}

func kv_cache_clear() {
    if g_cache_enabled == 0 {
        return
    }
    
    kv_cache_engine_clear(g_kv_cache_engine)
}

func should_use_cached_kv(int[] cached_block_ids) int {
    if len(cached_block_ids) > 0 {
        return 1
    }
    return 0
}

func get_cache_efficiency_report() string {
    string report = ""
    
    if g_cache_enabled == 0 {
        report = "[Cache Report] Cache disabled\n"
        return report
    }
    
    float hit_rate = kv_cache_get_hit_rate()
    int memory_percent = kv_cache_engine_get_memory_usage_percent(g_kv_cache_engine)
    int total_reqs = g_kv_cache_engine.total_hits + g_kv_cache_engine.total_misses
    
    report = "\n=== KV Cache Efficiency Report ===\n"
    report = report + "Total Requests: " + int_to_string(total_reqs) + "\n"
    report = report + "Cache Hits: " + int_to_string(g_kv_cache_engine.total_hits) + "\n"
    report = report + "Cache Misses: " + int_to_string(g_kv_cache_engine.total_misses) + "\n"
    report = report + "Hit Rate: " + int_to_string(int(hit_rate * 100)) + "%\n"
    report = report + "Memory Usage: " + int_to_string(memory_percent) + "%\n"
    report = report + "Active Blocks: " + int_to_string(g_kv_cache_engine.memory_pool.num_blocks) + "/" + int_to_string(g_kv_cache_engine.memory_pool.max_blocks) + "\n"
    report = report + "Cached Prefixes: " + int_to_string(g_kv_cache_engine.index.num_entries) + "\n"
    report = report + "=================================\n"
    
    return report
}
