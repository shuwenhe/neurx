package config

type parallel_mode int32

const (
    parallel_tensor_parallel    parallel_mode = iota
    parallel_pipeline_parallel
    parallel_data_parallel
    parallel_expert_parallel
    parallel_context_parallel
)

struct parallel_config {
    int32 world_size
    int32 local_rank
    int32 global_rank
    
    int32 tensor_parallel_size
    int32 pipeline_parallel_size
    int32 data_parallel_size
    int32 expert_parallel_size
    int32 context_parallel_size
    
    bool enable_tensor_parallel
    bool enable_pipeline_parallel
    bool enable_data_parallel
    bool enable_expert_parallel
    bool enable_context_parallel
    
    string communication_backend
    bool enable_overlap_communication
    
    bool enable_zero
    int32 zero_stage
    
    bool enable_gradient_accumulation
    int32 gradient_accumulation_steps
    
    map[string]interface{} extra_config
}

func create_default_parallel_config() parallel_config {
    return parallel_config{
        world_size: 1,
        local_rank: 0,
        global_rank: 0,
        tensor_parallel_size: 1,
        pipeline_parallel_size: 1,
        data_parallel_size: 1,
        expert_parallel_size: 1,
        context_parallel_size: 1,
        enable_tensor_parallel: false,
        enable_pipeline_parallel: false,
        enable_data_parallel: false,
        enable_expert_parallel: false,
        enable_context_parallel: false,
        communication_backend: "nccl",
        enable_overlap_communication: true,
        enable_zero: false,
        zero_stage: 0,
        enable_gradient_accumulation: false,
        gradient_accumulation_steps: 1,
        extra_config: make(map[string]interface{}),
    }
}

func (parallel_config* cfg) validate() bool {
    if cfg.world_size <= 0 {
        return false
    }
    if cfg.tensor_parallel_size * cfg.pipeline_parallel_size * cfg.data_parallel_size > cfg.world_size {
        return false
    }
    if cfg.zero_stage < 0 || cfg.zero_stage > 3 {
        return false
    }
    return true
}

func (parallel_config* cfg) get_total_parallel_degree() int32 {
    return cfg.tensor_parallel_size * cfg.pipeline_parallel_size * cfg.data_parallel_size
}

func (parallel_config* cfg) is_distributed() bool {
    return cfg.world_size > 1
}

func (parallel_config* cfg) enable_all_parallelism() {
    cfg.enable_tensor_parallel = true
    cfg.enable_pipeline_parallel = true
    cfg.enable_data_parallel = true
}

func (parallel_config* cfg) disable_all_parallelism() {
    cfg.enable_tensor_parallel = false
    cfg.enable_pipeline_parallel = false
    cfg.enable_data_parallel = false
    cfg.enable_expert_parallel = false
}
