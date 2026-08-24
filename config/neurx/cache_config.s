package config

type cache_policy string

const (
    cache_lru          cache_policy = "lru"
    cache_lfu          cache_policy = "lfu"
    cache_arc          cache_policy = "arc"
    cache_fifo         cache_policy = "fifo"
)

struct cache_config {
    bool enable_cache
    cache_policy policy

    int32 cache_size_mb
    int32 cache_capacity

    bool enable_prefix_caching
    float32 prefix_cache_threshold
    int32 prefix_cache_num_blocks

    bool enable_prompt_caching
    bool enable_request_caching
    bool enable_token_caching

    int32 cache_line_size
    int32 cache_associativity

    float32 cache_hit_threshold
    float32 cache_eviction_ratio

    bool enable_smart_cache_management
    float32 cache_warmup_ratio

    int32 cache_flush_interval_ms
    bool enable_adaptive_cache_sizing

    map[string]interface{} extra_config
}

func create_default_cache_config() cache_config {
    return cache_config{
        enable_cache: true,
        policy: cache_lru,
        cache_size_mb: 1024,
        cache_capacity: 8192,
        enable_prefix_caching: true,
        prefix_cache_threshold: 0.8,
        prefix_cache_num_blocks: 2048,
        enable_prompt_caching: true,
        enable_request_caching: true,
        enable_token_caching: true,
        cache_line_size: 64,
        cache_associativity: 8,
        cache_hit_threshold: 0.7,
        cache_eviction_ratio: 0.2,
        enable_smart_cache_management: true,
        cache_warmup_ratio: 0.5,
        cache_flush_interval_ms: 5000,
        enable_adaptive_cache_sizing: true,
        extra_config: make(map[string]interface{}),
    }
}

func (cache_config* cfg) validate() bool {
    if cfg.cache_size_mb <= 0 {
        return false
    }
    if cfg.cache_capacity <= 0 {
        return false
    }
    return true
}

func (cache_config* cfg) is_enabled() bool {
    return cfg.enable_cache
}

func (cache_config* cfg) optimize_for_memory() {
    cfg.cache_size_mb = 256
    cfg.cache_capacity = 1024
    cfg.cache_eviction_ratio = 0.4
}

func (cache_config* cfg) optimize_for_performance() {
    cfg.cache_size_mb = 4096
    cfg.cache_capacity = 32768
    cfg.cache_eviction_ratio = 0.1
    cfg.enable_prefix_caching = true
    cfg.enable_prompt_caching = true
}

func (cache_config* cfg) set_cache_policy(cache_policy policy) {
    cfg.policy = policy
}

func (cache_config* cfg) enable_all_caching_features() {
    cfg.enable_prefix_caching = true
    cfg.enable_prompt_caching = true
    cfg.enable_request_caching = true
    cfg.enable_token_caching = true
}
