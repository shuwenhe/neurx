package config

type scheduling_algorithm string

const (
    schedule_fcfs          scheduling_algorithm = "fcfs"
    schedule_priority      scheduling_algorithm = "priority"
    schedule_sbf           scheduling_algorithm = "sbf"
    schedule_age_based     scheduling_algorithm = "age_based"
    schedule_prediction    scheduling_algorithm = "prediction"
)

struct scheduler_config {
    scheduling_algorithm algorithm

    int32 max_batch_size
    int32 min_batch_size
    int32 prefill_batch_size
    int32 decode_batch_size

    int32 max_tokens_per_request
    int32 max_tokens_per_batch

    int32 queue_length
    int32 priority_levels

    int32 scheduling_interval_ms
    bool enable_chunked_prefill
    int32 chunk_size

    bool enable_prefix_caching
    float32 cache_hit_threshold

    bool enable_request_batching
    int32 batching_timeout_ms

    bool enable_early_exit
    bool enable_early_termination

    bool enable_token_limit_detection
    int32 token_limit_threshold

    bool enable_adaptive_batching
    float32 adaptive_batch_factor

    map[string]interface{} extra_config
}

func create_default_scheduler_config() scheduler_config {
    return scheduler_config{
        algorithm: schedule_fcfs,
        max_batch_size: 32,
        min_batch_size: 1,
        prefill_batch_size: 16,
        decode_batch_size: 32,
        max_tokens_per_request: 4096,
        max_tokens_per_batch: 8192,
        queue_length: 1024,
        priority_levels: 10,
        scheduling_interval_ms: 10,
        enable_chunked_prefill: true,
        chunk_size: 512,
        enable_prefix_caching: true,
        cache_hit_threshold: 0.8,
        enable_request_batching: true,
        batching_timeout_ms: 50,
        enable_early_exit: false,
        enable_early_termination: false,
        enable_token_limit_detection: true,
        token_limit_threshold: 32768,
        enable_adaptive_batching: true,
        adaptive_batch_factor: 1.2,
        extra_config: make(map[string]interface{}),
    }
}

func (scheduler_config* cfg) validate() bool {
    if cfg.max_batch_size <= 0 {
        return false
    }
    if cfg.max_tokens_per_batch <= 0 {
        return false
    }
    if cfg.scheduling_interval_ms <= 0 {
        return false
    }
    if cfg.min_batch_size > cfg.max_batch_size {
        return false
    }
    return true
}

func (scheduler_config* cfg) get_max_throughput() int32 {
    return cfg.max_batch_size * 100
}

func (scheduler_config* cfg) enable_efficient_scheduling() {
    cfg.enable_chunked_prefill = true
    cfg.enable_prefix_caching = true
    cfg.enable_request_batching = true
    cfg.enable_adaptive_batching = true
}

func (scheduler_config* cfg) optimize_for_latency() {
    cfg.max_batch_size = 8
    cfg.batching_timeout_ms = 10
    cfg.scheduling_interval_ms = 5
}

func (scheduler_config* cfg) optimize_for_throughput() {
    cfg.max_batch_size = 128
    cfg.batching_timeout_ms = 100
    cfg.scheduling_interval_ms = 20
}

func (scheduler_config* cfg) set_prefill_decode_separation() {
    cfg.prefill_batch_size = cfg.max_batch_size / 4
    cfg.decode_batch_size = cfg.max_batch_size
}
