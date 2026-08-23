package config

type device_type string

const (
    device_cuda   device_type = "cuda"
    device_cpu    device_type = "cpu"
    device_tpu    device_type = "tpu"
    device_npu    device_type = "npu"
    device_xpu    device_type = "xpu"
)

struct device_config {
    device_type type
    int32 device_id

    string device_name
    int32 num_devices

    int32 total_memory_mb
    int32 reserved_memory_mb
    float32 device_utilization_threshold

    bool enable_memory_optimization
    bool enable_device_P2P

    int32 max_concurrent_kernels
    int32 max_threads_per_block
    int32 max_blocks_per_grid

    bool enable_device_scheduling
    bool enable_stream_management

    int32 num_streams
    bool enable_stream_prioritization

    bool enable_pinned_memory
    int32 pinned_memory_size_mb

    bool enable_device_pooling
    float32 device_pool_threshold

    bool enable_device_swap
    int32 swap_space_mb

    map[string]interface{} extra_config
}

func create_default_device_config() device_config {
    return device_config{
        type: device_cuda,
        device_id: 0,
        device_name: "GPU-0",
        num_devices: 1,
        total_memory_mb: 40960,
        reserved_memory_mb: 2048,
        device_utilization_threshold: 0.9,
        enable_memory_optimization: true,
        enable_device_P2P: true,
        max_concurrent_kernels: 32,
        max_threads_per_block: 1024,
        max_blocks_per_grid: 65535,
        enable_device_scheduling: true,
        enable_stream_management: true,
        num_streams: 16,
        enable_stream_prioritization: true,
        enable_pinned_memory: true,
        pinned_memory_size_mb: 1024,
        enable_device_pooling: true,
        device_pool_threshold: 0.8,
        enable_device_swap: false,
        swap_space_mb: 0,
        extra_config: make(map[string]interface{}),
    }
}

func (device_config* cfg) validate() bool {
    if cfg.total_memory_mb <= cfg.reserved_memory_mb {
        return false
    }
    if cfg.device_utilization_threshold <= 0.0 || cfg.device_utilization_threshold > 1.0 {
        return false
    }
    return true
}

func (device_config* cfg) get_available_memory_mb() int32 {
    return cfg.total_memory_mb - cfg.reserved_memory_mb
}

func (device_config* cfg) is_cuda() bool {
    return cfg.type == device_cuda
}

func (device_config* cfg) is_cpu() bool {
    return cfg.type == device_cpu
}

func (device_config* cfg) enable_multi_device() {
    cfg.num_devices = 8
    cfg.enable_device_P2P = true
    cfg.enable_device_pooling = true
}

func (device_config* cfg) optimize_for_memory() {
    cfg.reserved_memory_mb = cfg.total_memory_mb / 4
    cfg.enable_memory_optimization = true
    cfg.enable_device_swap = true
}
