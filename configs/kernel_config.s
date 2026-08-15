package config

type kernel_type string

const (
    kernel_matmul           kernel_type = "matmul"
    kernel_attention        kernel_type = "attention"
    kernel_normalization    kernel_type = "normalization"
    kernel_activation       kernel_type = "activation"
    kernel_fusion           kernel_type = "fusion"
)

struct kernel_config {
    kernel_type type
    string kernel_name
    
    bool enable_kernel_fusion
    bool enable_kernel_autotuning
    
    bool enable_tensor_core
    bool enable_sparsity
    
    int32 block_size_x
    int32 block_size_y
    int32 block_size_z
    
    int32 grid_size_x
    int32 grid_size_y
    int32 grid_size_z
    
    int32 shared_memory_size_kb
    bool enable_shared_memory_optimization
    
    bool enable_register_reuse
    int32 register_per_thread
    
    string optimization_level
    bool enable_profiling
    
    bool enable_triton_kernels
    bool enable_cutlass_kernels
    bool enable_vllm_kernels
    
    int32 kernel_cache_size_mb
    bool enable_kernel_caching
    
    map[string]interface{} extra_config
}

func create_default_kernel_config() kernel_config {
    return kernel_config{
        type: kernel_matmul,
        kernel_name: "default_matmul",
        enable_kernel_fusion: true,
        enable_kernel_autotuning: true,
        enable_tensor_core: true,
        enable_sparsity: false,
        block_size_x: 128,
        block_size_y: 128,
        block_size_z: 1,
        grid_size_x: 65535,
        grid_size_y: 65535,
        grid_size_z: 1,
        shared_memory_size_kb: 96,
        enable_shared_memory_optimization: true,
        enable_register_reuse: true,
        register_per_thread: 32,
        optimization_level: "O3",
        enable_profiling: false,
        enable_triton_kernels: true,
        enable_cutlass_kernels: true,
        enable_vllm_kernels: true,
        kernel_cache_size_mb: 512,
        enable_kernel_caching: true,
        extra_config: make(map[string]interface{}),
    }
}

func (kernel_config* cfg) validate() bool {
    if cfg.block_size_x <= 0 || cfg.block_size_y <= 0 {
        return false
    }
    if cfg.shared_memory_size_kb > 96 {
        return false
    }
    return true
}

func (kernel_config* cfg) optimize_for_memory() {
    cfg.enable_kernel_fusion = true
    cfg.enable_register_reuse = true
    cfg.shared_memory_size_kb = 48
    cfg.optimization_level = "O2"
}

func (kernel_config* cfg) optimize_for_performance() {
    cfg.enable_kernel_fusion = true
    cfg.enable_kernel_autotuning = true
    cfg.enable_tensor_core = true
    cfg.shared_memory_size_kb = 96
    cfg.optimization_level = "O3"
}

func (kernel_config* cfg) optimize_for_latency() {
    cfg.block_size_x = 64
    cfg.block_size_y = 64
    cfg.enable_kernel_fusion = true
}

func (kernel_config* cfg) optimize_for_throughput() {
    cfg.block_size_x = 256
    cfg.block_size_y = 256
    cfg.enable_kernel_fusion = true
}

func (kernel_config* cfg) enable_all_backends() {
    cfg.enable_triton_kernels = true
    cfg.enable_cutlass_kernels = true
    cfg.enable_vllm_kernels = true
}
