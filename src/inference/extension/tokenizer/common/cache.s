import "./types"
import "std/string"
import "std/vector"
struct CacheEntry {
    key: string,
    tokens: i32[],
    hash: u64,
    timestamp: i64,
    hit_count: i32,
    size_bytes: i32,
    access_time: i64,
}

struct TokenCache {
    entries: map[string]CacheEntry,
    max_size_bytes: i32,
    current_size_bytes: i32,
    max_entries: i32,
    eviction_policy: string,
    stats: CacheStats,
}

struct CacheStats {
    total_hits: i64,
    total_misses: i64,
    total_evictions: i64,
    total_insertions: i64,
    bytes_evicted: i64,
}

func NewTokenCache(i32 max_size_bytes, string eviction_policy) *TokenCache {
    cache := new(TokenCache)
    cache.entries = make(map[string]CacheEntry)
    cache.max_size_bytes = max_size_bytes
    cache.current_size_bytes = 0
    cache.max_entries = max_size_bytes / 100
    cache.eviction_policy = eviction_policy
    cache.stats = CacheStats{}
    return cache
}

func (TokenCache* c) Get(string key) (i32[], bool) {
    if entry, ok := c.entries[key]; ok {
        c.stats.total_hits += 1
        entry.hit_count += 1
        entry.access_time = current_time_ms()
        return entry.tokens, true
    }
    c.stats.total_misses += 1
    return make(i32[], 0), false
}

func (TokenCache* c) Put(string key, i32[] tokens) bool {
    return c.PutWithHash(key, tokens, hash_string(key))
}

func (TokenCache* c) PutWithHash(string key, i32[] tokens, u64 hash) bool {
    if _, exists := c.entries[key]; exists {
        return false
    }
    entry_size := len(key) + len(tokens)*4 + 64
    if entry_size > c.max_size_bytes {
        return false
    }
    for c.current_size_bytes + entry_size > c.max_size_bytes && len(c.entries) > 0 {
        c.evict_one()
    }
    entry := CacheEntry{
        key: key,
        tokens: tokens,
        hash: hash,
        timestamp: current_time_ms(),
        hit_count: 0,
        size_bytes: entry_size,
        access_time: current_time_ms(),
    }
    c.entries[key] = entry
    c.current_size_bytes += entry_size
    c.stats.total_insertions += 1
    return true
}

func (TokenCache* c) Remove(string key) bool {
    if entry, ok := c.entries[key]; ok {
        delete(c.entries, key)
        c.current_size_bytes -= entry.size_bytes
        return true
    }
    return false
}

func (TokenCache* c) Contains(string key) bool {
    _, exists := c.entries[key]
    return exists
}

func (TokenCache* c) evict_one() {
    if len(c.entries) == 0 {
        return
    }
    key_to_evict := string()
    var min_value i32 = i32(2147483647)
    if c.eviction_policy == "lru" {
        var min_time i64 = i64(9223372036854775807)
        for key, entry := range c.entries {
            if entry.access_time < min_time {
                min_time = entry.access_time
                key_to_evict = key
            }
        }
    } else if c.eviction_policy == "lfu" {
        min_value = i32(2147483647)
        for key, entry := range c.entries {
            if entry.hit_count < min_value {
                min_value = entry.hit_count
                key_to_evict = key
            }
        }
    } else {
        var min_time i64 = i64(9223372036854775807)
        for key, entry := range c.entries {
            if entry.timestamp < min_time {
                min_time = entry.timestamp
                key_to_evict = key
            }
        }
    }
    if len(key_to_evict) > 0 {
        if entry, ok := c.entries[key_to_evict]; ok {
            delete(c.entries, key_to_evict)
            c.current_size_bytes -= entry.size_bytes
            c.stats.total_evictions += 1
            c.stats.bytes_evicted += i64(entry.size_bytes)
        }
    }
}

func (TokenCache* c) GetBatch([]string keys) map[string]i32[] {
    results := make(map[string]i32[])
    for i := 0; i < len(keys); i += 1 {
        if tokens, ok := c.Get(keys[i]); ok {
            results[keys[i]] = tokens
        }
    }
    return results
}

