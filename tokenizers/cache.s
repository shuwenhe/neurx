// NeurX Tokenizers - Token Cache Management
// Efficient caching system for tokenization results

import "./types"
import "std/string"
import "std/vector"

// ============================================================================
// Cache Entry and Manager
// ============================================================================

struct CacheEntry {
    key: string,
    tokens: vec[i32],
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
    eviction_policy: string,  // "lru", "lfu", "fifo"
    stats: CacheStats,
}

struct CacheStats {
    total_hits: i64,
    total_misses: i64,
    total_evictions: i64,
    total_insertions: i64,
    bytes_evicted: i64,
}

// NewTokenCache - Create a new token cache
func NewTokenCache(max_size_bytes: i32, eviction_policy: string) &TokenCache {
    cache := new(TokenCache)
    cache.entries = make(map[string]CacheEntry)
    cache.max_size_bytes = max_size_bytes
    cache.current_size_bytes = 0
    cache.max_entries = max_size_bytes / 100  // Estimate average entry size
    cache.eviction_policy = eviction_policy
    cache.stats = CacheStats{}
    return cache
}

// ============================================================================
// Cache Operations
// ============================================================================

// Get - Retrieve tokens from cache
func (c: &TokenCache) Get(key: string) (vec[i32], bool) {
    if entry, ok := c.entries[key]; ok {
        c.stats.total_hits += 1
        
        // Update hit count and access time
        entry.hit_count += 1
        entry.access_time = current_time_ms()
        
        return entry.tokens, true
    }
    
    c.stats.total_misses += 1
    return make(vec[i32], 0), false
}

// Put - Store tokens in cache
func (c: &TokenCache) Put(key: string, tokens: vec[i32]) bool {
    return c.PutWithHash(key, tokens, hash_string(key))
}

