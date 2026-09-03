struct cache_index_entry {
    string prefix_hash
    []int block_ids
    int num_blocks
    int64 created_time
    int64 last_access_time
    int access_count
}

struct cache_index {
    []cache_index_entry entries
    int num_entries
    int max_entries
    int64 current_time
}

func create_cache_index(int max_entries_count) cache_index {
    cache_index idx = cache_index{}
    idx.max_entries = max_entries_count
    idx.num_entries = 0
    idx.current_time = 0
    idx.entries = make([]cache_index_entry, max_entries_count)
    print("[CacheIndex] Created with capacity " + int_to_string(max_entries_count) + "\n")
    return idx
}

func compute_prefix_hash([]int tokens, int max_tokens) string {
    if len(tokens) == 0 {
        return "empty"
    }
    int hash_seed = 0
    int i = 0
    int limit = len(tokens)
    if limit > max_tokens { limit = max_tokens }
    for i < limit {
        int token = tokens[i]
        hash_seed = (hash_seed * 31 + token) % 2147483647
        i = i + 1
    }
    string hash_str = "h_" + int_to_string(hash_seed)
    return hash_str
}

func cache_index_find_entry(cache_index idx, string prefix_hash) int {
    int i = 0
    for i < idx.num_entries {
        if idx.entries[i].prefix_hash == prefix_hash {
            return i
        }
        i = i + 1
    }
    return -1
}

func cache_index_get_blocks(cache_index idx, string prefix_hash) []int {
    int entry_idx = cache_index_find_entry(idx, prefix_hash)
    if entry_idx == -1 {
        print("[CacheIndex] Miss for prefix " + prefix_hash + "\n")
        return []int{}
    }
    cache_index_entry entry = idx.entries[entry_idx]
    entry.access_count = entry.access_count + 1
    entry.last_access_time = idx.current_time
    idx.entries[entry_idx] = entry
    print("[CacheIndex] Hit for prefix " + prefix_hash + " (blocks=" + int_to_string(entry.num_blocks) + ", accesses=" + int_to_string(entry.access_count) + ")\n")
    return entry.block_ids
}

func cache_index_store_blocks(cache_index idx, string prefix_hash, []int block_ids) int {
    if idx.num_entries >= idx.max_entries {
        print("[CacheIndex] Index full, cannot store prefix " + prefix_hash + "\n")
        return 0
    }
    int entry_idx = cache_index_find_entry(idx, prefix_hash)
    if entry_idx >= 0 {
        print("[CacheIndex] Prefix already exists, updating\n")
        cache_index_entry entry = idx.entries[entry_idx]
        entry.block_ids = block_ids
        entry.num_blocks = len(block_ids)
        entry.last_access_time = idx.current_time
        idx.entries[entry_idx] = entry
        return 1
    }
    cache_index_entry new_entry = cache_index_entry{}
    new_entry.prefix_hash = prefix_hash
    new_entry.block_ids = block_ids
    new_entry.num_blocks = len(block_ids)
    new_entry.created_time = idx.current_time
    new_entry.last_access_time = idx.current_time
    new_entry.access_count = 1
    idx.entries[idx.num_entries] = new_entry
    idx.num_entries = idx.num_entries + 1
    print("[CacheIndex] Stored prefix " + prefix_hash + " with " + int_to_string(len(block_ids)) + " blocks\n")
    return 1
}

func cache_index_get_stats(cache_index idx) string {
    int total_hits = 0
    int i = 0
    for i < idx.num_entries {
        total_hits = total_hits + idx.entries[i].access_count
        i = i + 1
    }
    string stats = "[CacheIndex] Entries=" + int_to_string(idx.num_entries) + "/" + int_to_string(idx.max_entries) + ", TotalAccesses=" + int_to_string(total_hits)
    return stats
}

func cache_index_evict_lru(cache_index idx) string {
    if idx.num_entries == 0 {
        return ""
    }
    int lru_idx = 0
    int64 oldest_time = idx.entries[0].last_access_time
    int i = 1
    for i < idx.num_entries {
        if idx.entries[i].last_access_time < oldest_time {
            oldest_time = idx.entries[i].last_access_time
            lru_idx = i
        }
        i = i + 1
    }
    string evicted_hash = idx.entries[lru_idx].prefix_hash
    print("[CacheIndex] Evicting LRU entry: " + evicted_hash + "\n")
    i = lru_idx
    for i < idx.num_entries - 1 {
        idx.entries[i] = idx.entries[i + 1]
        i = i + 1
    }
    idx.num_entries = idx.num_entries - 1
    return evicted_hash
}

func cache_index_clear(cache_index idx) {
    idx.num_entries = 0
    print("[CacheIndex] Cleared all entries\n")
}

func cache_index_update_time(cache_index idx, int64 new_time) {
    idx.current_time = new_time
}
