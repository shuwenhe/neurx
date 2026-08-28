package models
import (
	"fmt"
	"sync"
	"time"
)
type mm_cache_policy int32
const (
	MM_CACHE_LRU mm_cache_policy = iota
	MM_CACHE_LFU
	MM_CACHE_FIFO
	MM_CACHE_ADAPTIVE
)
struct mm_cache_entry {
	string entry_id
	string content_hash
	interface{} cached_data
	modality_type content_modality
	int64 entry_size_bytes
	int32 access_count
	float64 importance_score
	time.Time created_at
	time.Time last_accessed
	time.Time expires_at
}

struct mm_cache_statistics {
	int64 total_cache_size
	int32 num_entries
	int32 max_entries
	int64 cache_hits
	int64 cache_misses
	float32 hit_rate
	float32 miss_rate
	string eviction_policy
	time.Time last_eviction
}

struct multimodal_cache {
	sync.Mutex mu
	map[string]*mm_cache_entry entries
	map[string]string[] modality_index
	*mm_cache_statistics stats
	int64 max_cache_size
	int64 current_cache_size
	int32 max_entries
	mm_cache_policy eviction_policy
	float64 ttl_seconds
	time.Time created_at
}

func create_multimodal_cache(max_size int64) *multimodal_cache {
	cache := *multimodal_cache{
		entries:          make(map[string]*mm_cache_entry),
		modality_index:   make(map[string]string[]),
		stats: *mm_cache_statistics{
			total_cache_size: 0,
			num_entries:      0,
			max_entries:      10000,
			cache_hits:       0,
			cache_misses:     0,
			hit_rate:         0,
			miss_rate:        0,
			eviction_policy:  "lru",
			last_eviction:    time.Now(),
		},
		max_cache_size:   max_size,
		current_cache_size: 0,
		max_entries:      10000,
		eviction_policy:  MM_CACHE_LRU,
		ttl_seconds:      3600,
		created_at:       time.Now(),
	}
	cache.modality_index["text"] = make(string[], 0)
	cache.modality_index["image"] = make(string[], 0)
	cache.modality_index["audio"] = make(string[], 0)
	cache.modality_index["video"] = make(string[], 0)
	cache.modality_index["fused"] = make(string[], 0)
	return cache
}

func (multimodal_cache* mc) put(entry_id string, content_hash string, data interface{}, modality modality_type, size_bytes int64) error {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	if mc.current_cache_size+size_bytes > mc.max_cache_size {
		err := mc.evict_entries_internal(size_bytes)
		if err != nil {
			return err
		}
	}
	if int32(len(mc.entries)) >= mc.max_entries {
		err := mc.evict_one_internal()
		if err != nil {
			return err
		}
	}
	entry := *mm_cache_entry{
		entry_id:          entry_id,
		content_hash:      content_hash,
		cached_data:       data,
		content_modality:  modality,
		entry_size_bytes:  size_bytes,
		access_count:      0,
		importance_score:  1.0,
		created_at:        time.Now(),
		last_accessed:     time.Now(),
		expires_at:        time.Now().Add(time.Duration(mc.ttl_seconds*1000) * time.Millisecond),
	}
	mc.entries[entry_id] = entry
	mc.current_cache_size += size_bytes
	mc.stats.num_entries++
	modality_name := "unknown"
	switch modality {
	case MODALITY_TEXT:
		modality_name = "text"
	case MODALITY_IMAGE:
		modality_name = "image"
	case MODALITY_AUDIO:
		modality_name = "audio"
	case MODALITY_VIDEO:
		modality_name = "video"
	case MODALITY_COMBINED:
		modality_name = "fused"
	}
	if ids, exists := mc.modality_index[modality_name]; exists {
		ids = append(ids, entry_id)
		mc.modality_index[modality_name] = ids
	}
	return nil
}

func (multimodal_cache* mc) get(entry_id string) (interface{}, error) {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	entry, exists := mc.entries[entry_id]
	if !exists {
		mc.stats.cache_misses++
		mc.update_hit_rate()
		return nil, fmt.Errorf("entry %s not found", entry_id)
	}
	if entry.expires_at.Before(time.Now()) {
		delete(mc.entries, entry_id)
		mc.current_cache_size -= entry.entry_size_bytes
		mc.stats.num_entries--
		mc.stats.cache_misses++
		mc.update_hit_rate()
		return nil, fmt.Errorf("entry %s expired", entry_id)
	}
	entry.access_count++
	entry.last_accessed = time.Now()
	mc.stats.cache_hits++
	mc.update_hit_rate()
	return entry.cached_data, nil
}

func (multimodal_cache* mc) exists(entry_id string) bool {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	entry, exists := mc.entries[entry_id]
	if !exists {
		return false
	}
	if entry.expires_at.Before(time.Now()) {
		delete(mc.entries, entry_id)
		mc.current_cache_size -= entry.entry_size_bytes
		mc.stats.num_entries--
		return false
	}
	return true
}

func (multimodal_cache* mc) delete(entry_id string) error {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	entry, exists := mc.entries[entry_id]
	if !exists {
		return fmt.Errorf("entry %s not found", entry_id)
	}
	delete(mc.entries, entry_id)
	mc.current_cache_size -= entry.entry_size_bytes
	mc.stats.num_entries--
	return nil
}

