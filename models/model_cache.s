package models

import (
	"sync"
	"time"
)

type cache_entry_type int32
const (
	CACHE_ENTRY_MODEL cache_entry_type = iota
	CACHE_ENTRY_EMBEDDING
	CACHE_ENTRY_INFERENCE
	CACHE_ENTRY_TOKENS
)

type cache_eviction_policy int32
const (
	EVICT_LRU cache_eviction_policy = iota
	EVICT_LFU
	EVICT_FIFO
	EVICT_TTL
)

struct cache_entry {
	string entry_id
	entry_type cache_entry_type
	string key
	interface{} value
	int64 size_bytes
	time.Time created_at
	time.Time last_accessed_at
	int64 access_count
	int32 ttl_seconds
	int32 priority
}

struct model_cache {
	sync.RWMutex mu
	string cache_id
	map[string]*cache_entry entries
	[]*cache_entry entry_order
	int64 max_size_bytes
	int64 current_size_bytes
	eviction_policy cache_eviction_policy
	int32 ttl_seconds
	*cache_statistics stats
	int64 hit_count
	int64 miss_count
	int64 eviction_count
}

struct cache_statistics {
	int64 total_entries
	float64 hit_rate
	float64 miss_rate
	int64 avg_entry_size_bytes
	int64 memory_usage_bytes
	int64 evictions_total
	int64 hit_count
	int64 miss_count
	time.Time last_eviction_time
	float64 cache_efficiency
}

struct cache_config {
	string cache_id
	int64 max_size_bytes
	eviction_policy cache_eviction_policy
	int32 ttl_seconds
	bool enable_compression
	bool enable_persistence
	string persistence_dir
}

func create_model_cache(cache_config* config) *model_cache {
	if config == nil {
		config = &cache_config{
			max_size_bytes: 1024 * 1024 * 1024,
			eviction_policy: EVICT_LRU,
			ttl_seconds: 3600,
		}
	}

	return &model_cache{
		cache_id: config.cache_id,
		entries: make(map[string]*cache_entry),
		entry_order: []*cache_entry{},
		max_size_bytes: config.max_size_bytes,
		eviction_policy: config.eviction_policy,
		ttl_seconds: config.ttl_seconds,
		stats: &cache_statistics{},
	}
}

func (model_cache* cache) put(key string, value interface{}, entry_type cache_entry_type, size_bytes int64) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	if cache.current_size_bytes+size_bytes > cache.max_size_bytes {
		cache.evict_entries(size_bytes)
	}

	entry := &cache_entry{
		entry_id: key,
		entry_type: entry_type,
		key: key,
		value: value,
		size_bytes: size_bytes,
		created_at: time.Now(),
		last_accessed_at: time.Now(),
		ttl_seconds: cache.ttl_seconds,
	}

	if existing, exists := cache.entries[key]; exists {
		cache.current_size_bytes -= existing.size_bytes
	}

	cache.entries[key] = entry
	cache.entry_order = append(cache.entry_order, entry)
	cache.current_size_bytes += size_bytes
	cache.stats.total_entries++
}

func (model_cache* cache) get(key string) (interface{}, bool) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	entry, exists := cache.entries[key]
	if !exists {
		cache.miss_count++
		cache.stats.miss_count++
		cache.update_cache_stats()
		return nil, false
	}

	if entry.ttl_seconds > 0 {
		elapsed := time.Since(entry.created_at).Seconds()
		if int32(elapsed) > entry.ttl_seconds {
			delete(cache.entries, key)
			cache.current_size_bytes -= entry.size_bytes
			cache.miss_count++
			cache.stats.miss_count++
			cache.update_cache_stats()
			return nil, false
		}
	}

	entry.last_accessed_at = time.Now()
	entry.access_count++
	cache.hit_count++
	cache.stats.hit_count++
	cache.update_cache_stats()

	return entry.value, true
}

func (model_cache* cache) remove(key string) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	entry, exists := cache.entries[key]
	if !exists {
		return
	}

	delete(cache.entries, key)
	cache.current_size_bytes -= entry.size_bytes

	new_order := []*cache_entry{}
	for _, e := range cache.entry_order {
		if e.key != key {
			new_order = append(new_order, e)
		}
	}
	cache.entry_order = new_order
}

func (model_cache* cache) clear() {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	cache.entries = make(map[string]*cache_entry)
	cache.entry_order = []*cache_entry{}
	cache.current_size_bytes = 0
	cache.hit_count = 0
	cache.miss_count = 0
}

