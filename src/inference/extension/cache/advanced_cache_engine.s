struct advanced_kv_cache_engine {
    hash_table index
    tiered_storage storage
    lru_cache lru
    distributed_cache peers
    performance_cache optimization
    int64 total_hits
    int64 total_misses
    int64 total_reads
    int64 total_writes
    int64 current_time_ms
}

func create_advanced_kv_cache_engine(string node_id) advanced_kv_cache_engine {
    advanced_kv_cache_engine engine = advanced_kv_cache_engine{}
    engine.index = create_hash_table(256, 4096)
    engine.storage = create_tiered_storage()
    add_storage_tier(engine.storage, "L1_MEMORY", 500, 2000)
    add_storage_tier(engine.storage, "L2_CPU", 2000, 5000)
    add_storage_tier(engine.storage, "L3_DISK", 5000, 10000)
    engine.lru = create_lru_cache(2000)
    engine.peers = create_distributed_cache(node_id, 3, 2)
    engine.optimization = create_performance_cache()
    engine.total_hits = 0
    engine.total_misses = 0
    engine.total_reads = 0
    engine.total_writes = 0
    engine.current_time_ms = 0
    print("[AdvancedKVCacheEngine] Initialized node: " + node_id + "\n")
    return engine
}

func advanced_cache_query(advanced_kv_cache_engine engine, string prefix_hash) []int {
    engine.total_reads = engine.total_reads + 1
    []int cached_blocks = hash_table_lookup(engine.index, prefix_hash)
    if len(cached_blocks) > 0 {
        engine.total_hits = engine.total_hits + 1
        int block_id = cached_blocks[0]
        int lru_block = lru_cache_get(engine.lru, prefix_hash)
        int best_tier = tiered_storage_get_best_tier_for_read(engine.storage)
        if best_tier >= 0 {
            tiered_storage_record_hit(engine.storage, best_tier)
        }
        print("[AdvancedCache] HIT: " + prefix_hash + ", blocks=" + int_to_string(len(cached_blocks)) + "\n")
        return cached_blocks
    }
    engine.total_misses = engine.total_misses + 1
    int best_tier = tiered_storage_get_best_tier_for_read(engine.storage)
    if best_tier >= 0 {
        tiered_storage_record_miss(engine.storage, best_tier)
    }
    []int replicas = distributed_cache_compute_replica_nodes(engine.peers, prefix_hash)
    if len(replicas) > 0 {
        string best_node = distributed_cache_find_best_replica_node(engine.peers, replicas)
        print("[AdvancedCache] MISS locally, querying replicas: " + best_node + "\n")
    }
    print("[AdvancedCache] MISS: " + prefix_hash + "\n")
    return []int{}
}

func advanced_cache_store(advanced_kv_cache_engine engine, string prefix_hash, []int block_ids) int {
    engine.total_writes = engine.total_writes + 1
    hash_table_insert(engine.index, prefix_hash, block_ids)
    lru_cache_put(engine.lru, prefix_hash, block_ids[0])
    int64 block_size = 7200
    if compression_should_compress(engine.optimization, block_size) == 1 {
        int64 compressed = compression_apply(engine.optimization, block_size)
        block_size = compressed
    }
    int best_tier = tiered_storage_find_space(engine.storage, block_size)
    if best_tier >= 0 {
        tiered_storage_allocate(engine.storage, best_tier, block_size)
        print("[AdvancedCache] Stored in tier: " + int_to_string(best_tier) + "\n")
    } else {
        print("[AdvancedCache] No space available, attempting eviction\n")
        string lru_key = lru_cache_get_lru_key(engine.lru)
        if len(lru_key) > 0 {
            lru_cache_remove(engine.lru, lru_key)
            hash_table_remove(engine.index, lru_key)
            tiered_storage_evict(engine.storage, 0)
            best_tier = tiered_storage_find_space(engine.storage, block_size)
            if best_tier >= 0 {
                tiered_storage_allocate(engine.storage, best_tier, block_size)
            }
        }
    }
    []string replicas = distributed_cache_compute_replica_nodes(engine.peers, prefix_hash)
    if len(replicas) > 0 {
        print("[AdvancedCache] Replicating to " + int_to_string(len(replicas)) + " nodes\n")
    }
    return 1
}

