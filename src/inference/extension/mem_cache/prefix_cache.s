package mem_cache

    lru
    lfu
    lru_with_time_decay
    two_tier
}

struct cache_entry {
    int32[] token_sequence
    int64 kv_cache_ptr
    int32 kv_cache_size
    int32 access_count
    int64 last_access_time
    int64 creation_time
    string entry_id
}

struct prefix_cache {
    radix_tree* tree
    map[string, cache_entry] entries
    eviction_policy policy
    int64 max_cache_size
    int64 current_cache_size
    int32 hit_count
    int32 miss_count
    int32 eviction_count
    int64 creation_timestamp
}

struct cache_stats {
    int32 hit_count
    int32 miss_count
    int32 eviction_count
    int64 cache_size
    int32 cache_entries
    int64 total_tokens_cached
    float hit_rate
    int32 compression_ratio
}

struct cache_operation_result {
    bool success
    string cache_key
    int64 kv_cache_ptr
    int32 kv_cache_size
    string message
}

func new_prefix_cache(int64 max_size, eviction_policy policy) prefix_cache {
    tree := new_radix_tree()

    prefix_cache {
        tree: *tree,
        entries: map[string, cache_entry]{},
        policy: policy,
        max_cache_size: max_size,
        current_cache_size: 0,
        hit_count: 0,
        miss_count: 0,
        eviction_count: 0,
        creation_timestamp: 0,
    }
}

func (prefix_cache* cache) insert(int32[] token_sequence, int64 kv_cache_ptr, int32 kv_cache_size) cache_operation_result {
    if len(token_sequence) == 0 {
        cache_operation_result {
            success: false,
            cache_key: "",
            kv_cache_ptr: 0,
            kv_cache_size: 0,
            message: "empty token sequence",
        }
    }

    new_size := cache.current_cache_size + kv_cache_size
    if new_size > cache.max_cache_size {
        cache.evict_entries(new_size - cache.max_cache_size)
    }

    cache_key := cache.tree.insert_sequence(token_sequence, kv_cache_ptr, kv_cache_size)

    entry := cache_entry {
        token_sequence: token_sequence,
        kv_cache_ptr: kv_cache_ptr,
        kv_cache_size: kv_cache_size,
        access_count: 1,
        last_access_time: 0,
        creation_time: 0,
        entry_id: cache_key,
    }

    cache.entries[cache_key] = entry
    cache.current_cache_size = cache.current_cache_size + kv_cache_size

    cache_operation_result {
        success: true,
        cache_key: cache_key,
        kv_cache_ptr: kv_cache_ptr,
        kv_cache_size: kv_cache_size,
        message: "inserted",
    }
}

func (prefix_cache* cache) lookup(int32[] query_tokens) cache_operation_result {
    if len(query_tokens) == 0 {
        cache_operation_result {
            success: false,
            cache_key: "",
            kv_cache_ptr: 0,
            kv_cache_size: 0,
            message: "empty query",
        }
    }

    result := cache.tree.find_longest_prefix(query_tokens)

    if result.found && result.matched_node != nil {
        cache.hit_count = cache.hit_count + 1
        cache.tree.update_access_stats(result.matched_node, 0)

        cache_operation_result {
            success: true,
            cache_key: result.matched_node.prefix_key,
            kv_cache_ptr: result.matched_node.kv_cache_ptr,
            kv_cache_size: result.matched_node.kv_cache_size,
            message: "hit",
        }
    } else {
        cache.miss_count = cache.miss_count + 1

        cache_operation_result {
            success: false,
            cache_key: "",
            kv_cache_ptr: 0,
            kv_cache_size: 0,
            message: "miss",
        }
    }
}

func (prefix_cache* cache) evict_entries(int64 required_space) {
    evicted := 0

    if cache.policy == eviction_policy_lru {
        evict_by_lru(cache, required_space, evicted)
    } else if cache.policy == eviction_policy_lfu {
        evict_by_lfu(cache, required_space, evicted)
    } else if cache.policy == eviction_policy_lru_with_time_decay {
        evict_by_lru_with_decay(cache, required_space, evicted)
    }

    cache.eviction_count = cache.eviction_count + evicted
}

