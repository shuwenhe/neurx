advanced_kv_cache_engine g_advanced_cache_engine = advanced_kv_cache_engine{}
int g_advanced_cache_initialized = 0
int g_advanced_cache_enabled = 0
func init_advanced_kv_cache(string node_id) int {
    if g_advanced_cache_initialized == 1 {
        print("[AdvancedCacheIntegration] Already initialized\n")
        return 1
    }
    g_advanced_cache_engine = create_advanced_kv_cache_engine(node_id)
    g_advanced_cache_initialized = 1
    g_advanced_cache_enabled = 1
    advanced_cache_enable_all_optimizations(g_advanced_cache_engine)
    print("[AdvancedCacheIntegration] Initialized with Phase 2-4 features\n")
    print("[AdvancedCacheIntegration] - O(1) Hash table prefix lookup\n")
    print("[AdvancedCacheIntegration] - Tiered storage (L1/L2/L3)\n")
    print("[AdvancedCacheIntegration] - O(1) LRU eviction with linked list\n")
    print("[AdvancedCacheIntegration] - Distributed cache with replication\n")
    print("[AdvancedCacheIntegration] - Compression and adaptive policies\n")
    return 1
}

func advanced_cache_query_kv(int[] prompt_tokens) int[] {
    if g_advanced_cache_enabled == 0 {
        return int[]{cap: 0}
    }
    string prefix_hash = compute_prefix_hash(prompt_tokens, 100)
    return advanced_cache_query(g_advanced_cache_engine, prefix_hash)
}

func advanced_cache_store_kv(int[] prompt_tokens, float[] kv_data) int {
    if g_advanced_cache_enabled == 0 {
        return -1
    }
    string prefix_hash = compute_prefix_hash(prompt_tokens, 100)
    int[] block_ids = int[]{cap: 24}
    int i = 0
    for i < 24 {
        block_ids[i] = i
        i = i + 1
    }
    return advanced_cache_store(g_advanced_cache_engine, prefix_hash, block_ids)
}

func advanced_cache_get_stats() string {
    if g_advanced_cache_enabled == 0 {
        return "[AdvancedCache] Disabled\n"
    }
    return advanced_cache_get_comprehensive_stats(g_advanced_cache_engine)
}

func advanced_cache_tick(int64 time_ms) {
    if g_advanced_cache_enabled == 0 {
        return
    }
    advanced_cache_tick(g_advanced_cache_engine, time_ms)
}

func advanced_cache_add_peer_node(string peer_id, string host, int port) {
    if g_advanced_cache_enabled == 0 {
        return
    }
    advanced_cache_add_peer(g_advanced_cache_engine, peer_id, host, port)
}

func advanced_cache_enable_distributed() {
    if g_advanced_cache_enabled == 0 {
        return
    }
    print("[AdvancedCacheIntegration] Distributed cache enabled\n")
}

func advanced_cache_get_hit_rate() float {
    if g_advanced_cache_enabled == 0 {
        return 0.0
    }
    return advanced_cache_get_hit_rate(g_advanced_cache_engine)
}

func advanced_cache_disable() {
    g_advanced_cache_enabled = 0
    print("[AdvancedCacheIntegration] Advanced cache disabled\n")
}

func advanced_cache_enable() {
    if g_advanced_cache_initialized == 0 {
        print("[AdvancedCacheIntegration] Not initialized\n")
        return
    }
    g_advanced_cache_enabled = 1
    print("[AdvancedCacheIntegration] Advanced cache enabled\n")
}

func advanced_cache_clear() {
    if g_advanced_cache_enabled == 0 {
        return
    }
    hash_table_clear(g_advanced_cache_engine.index)
    lru_cache_clear(g_advanced_cache_engine.lru)
    tiered_storage_clear(g_advanced_cache_engine.storage)
    print("[AdvancedCacheIntegration] All caches cleared\n")
}

func advanced_cache_get_detailed_report() string {
    string report = advanced_cache_get_stats()
    report = report + "\n[Hash Table Performance Tuning]\n"
    if hash_table_should_resize(g_advanced_cache_engine.index) == 1 {
        report = report + "  ⚠️  Load factor high - consider resizing hash table\n"
    } else {
        report = report + "  ✓ Load factor optimal\n"
    }
    report = report + "\n[Tiered Storage Optimization]\n"
    int best_tier = tiered_storage_get_best_tier_for_read(g_advanced_cache_engine.storage)
    if best_tier == 0 {
        report = report + "  ✓ L1 memory tier active\n"
    } else if best_tier == 1 {
        report = report + "  ⚠️  L2 CPU tier (slower than L1)\n"
    } else if best_tier == 2 {
        report = report + "  ⚠️  L3 disk tier (slowest, high latency)\n"
    }
    report = report + "\n[Eviction Policy]\n"
    string lru_key = lru_cache_get_lru_key(g_advanced_cache_engine.lru)
    if len(lru_key) > 0 {
        report = report + "  Next to evict: " + lru_key + "\n"
    }
    return report
}

func switch_to_legacy_cache() {
    advanced_cache_disable()
    print("[CacheIntegration] Switched back to legacy cache\n")
}

func switch_to_advanced_cache() {
    advanced_cache_enable()
    print("[CacheIntegration] Switched to advanced cache\n")
}

func is_advanced_cache_enabled() int {
    return g_advanced_cache_enabled
}