func advanced_cache_get_hit_rate(advanced_kv_cache_engine engine) float {
    if engine.total_reads == 0 {
        return 0.0
    }
    float hit_rate = float(engine.total_hits) / float(engine.total_reads)
    return hit_rate
}

func advanced_cache_get_tier_utilization(advanced_kv_cache_engine engine) string {
    return tiered_storage_get_stats(engine.storage)
}

func advanced_cache_add_peer(advanced_kv_cache_engine engine, string peer_id, string host, int port) {
    distributed_cache_add_peer(engine.peers, peer_id, host, port)
}

func advanced_cache_promote_block(advanced_kv_cache_engine engine, string key, int from_tier, int to_tier) {
    int64 block_size = 7200
    if tiered_storage_promote(engine.storage, from_tier, to_tier, block_size) == 1 {
        print("[AdvancedCache] Promoted " + key + " from tier " + int_to_string(from_tier) + 
              " to tier " + int_to_string(to_tier) + "\n")
    }
}

func advanced_cache_enable_compression(advanced_kv_cache_engine engine) {
    enable_compression(engine.optimization, 1)
}

func advanced_cache_enable_warmup(advanced_kv_cache_engine engine) {
    enable_warmup(engine.optimization, 1)
}

func advanced_cache_tick(advanced_kv_cache_engine engine, int64 time_increment_ms) {
    engine.current_time_ms = engine.current_time_ms + time_increment_ms
    hash_table_update_time(engine.index, engine.current_time_ms)
    lru_cache_update_time(engine.lru, engine.current_time_ms)
    distributed_cache_tick(engine.peers, time_increment_ms)
    performance_cache_tick(engine.optimization, time_increment_ms)
    if engine.current_time_ms % 10000 == 0 {
        distributed_cache_check_peer_health(engine.peers)
    }
}

func advanced_cache_get_comprehensive_stats(advanced_kv_cache_engine engine) string {
    float hit_rate = advanced_cache_get_hit_rate(engine)
    string stats = "\n╔════════════════════════════════════════════════════╗\n"
    stats = stats + "║         Advanced KV Cache Engine - Phase 2-4       ║\n"
    stats = stats + "╚════════════════════════════════════════════════════╝\n"
    stats = stats + "\n[Performance Metrics]\n"
    stats = stats + "  Total Reads: " + int_to_string(engine.total_reads) + "\n"
    stats = stats + "  Total Writes: " + int_to_string(engine.total_writes) + "\n"
    stats = stats + "  Cache Hits: " + int_to_string(engine.total_hits) + "\n"
    stats = stats + "  Cache Misses: " + int_to_string(engine.total_misses) + "\n"
    stats = stats + "  Hit Rate: " + int_to_string(int(hit_rate * 100)) + "%\n"
    stats = stats + "\n[Hash Table Performance]\n"
    stats = stats + hash_table_get_stats(engine.index) + "\n"
    stats = stats + "\n[Tiered Storage]\n"
    stats = stats + advanced_cache_get_tier_utilization(engine)
    stats = stats + "\n[LRU Linked List]\n"
    stats = stats + lru_cache_get_stats(engine.lru) + "\n"
    stats = stats + "\n[Distributed Cache]\n"
    stats = stats + distributed_cache_get_stats(engine.peers) + "\n"
    stats = stats + "\n[Optimizations]\n"
    stats = stats + performance_cache_get_comprehensive_stats(engine.optimization)
    return stats
}

func advanced_cache_enable_all_optimizations(advanced_kv_cache_engine engine) {
    advanced_cache_enable_compression(engine)
    advanced_cache_enable_warmup(engine)
    set_adaptive_level(engine.optimization, 3)
    print("[AdvancedCache] All optimizations enabled\n")
}

func advanced_cache_get_effective_cache_size(advanced_kv_cache_engine engine) int64 {
    int64 l1_size = engine.storage.tiers[0].capacity_bytes
    int64 l2_size = engine.storage.tiers[1].capacity_bytes
    int64 total = l1_size + l2_size
    return total
}