func (TokenCache* c) PutBatch(map[string]i32[] entries) i32 {
    count := i32(0)
    for key, tokens := range entries {
        if c.Put(key, tokens) {
            count += 1
        }
    }
    return count
}

func (TokenCache* c) Clear() {
    for key := range c.entries {
        delete(c.entries, key)
    }
    c.current_size_bytes = 0
}

func (TokenCache* c) Compact(i32 min_hit_count) i32 {
    removed := i32(0)
    keys_to_remove := make([]string, 0)
    for key, entry := range c.entries {
        if entry.hit_count < min_hit_count {
            keys_to_remove = append(keys_to_remove, key)
        }
    }
    for i := 0; i < len(keys_to_remove); i += 1 {
        if c.Remove(keys_to_remove[i]) {
            removed += 1
        }
    }
    return removed
}

func (TokenCache* c) PurgeOld(i64 max_age_ms) i32 {
    removed := i32(0)
    current_time := current_time_ms()
    keys_to_remove := make([]string, 0)
    for key, entry := range c.entries {
        if current_time - entry.timestamp > max_age_ms {
            keys_to_remove = append(keys_to_remove, key)
        }
    }
    for i := 0; i < len(keys_to_remove); i += 1 {
        if c.Remove(keys_to_remove[i]) {
            removed += 1
        }
    }
    return removed
}

func (TokenCache* c) GetStatistics() CacheStats {
    return c.stats
}

func (TokenCache* c) GetHitRate() f32 {
    total := c.stats.total_hits + c.stats.total_misses
    if total == 0 {
        return 0.0
    }
    return f32(100.0 * c.stats.total_hits / total)
}

func (TokenCache* c) GetUtilization() f32 {
    if c.max_size_bytes == 0 {
        return 0.0
    }
    return f32(100.0 * c.current_size_bytes / c.max_size_bytes)
}

func (TokenCache* c) GetEntryCount() i32 {
    return i32(len(c.entries))
}

func (TokenCache* c) GetSizeBytes() i32 {
    return c.current_size_bytes
}

func (TokenCache* c) PrintStatistics() {
    println("Cache Statistics:")
    println("  Total Hits:", c.stats.total_hits)
    println("  Total Misses:", c.stats.total_misses)
    println("  Hit Rate:", c.GetHitRate(), "%")
    println("  Current Entries:", c.GetEntryCount())
    println("  Size Used:", c.GetSizeBytes(), "bytes")
    println("  Size Available:", c.max_size_bytes, "bytes")
    println("  Utilization:", c.GetUtilization(), "%")
    println("  Evictions:", c.stats.total_evictions)
    println("  Bytes Evicted:", c.stats.bytes_evicted)
}

func (TokenCache* c) GetLargestEntries(i32 count) []CacheEntry {
    entries := make(CacheEntry[], 0)
    for _, entry := range c.entries {
        entries = append(entries, entry)
    }
    for i := 0; i < len(entries); i += 1 {
        for j := 0; j < len(entries)-1; j += 1 {
            if entries[j].size_bytes < entries[j+1].size_bytes {
                temp := entries[j]
                entries[j] = entries[j+1]
                entries[j+1] = temp
            }
        }
    }
    if i32(len(entries)) > count {
        return entries[0:count]
    }
    return entries
}

func (TokenCache* c) GetHotEntries(i32 count) []CacheEntry {
    entries := make(CacheEntry[], 0)
    for _, entry := range c.entries {
        entries = append(entries, entry)
    }
    for i := 0; i < len(entries); i += 1 {
        for j := 0; j < len(entries)-1; j += 1 {
            if entries[j].hit_count < entries[j+1].hit_count {
                temp := entries[j]
                entries[j] = entries[j+1]
                entries[j+1] = temp
            }
        }
    }
    if i32(len(entries)) > count {
        return entries[0:count]
    }
    return entries
}

func hash_string(string s) u64 {
    hash := u64(5381)
    for i := 0; i < len(s); i += 1 {
        hash = ((hash << 5) + hash) + u64(s[i])
    }
    return hash
}

func current_time_ms() i64 {
    return i64(0)
}