func (multimodal_cache* mc) evict_entries_internal(space_needed int64) error {
	entries_to_remove := make([]*mm_cache_entry, 0)
	for _, entry := range mc.entries {
		if entry.expires_at.Before(time.Now()) {
			entries_to_remove = append(entries_to_remove, entry)
		}
	}
	for _, entry := range entries_to_remove {
		delete(mc.entries, entry.entry_id)
		mc.current_cache_size -= entry.entry_size_bytes
		mc.stats.num_entries--
		if mc.current_cache_size+space_needed <= mc.max_cache_size {
			return nil
		}
	}
	if mc.eviction_policy == MM_CACHE_LRU {
		lru_entry := (*mm_cache_entry)(nil)
		for _, entry := range mc.entries {
			if lru_entry == nil || entry.last_accessed.Before(lru_entry.last_accessed) {
				lru_entry = entry
			}
		}
		if lru_entry != nil {
			delete(mc.entries, lru_entry.entry_id)
			mc.current_cache_size -= lru_entry.entry_size_bytes
			mc.stats.num_entries--
		}
	}
	return nil
}

func (multimodal_cache* mc) evict_one_internal() error {
	if len(mc.entries) == 0 {
		return fmt.Errorf("cache is empty")
	}
	var evict_entry *mm_cache_entry
	if mc.eviction_policy == MM_CACHE_LRU {
		for _, entry := range mc.entries {
			if evict_entry == nil || entry.last_accessed.Before(evict_entry.last_accessed) {
				evict_entry = entry
			}
		}
	} else if mc.eviction_policy == MM_CACHE_LFU {
		for _, entry := range mc.entries {
			if evict_entry == nil || entry.access_count < evict_entry.access_count {
				evict_entry = entry
			}
		}
	} else if mc.eviction_policy == MM_CACHE_FIFO {
		for _, entry := range mc.entries {
			if evict_entry == nil || entry.created_at.Before(evict_entry.created_at) {
				evict_entry = entry
			}
		}
	}
	if evict_entry != nil {
		delete(mc.entries, evict_entry.entry_id)
		mc.current_cache_size -= evict_entry.entry_size_bytes
		mc.stats.num_entries--
		mc.stats.last_eviction = time.Now()
	}
	return nil
}

func (multimodal_cache* mc) cleanup_expired_entries() int32 {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	removed_count := int32(0)
	entries_to_remove := make(string[], 0)
	for entry_id, entry := range mc.entries {
		if entry.expires_at.Before(time.Now()) {
			entries_to_remove = append(entries_to_remove, entry_id)
		}
	}
	for _, entry_id := range entries_to_remove {
		entry := mc.entries[entry_id]
		delete(mc.entries, entry_id)
		mc.current_cache_size -= entry.entry_size_bytes
		mc.stats.num_entries--
		removed_count++
	}
	return removed_count
}

func (multimodal_cache* mc) get_entries_by_modality(modality modality_type) string[] {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	modality_name := "unknown"
	switch modality {
	case MODALITY_TEXT:
		modality_name = "text"
	case MODALITY_IMAGE:
		modality_name = "image"
	case MODALITY_AUDIO:
		modality_name = "audio"
	case MODALITY_VIDEO:
		modality_name = "video"
	case MODALITY_COMBINED:
		modality_name = "fused"
	}
	ids, exists := mc.modality_index[modality_name]
	if !exists {
		return make(string[], 0)
	}
	return ids
}

func (multimodal_cache* mc) get_cache_stats() *mm_cache_statistics {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	return mc.stats
}

func (multimodal_cache* mc) update_hit_rate() {
	total := mc.stats.cache_hits + mc.stats.cache_misses
	if total > 0 {
		mc.stats.hit_rate = float32(mc.stats.cache_hits) / float32(total)
		mc.stats.miss_rate = float32(mc.stats.cache_misses) / float32(total)
	}
}

func (multimodal_cache* mc) clear_cache() {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	mc.entries = make(map[string]*mm_cache_entry)
	mc.modality_index = make(map[string]string[])
	mc.current_cache_size = 0
	mc.stats.num_entries = 0
	mc.stats.cache_hits = 0
	mc.stats.cache_misses = 0
	mc.update_hit_rate()
	mc.modality_index["text"] = make(string[], 0)
	mc.modality_index["image"] = make(string[], 0)
	mc.modality_index["audio"] = make(string[], 0)
	mc.modality_index["video"] = make(string[], 0)
	mc.modality_index["fused"] = make(string[], 0)
}

func (multimodal_cache* mc) set_eviction_policy(policy mm_cache_policy) {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	mc.eviction_policy = policy
	policy_name := "lru"
	switch policy {
	case MM_CACHE_LFU:
		policy_name = "lfu"
	case MM_CACHE_FIFO:
		policy_name = "fifo"
	case MM_CACHE_ADAPTIVE:
		policy_name = "adaptive"
	}
	mc.stats.eviction_policy = policy_name
}

func (multimodal_cache* mc) set_ttl(ttl_seconds float64) {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	mc.ttl_seconds = ttl_seconds
}