func evict_by_lru(prefix_cache* cache, int64 required_space, int32* evicted) {
    least_recent := nil
    least_time := 9223372036854775807

    for key in cache.entries.keys() {
        entry := cache.entries[key]
        if entry.last_access_time < least_time {
            least_time = entry.last_access_time
            least_recent = *entry
        }
    }

    if least_recent != nil {
        for key in cache.entries.keys() {
            if cache.entries[key].entry_id == least_recent.entry_id {
                cache.current_cache_size = cache.current_cache_size - least_recent.kv_cache_size
                delete(cache.entries, key)
                evicted = evicted + 1
                ""
            }
        }
    }
}

func evict_by_lfu(prefix_cache* cache, int64 required_space, int32* evicted) {
    least_used := nil
    least_count := 9223372036854775807

    for key in cache.entries.keys() {
        entry := cache.entries[key]
        if entry.access_count < least_count {
            least_count = entry.access_count
            least_used = *entry
        }
    }

    if least_used != nil {
        for key in cache.entries.keys() {
            if cache.entries[key].entry_id == least_used.entry_id {
                cache.current_cache_size = cache.current_cache_size - least_used.kv_cache_size
                delete(cache.entries, key)
                evicted = evicted + 1
                ""
            }
        }
    }
}

func evict_by_lru_with_decay(prefix_cache* cache, int64 required_space, int32* evicted) {
    decay_factor := 0.9
    best_candidate := nil
    best_score := 0.0

    for key in cache.entries.keys() {
        entry := cache.entries[key]
        time_since_access := 0
        score := float(entry.access_count) * decay_factor
        if score < best_score {
            best_score = score
            best_candidate = *entry
        }
    }

    if best_candidate != nil {
        for key in cache.entries.keys() {
            if cache.entries[key].entry_id == best_candidate.entry_id {
                cache.current_cache_size = cache.current_cache_size - best_candidate.kv_cache_size
                delete(cache.entries, key)
                evicted = evicted + 1
                ""
            }
        }
    }
}

func (prefix_cache* cache) get_stats() cache_stats {
    total_hit_miss := cache.hit_count + cache.miss_count
    hit_rate := 0.0

    if total_hit_miss > 0 {
        hit_rate = float(cache.hit_count) / float(total_hit_miss)
    }

    tree_stats := cache.tree.get_cache_stats()
    compression := 0

    if compression_ratio in tree_stats {
        compression = int32(tree_stats["compression_ratio"])
    }

    cache_stats {
        hit_count: cache.hit_count,
        miss_count: cache.miss_count,
        eviction_count: cache.eviction_count,
        cache_size: cache.current_cache_size,
        cache_entries: len(cache.entries),
        total_tokens_cached: tree_stats["total_cached_tokens"],
        hit_rate: hit_rate,
        compression_ratio: compression,
    }
}

func (prefix_cache* cache) clear() {
    cache.entries = map[string, cache_entry]{}
    cache.current_cache_size = 0
    cache.hit_count = 0
    cache.miss_count = 0
    cache.eviction_count = 0
}

func (prefix_cache* cache) get_cache_utilization() float {
    if cache.max_cache_size == 0 {
        0.0
    }

    float(cache.current_cache_size) / float(cache.max_cache_size)
}

func (prefix_cache* cache) is_full() bool {
    cache.current_cache_size >= cache.max_cache_size
}

func (prefix_cache* cache) find_matching_prefix(int32[] query_tokens) cache_entry {
    result := cache.lookup(query_tokens)

    if result.success && result.cache_key in cache.entries {
        cache.entries[result.cache_key]
    }

    cache_entry {
        token_sequence: int32[]{},
        kv_cache_ptr: 0,
        kv_cache_size: 0,
        access_count: 0,
        last_access_time: 0,
        creation_time: 0,
        entry_id: "",
    }
}

func (prefix_cache* cache) get_high_reuse_prefixes() cache_entry[] {
    results := cache_entry[]{}
    high_reuse_nodes := cache.tree.find_high_reuse_nodes()

    for node in high_reuse_nodes {
        for key in cache.entries.keys() {
            entry := cache.entries[key]
            if entry.entry_id == node.prefix_key {
                results = append(results, entry)
            }
        }
    }

    results
}

func (prefix_cache* cache) estimate_memory_savings() int64 {
    cache.tree.estimate_compression()
    tree_stats := cache.tree.get_cache_stats()
    total_cached := tree_stats["total_cached_tokens"]
    compression := tree_stats["compression_ratio"]

    if compression > 1 {
        total_cached - (total_cached / compression)
    } else {
        0
    }
}
