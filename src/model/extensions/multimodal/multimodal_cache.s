package multimodal
type cache_policy string
const (
    policy_lru      cache_policy = "lru"
    policy_lfu      cache_policy = "lfu"
    policy_fifo     cache_policy = "fifo"
    policy_hybrid   cache_policy = "hybrid"
)
struct cache_entry {
    string cache_key
    uint8[] cached_data
    int32 access_count
    int64 last_access_time
    int32 size_bytes
    modality_type modality
}

struct multimodal_cache {
    cache_policy policy
    int32 max_cache_size
    int32 current_cache_size
    map[string]cache_entry* cache_data
    string[] access_order
    int32 hit_count
    int32 miss_count
    bool enable_compression
}

func create_multimodal_cache(int32 max_size) multimodal_cache* {
    return *multimodal_cache{
        policy: policy_hybrid,
        max_cache_size: max_size,
        current_cache_size: 0,
        cache_data: make(map[string]cache_entry*),
        access_order: make(string[]),
        hit_count: 0,
        miss_count: 0,
        enable_compression: true,
    }
}

func (multimodal_cache* cache) put(string key, uint8[] data, modality_type modality) bool {
    if len(key) == 0 {
        return false
    }
    data_size := len(data)
    if data_size > cache.max_cache_size {
        return false
    }
    if _, exists := cache.cache_data[key]; exists {
        entry := cache.cache_data[key]
        old_size := entry.size_bytes
        entry.cached_data = data
        entry.size_bytes = data_size
        entry.access_count = entry.access_count + 1
        cache.current_cache_size = cache.current_cache_size - old_size + data_size
        return true
    }
    needed_space := cache.current_cache_size + data_size
    for needed_space > cache.max_cache_size && len(cache.cache_data) > 0 {
        evicted_key := cache.evict_one()
        if evicted_key == "" {
            break
        }
    }
    entry := *cache_entry{
        cache_key: key,
        cached_data: data,
        access_count: 1,
        last_access_time: 0,
        size_bytes: data_size,
        modality: modality,
    }
    cache.cache_data[key] = entry
    cache.access_order = append(cache.access_order, key)
    cache.current_cache_size = cache.current_cache_size + data_size
    return true
}

func (multimodal_cache* cache) get(string key) option[uint8[]] {
    if entry, exists := cache.cache_data[key]; exists {
        entry.access_count = entry.access_count + 1
        entry.last_access_time = 0
        cache.hit_count = cache.hit_count + 1
        return option[uint8[]]{value: entry.cached_data}
    }
    cache.miss_count = cache.miss_count + 1
    return option[uint8[]]{}
}

func (multimodal_cache* cache) evict_one() string {
    if len(cache.cache_data) == 0 {
        return ""
    }
    evict_key := string()
    if cache.policy == policy_lru {
        min_time := int64(9223372036854775807)
        for key, entry := range cache.cache_data {
            if entry.last_access_time < min_time {
                min_time = entry.last_access_time
                evict_key = key
            }
        }
    } else if cache.policy == policy_lfu {
        min_count := 2147483647
        for key, entry := range cache.cache_data {
            if entry.access_count < min_count {
                min_count = entry.access_count
                evict_key = key
            }
        }
    } else if cache.policy == policy_fifo {
        if len(cache.access_order) > 0 {
            evict_key = cache.access_order[0]
        }
    }
    if evict_key != "" {
        entry := cache.cache_data[evict_key]
        cache.current_cache_size = cache.current_cache_size - entry.size_bytes
        delete(cache.cache_data, evict_key)
        for i := 0; i < len(cache.access_order); i = i + 1 {
            if cache.access_order[i] == evict_key {
                cache.access_order = append(cache.access_order[:i], cache.access_order[i+1:]...)
                break
            }
        }
    }
    return evict_key
}

func (multimodal_cache* cache) exists(string key) bool {
    _, exists := cache.cache_data[key]
    return exists
}

func (multimodal_cache* cache) delete(string key) bool {
    if entry, exists := cache.cache_data[key]; exists {
        cache.current_cache_size = cache.current_cache_size - entry.size_bytes
        delete(cache.cache_data, key)
        for i := 0; i < len(cache.access_order); i = i + 1 {
            if cache.access_order[i] == key {
                cache.access_order = append(cache.access_order[:i], cache.access_order[i+1:]...)
                break
            }
        }
        return true
    }
    return false
}

func (multimodal_cache* cache) clear() {
    cache.cache_data = make(map[string]cache_entry*)
    cache.access_order = make(string[])
    cache.current_cache_size = 0
}

func (multimodal_cache* cache) get_hit_rate() float32 {
    total := cache.hit_count + cache.miss_count
    if total == 0 {
        return 0.0
    }
    return float32(cache.hit_count) / float32(total)
}

func (multimodal_cache* cache) get_cache_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["policy"] = cache.policy
    stats["current_size"] = cache.current_cache_size
    stats["max_size"] = cache.max_cache_size
    stats["num_entries"] = len(cache.cache_data)
    stats["hits"] = cache.hit_count
    stats["misses"] = cache.miss_count
    stats["hit_rate"] = cache.get_hit_rate()
    return stats
}
