package config

type kv_cache_location string

const (
    kv_cache_gpu         kv_cache_location = "gpu"
    kv_cache_cpu         kv_cache_location = "cpu"
    kv_cache_nvme        kv_cache_location = "nvme"
    kv_cache_hybrid      kv_cache_location = "hybrid"
)

struct kv_transfer_config {
    kv_cache_location location
    bool enable_kv_transfer
    
    bool enable_prefetching
    bool enable_prefill_prefetch
    bool enable_decode_prefetch
    
    int32 prefetch_threshold
    int32 prefetch_lookahead_distance
    
    bool enable_offloading
    int32 offload_threshold
    float32 offload_ratio
    
    bool enable_kv_compression
    float32 compression_ratio
    string compression_method
    
    int32 gpu_kv_cache_size_mb
    int32 cpu_kv_cache_size_mb
    int32 nvme_kv_cache_size_gb
    
    bool enable_dynamic_kv_cache
    float32 dynamic_kv_ratio
    
    bool enable_reuse_cache
    float32 cache_reuse_threshold
    
    int32 kv_cache_block_size
    int32 num_kv_cache_blocks
    
    map[string]interface{} extra_config
}

func create_default_kv_transfer_config() kv_transfer_config {
    return kv_transfer_config{
        location: kv_cache_gpu,
        enable_kv_transfer: true,
        enable_prefetching: true,
        enable_prefill_prefetch: true,
        enable_decode_prefetch: true,
        prefetch_threshold: 256,
        prefetch_lookahead_distance: 512,
        enable_offloading: false,
        offload_threshold: 4096,
        offload_ratio: 0.8,
        enable_kv_compression: false,
        compression_ratio: 0.5,
        compression_method: "lz4",
        gpu_kv_cache_size_mb: 4096,
        cpu_kv_cache_size_mb: 16384,
        nvme_kv_cache_size_gb: 128,
        enable_dynamic_kv_cache: true,
        dynamic_kv_ratio: 0.8,
        enable_reuse_cache: true,
        cache_reuse_threshold: 0.9,
        kv_cache_block_size: 256,
        num_kv_cache_blocks: 16384,
        extra_config: make(map[string]interface{}),
    }
}

func (kv_transfer_config* cfg) validate() bool {
    if cfg.gpu_kv_cache_size_mb <= 0 {
        return false
    }
    if cfg.prefetch_threshold <= 0 {
        return false
    }
    return true
}

func (kv_transfer_config* cfg) is_gpu_only() bool {
    return cfg.location == kv_cache_gpu
}

func (kv_transfer_config* cfg) is_hybrid() bool {
    return cfg.location == kv_cache_hybrid
}

func (kv_transfer_config* cfg) enable_cpu_fallback() {
    cfg.location = kv_cache_hybrid
    cfg.enable_offloading = true
}

func (kv_transfer_config* cfg) enable_nvme_storage() {
    cfg.location = kv_cache_hybrid
    cfg.enable_offloading = true
    cfg.nvme_kv_cache_size_gb = 256
}

func (kv_transfer_config* cfg) get_total_kv_size_mb() int32 {
    return cfg.gpu_kv_cache_size_mb + cfg.cpu_kv_cache_size_mb + (cfg.nvme_kv_cache_size_gb * 1024)
}