// PutWithHash - Store tokens with pre-computed hash
func (c: &TokenCache) PutWithHash(key: string, tokens: vec[i32], hash: u64) bool {
    // Check if key already exists
    if _, exists := c.entries[key]; exists {
        return false  // Entry already exists
    }
    
    // Calculate entry size
    entry_size := len(key) + len(tokens)*4 + 64  // overhead
    
    // Check if entry is too large
    if entry_size > c.max_size_bytes {
        return false
    }
    
    // Make space if needed
    for c.current_size_bytes + entry_size > c.max_size_bytes && len(c.entries) > 0 {
        c.evict_one()
    }
    
    // Create and insert entry
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

// Remove - Remove entry from cache
func (c: &TokenCache) Remove(key: string) bool {
    if entry, ok := c.entries[key]; ok {
        delete(c.entries, key)
        c.current_size_bytes -= entry.size_bytes
        return true
    }
    return false
}

// Contains - Check if key exists in cache
func (c: &TokenCache) Contains(key: string) bool {
    _, exists := c.entries[key]
    return exists
}

// ============================================================================
// Eviction Policies
// ============================================================================

// evict_one - Evict one entry based on policy
func (c: &TokenCache) evict_one() {
    if len(c.entries) == 0 {
        return
    }
    
    var key_to_evict string
    var min_value i32 = i32(2147483647)  // Max int32
    
    if c.eviction_policy == "lru" {
        // Least Recently Used
        var min_time i64 = i64(9223372036854775807)  // Max int64
        
        for key, entry := range c.entries {
            if entry.access_time < min_time {
                min_time = entry.access_time
                key_to_evict = key
            }
        }
    } else if c.eviction_policy == "lfu" {
        // Least Frequently Used
        min_value = i32(2147483647)
        
        for key, entry := range c.entries {
            if entry.hit_count < min_value {
                min_value = entry.hit_count
                key_to_evict = key
            }
        }
    } else {
        // FIFO - evict by insertion order (use smallest timestamp)
        var min_time i64 = i64(9223372036854775807)
        
        for key, entry := range c.entries {
            if entry.timestamp < min_time {
                min_time = entry.timestamp
                key_to_evict = key
            }
        }
    }
    
    // Perform eviction
    if len(key_to_evict) > 0 {
        if entry, ok := c.entries[key_to_evict]; ok {
            delete(c.entries, key_to_evict)
            c.current_size_bytes -= entry.size_bytes
            c.stats.total_evictions += 1
            c.stats.bytes_evicted += i64(entry.size_bytes)
        }
    }
}

// ============================================================================
// Batch Operations
// ============================================================================

// GetBatch - Retrieve multiple entries
func (c: &TokenCache) GetBatch(keys: vec[string]) map[string]vec[i32] {
    results := make(map[string]vec[i32])
    
    for i := 0; i < len(keys); i += 1 {
        if tokens, ok := c.Get(keys[i]); ok {
            results[keys[i]] = tokens
        }
    }
    
    return results
}

// PutBatch - Store multiple entries
func (c: &TokenCache) PutBatch(entries: map[string]vec[i32]) i32 {
    count := i32(0)
    
    for key, tokens := range entries {
        if c.Put(key, tokens) {
            count += 1
        }
    }
    
    return count
}

// ============================================================================
// Cache Maintenance
// ============================================================================

// Clear - Clear entire cache
func (c: &TokenCache) Clear() {
    for key := range c.entries {
        delete(c.entries, key)
    }
    c.current_size_bytes = 0
}

// Compact - Remove low-hit-count entries to free space
func (c: &TokenCache) Compact(min_hit_count: i32) i32 {
    removed := i32(0)
    keys_to_remove := make(vec[string], 0)
    
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

// PurgeOld - Remove entries older than specified time
func (c: &TokenCache) PurgeOld(max_age_ms: i64) i32 {
    removed := i32(0)
    current_time := current_time_ms()
    keys_to_remove := make(vec[string], 0)
    
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

// ============================================================================
// Statistics and Reporting
// ============================================================================

// GetStatistics - Get cache statistics
func (c: &TokenCache) GetStatistics() CacheStats {
    return c.stats
}

// GetHitRate - Get cache hit rate (0-100)
func (c: &TokenCache) GetHitRate() f32 {
    total := c.stats.total_hits + c.stats.total_misses
    if total == 0 {
        return 0.0
    }
    return f32(100.0 * c.stats.total_hits / total)
}

// GetUtilization - Get cache utilization percentage
func (c: &TokenCache) GetUtilization() f32 {
    if c.max_size_bytes == 0 {
        return 0.0
    }
    return f32(100.0 * c.current_size_bytes / c.max_size_bytes)
}

// GetEntryCount - Get number of entries in cache
func (c: &TokenCache) GetEntryCount() i32 {
    return i32(len(c.entries))
}

// GetSizeBytes - Get current cache size in bytes
func (c: &TokenCache) GetSizeBytes() i32 {
    return c.current_size_bytes
}

// PrintStatistics - Print cache statistics
func (c: &TokenCache) PrintStatistics() {
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

// ============================================================================
// Advanced Cache Features
// ============================================================================

// GetLargestEntries - Get N largest entries
func (c: &TokenCache) GetLargestEntries(count: i32) vec[CacheEntry] {
    entries := make(vec[CacheEntry], 0)
    
    // Collect all entries
    for _, entry := range c.entries {
        entries = append(entries, entry)
    }
    
    // Simple bubble sort by size (descending)
    for i := 0; i < len(entries); i += 1 {
        for j := 0; j < len(entries)-1; j += 1 {
            if entries[j].size_bytes < entries[j+1].size_bytes {
                temp := entries[j]
                entries[j] = entries[j+1]
                entries[j+1] = temp
            }
        }
    }
    
    // Return top N
    if i32(len(entries)) > count {
        return entries[0:count]
    }
    return entries
}

// GetHotEntries - Get most frequently accessed entries
func (c: &TokenCache) GetHotEntries(count: i32) vec[CacheEntry] {
    entries := make(vec[CacheEntry], 0)
    
    // Collect all entries
    for _, entry := range c.entries {
        entries = append(entries, entry)
    }
    
    // Sort by hit count (descending)
    for i := 0; i < len(entries); i += 1 {
        for j := 0; j < len(entries)-1; j += 1 {
            if entries[j].hit_count < entries[j+1].hit_count {
                temp := entries[j]
                entries[j] = entries[j+1]
                entries[j+1] = temp
            }
        }
    }
    
    // Return top N
    if i32(len(entries)) > count {
        return entries[0:count]
    }
    return entries
}

// ============================================================================
// Utility Functions
// ============================================================================

func hash_string(s: string) u64 {
    hash := u64(5381)
    for i := 0; i < len(s); i += 1 {
        hash = ((hash << 5) + hash) + u64(s[i])
    }
    return hash
}

func current_time_ms() i64 {
    // Simplified: return 0 for now
    return i64(0)
}