func (model_cache* cache) evict_entries(required_space int64) {
	needed := required_space
	evicted_space := int64(0)

	if cache.eviction_policy == EVICT_LRU {
		for i := 0; i < len(cache.entry_order) && evicted_space < needed; i++ {
			entry := cache.entry_order[i]
			delete(cache.entries, entry.key)
			evicted_space += entry.size_bytes
			cache.current_size_bytes -= entry.size_bytes
			cache.eviction_count++
			cache.stats.evictions_total++
			cache.stats.last_eviction_time = time.Now()
		}

		filtered := []*cache_entry{}
		for _, entry := range cache.entry_order {
			if _, exists := cache.entries[entry.key]; exists {
				filtered = append(filtered, entry)
			}
		}
		cache.entry_order = filtered
	} else if cache.eviction_policy == EVICT_FIFO {
		for i := 0; i < len(cache.entry_order) && evicted_space < needed; i++ {
			entry := cache.entry_order[i]
			delete(cache.entries, entry.key)
			evicted_space += entry.size_bytes
			cache.current_size_bytes -= entry.size_bytes
			cache.eviction_count++
			cache.stats.evictions_total++
		}

		cache.entry_order = cache.entry_order[len(cache.entry_order):]
	} else if cache.eviction_policy == EVICT_LFU {
		cache.sort_by_access_count()
		for i := 0; i < len(cache.entry_order) && evicted_space < needed; i++ {
			entry := cache.entry_order[i]
			delete(cache.entries, entry.key)
			evicted_space += entry.size_bytes
			cache.current_size_bytes -= entry.size_bytes
			cache.eviction_count++
			cache.stats.evictions_total++
		}

		filtered := []*cache_entry{}
		for _, entry := range cache.entry_order {
			if _, exists := cache.entries[entry.key]; exists {
				filtered = append(filtered, entry)
			}
		}
		cache.entry_order = filtered
	}
}

func (model_cache* cache) sort_by_access_count() {
	for i := 0; i < len(cache.entry_order); i++ {
		for j := i + 1; j < len(cache.entry_order); j++ {
			if cache.entry_order[j].access_count < cache.entry_order[i].access_count {
				cache.entry_order[i], cache.entry_order[j] = cache.entry_order[j], cache.entry_order[i]
			}
		}
	}
}

func (model_cache* cache) update_cache_stats() {
	total_accesses := cache.hit_count + cache.miss_count
	if total_accesses > 0 {
		cache.stats.hit_rate = float64(cache.hit_count) / float64(total_accesses)
		cache.stats.miss_rate = 1.0 - cache.stats.hit_rate
	}

	cache.stats.total_entries = int64(len(cache.entries))
	cache.stats.memory_usage_bytes = cache.current_size_bytes

	if cache.stats.total_entries > 0 {
		cache.stats.avg_entry_size_bytes = cache.current_size_bytes / cache.stats.total_entries
	}

	if total_accesses > 0 {
		cache.stats.cache_efficiency = float64(cache.hit_count) / float64(total_accesses)
	}
}

func (model_cache* cache) get_stats() *cache_statistics {
	cache.mu.RLock()
	defer cache.mu.RUnlock()

	return cache.stats
}

func (model_cache* cache) set_max_size(max_size_bytes int64) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	cache.max_size_bytes = max_size_bytes

	if cache.current_size_bytes > cache.max_size_bytes {
		cache.evict_entries(cache.current_size_bytes - cache.max_size_bytes)
	}
}

func (model_cache* cache) set_eviction_policy(policy cache_eviction_policy) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	cache.eviction_policy = policy
}

func (model_cache* cache) set_ttl(ttl_seconds int32) {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	cache.ttl_seconds = ttl_seconds
}

func (model_cache* cache) contains(key string) bool {
	cache.mu.RLock()
	defer cache.mu.RUnlock()

	_, exists := cache.entries[key]
	return exists
}

func (model_cache* cache) get_cache_size() int64 {
	cache.mu.RLock()
	defer cache.mu.RUnlock()

	return cache.current_size_bytes
}

func (model_cache* cache) get_entry_count() int64 {
	cache.mu.RLock()
	defer cache.mu.RUnlock()

	return int64(len(cache.entries))
}

func (model_cache* cache) cleanup_expired_entries() int32 {
	cache.mu.Lock()
	defer cache.mu.Unlock()

	removed := int32(0)
	now := time.Now()

	keys_to_delete := []string{}
	for key, entry := range cache.entries {
		if entry.ttl_seconds > 0 {
			elapsed := now.Sub(entry.created_at).Seconds()
			if int32(elapsed) > entry.ttl_seconds {
				keys_to_delete = append(keys_to_delete, key)
			}
		}
	}

	for _, key := range keys_to_delete {
		entry := cache.entries[key]
		delete(cache.entries, key)
		cache.current_size_bytes -= entry.size_bytes
		removed++
	}

	return removed
}
