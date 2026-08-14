package neurx.cache.prefix_cache_eviction
struct cache_entry {
    string prefix_hash
    int tokens_count
    int access_count
    int last_access_time
    int creation_time
    int memory_bytes
}

struct lru_cache_eviction {
    []cache_entry entries
    int max_cache_size
    int current_size
    int eviction_count
}

struct lfu_cache_eviction {
    []cache_entry entries
    int max_cache_size
    int current_size
    int eviction_count
}

func new_lru_eviction(int max_cache_size) lru_cache_eviction {
    lru_cache_eviction {
        entries: []cache_entry{},
        max_cache_size: max_cache_size,
        current_size: 0,
        eviction_count: 0,
    }
}

func new_lfu_eviction(int max_cache_size) lfu_cache_eviction {
    lfu_cache_eviction {
        entries: []cache_entry{},
        max_cache_size: max_cache_size,
        current_size: 0,
        eviction_count: 0,
    }
}

func add_cache_entry_lru(
    lru_cache_eviction cache,
    string prefix_hash,
    int tokens_count,
    int memory_bytes,
) lru_cache_eviction {
    entry := cache_entry{
        prefix_hash: prefix_hash,
        tokens_count: tokens_count,
        access_count: 1,
        last_access_time: get_time(),
        creation_time: get_time(),
        memory_bytes: memory_bytes,
    }
    cache.entries = append_cache_entry(cache.entries, entry)
    cache.current_size = cache.current_size + memory_bytes
    if cache.current_size > cache.max_cache_size {
        cache = evict_lru(cache)
    }
    cache
}

func add_cache_entry_lfu(
    lfu_cache_eviction cache,
    string prefix_hash,
    int tokens_count,
    int memory_bytes,
) lfu_cache_eviction {
    entry := cache_entry{
        prefix_hash: prefix_hash,
        tokens_count: tokens_count,
        access_count: 1,
        last_access_time: get_time(),
        creation_time: get_time(),
        memory_bytes: memory_bytes,
    }
    cache.entries = append_cache_entry_lfu(cache.entries, entry)
    cache.current_size = cache.current_size + memory_bytes
    if cache.current_size > cache.max_cache_size {
        cache = evict_lfu_strategy(cache)
    }
    cache
}

func access_cache_entry_lru(
    lru_cache_eviction cache,
    string prefix_hash,
) lru_cache_eviction {
    i := 0
    while i < cache.entries.len {
        if cache.entries[i].prefix_hash == prefix_hash {
            cache.entries[i].access_count = cache.entries[i].access_count + 1
            cache.entries[i].last_access_time = get_time()
            cache.entries[i] = cache.entries[i]
        }
        i = i + 1
    }
    cache
}

func access_cache_entry_lfu(
    lfu_cache_eviction cache,
    string prefix_hash,
) lfu_cache_eviction {
    i := 0
    while i < cache.entries.len {
        if cache.entries[i].prefix_hash == prefix_hash {
            cache.entries[i].access_count = cache.entries[i].access_count + 1
            cache.entries[i].last_access_time = get_time()
            cache.entries[i] = cache.entries[i]
        }
        i = i + 1
    }
    cache
}

func evict_lru(lru_cache_eviction cache) lru_cache_eviction {
    if cache.entries.len == 0 {
        return cache
    }
    lru_idx := 0
    min_time := cache.entries[0].last_access_time
    i := 1
    while i < cache.entries.len {
        if cache.entries[i].last_access_time < min_time {
            min_time = cache.entries[i].last_access_time
            lru_idx = i
        }
        i = i + 1
    }
    removed_entry := cache.entries[lru_idx]
    cache.current_size = cache.current_size - removed_entry.memory_bytes
    cache.eviction_count = cache.eviction_count + 1
    new_entries := []cache_entry{}
    i = 0
    while i < cache.entries.len {
        if i != lru_idx {
            new_entries = append_cache_entry(new_entries, cache.entries[i])
        }
        i = i + 1
    }
    cache.entries = new_entries
    cache
}

func evict_lfu_strategy(lfu_cache_eviction cache) lfu_cache_eviction {
    if cache.entries.len == 0 {
        return cache
    }
    lfu_idx := 0
    min_access := cache.entries[0].access_count
    i := 1
    while i < cache.entries.len {
        if cache.entries[i].access_count < min_access {
            min_access = cache.entries[i].access_count
            lfu_idx = i
        }
        i = i + 1
    }
    removed_entry := cache.entries[lfu_idx]
    cache.current_size = cache.current_size - removed_entry.memory_bytes
    cache.eviction_count = cache.eviction_count + 1
    new_entries := []cache_entry{}
    i = 0
    while i < cache.entries.len {
        if i != lfu_idx {
            new_entries = append_cache_entry_lfu(new_entries, cache.entries[i])
        }
        i = i + 1
    }
    cache.entries = new_entries
    cache
}

func get_cache_stats_lru(lru_cache_eviction cache) string {
    hit_rate := "0.0"
    if cache.entries.len > 0 {
        hit_rate = float_to_str(float(cache.entries.len) / float(cache.entries.len + cache.eviction_count))
    }
    "LRU Cache: " + int_to_str(cache.entries.len) + " entries, " + int_to_str(cache.current_size) + " bytes, " + int_to_str(cache.eviction_count) + " evictions, hit_rate=" + hit_rate
}

func get_cache_stats_lfu(lfu_cache_eviction cache) string {
    hit_rate := "0.0"
    if cache.entries.len > 0 {
        hit_rate = float_to_str(float(cache.entries.len) / float(cache.entries.len + cache.eviction_count))
    }
    "LFU Cache: " + int_to_str(cache.entries.len) + " entries, " + int_to_str(cache.current_size) + " bytes, " + int_to_str(cache.eviction_count) + " evictions, hit_rate=" + hit_rate
}

func append_cache_entry([]cache_entry slice, cache_entry elem) []cache_entry {
    new_slice := []cache_entry{}
    i := 0
    while i < slice.len {
        new_slice = append_cache_entry(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_cache_entry(new_slice, elem)
    new_slice
}

func append_cache_entry_lfu([]cache_entry slice, cache_entry elem) []cache_entry {
    new_slice := []cache_entry{}
    i := 0
    while i < slice.len {
        new_slice = append_cache_entry_lfu(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_cache_entry_lfu(new_slice, elem)
    new_slice
}

func get_time() int {
    0
}

func int_to_str(int n) string {
    ""
}

func float_to_str(float f) string {
    ""
}
