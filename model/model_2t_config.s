package neurx.model
struct model_2t_config {
    int vocab_size
    int hidden_dim
    int num_layers
    int num_attention_heads
    int num_kv_heads
    int intermediate_dim
    int max_seq_len
    double layer_norm_eps
    double attention_dropout
    double residual_dropout
    string position_embedding
    double rope_base
    double rope_scaling
    string activation
    string norm_type
    bool pre_norm
    bool use_bias
}
func new_2t_model_config() model_2t_config {
    model_2t_config cfg
    cfg.vocab_size = 100000
    cfg.hidden_dim = 16384
    cfg.num_layers = 160
    cfg.num_attention_heads = 128
    cfg.num_kv_heads = 32
    cfg.intermediate_dim = 65536
    cfg.max_seq_len = 8192
    cfg.layer_norm_eps = 1e-6
    cfg.attention_dropout = 0.1
    cfg.residual_dropout = 0.1
    cfg.position_embedding = "rope"
    cfg.rope_base = 10000.0
    cfg.rope_scaling = 1.0
    cfg.activation = "swiglu"
    cfg.norm_type = "rmsnorm"
    cfg.pre_norm = true
    cfg.use_bias = false
    return cfg
}

func calculate_2t_model_parameters(model_2t_config cfg) int {
    int embedding_params = cfg.vocab_size * cfg.hidden_dim
    int per_layer_params = 0
    int qkv_params = cfg.hidden_dim * (cfg.hidden_dim + (cfg.num_kv_heads * cfg.hidden_dim / cfg.num_attention_heads) * 2)
    int out_proj_params = cfg.hidden_dim * cfg.hidden_dim
    int attention_params = qkv_params + out_proj_params
    int ffn_gate_params = cfg.hidden_dim * cfg.intermediate_dim
    int ffn_value_params = cfg.hidden_dim * cfg.intermediate_dim
    int ffn_out_params = cfg.intermediate_dim * cfg.hidden_dim
    int ffn_params = ffn_gate_params + ffn_value_params + ffn_out_params
    int norm_params = cfg.hidden_dim * 3
    per_layer_params = attention_params + ffn_params + norm_params
    int total_params = embedding_params + per_layer_params * cfg.num_layers
    int output_params = cfg.hidden_dim * cfg.vocab_size
    total_params = total_params + output_params
    return total_params
}

func verify_2t_size(model_2t_config cfg) {
    int params = calculate_2t_model_parameters(cfg)
    int lower_bound = 1900000000000
    int upper_bound = 2100000000000
    if params >= lower_bound && params <= upper_bound {
    }
}

struct memory_requirements_2t {
    double model_size_gb
    double gradient_size_gb
    double optimizer_size_gb
    double activation_size_gb
    double total_without_optimization_gb
    double total_with_zero_3_gb
    double total_with_gradient_ckpt_gb
}

func calculate_2t_memory_requirements(
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_layers,
    int vocab_size,
    int num_gpus,
    bool use_gradient_checkpointing,
    bool use_zero_3) memory_requirements_2t {
    memory_requirements_2t mem
    mem.model_size_gb = 2000000.0 * 2.0 / 1024.0
    mem.gradient_size_gb = mem.model_size_gb
    mem.optimizer_size_gb = mem.model_size_gb * 4.0
    double per_layer_activation = double(batch_size) * double(seq_len) * double(hidden_dim) * 2.0 / 1024.0 / 1024.0
    if use_gradient_checkpointing {
        mem.activation_size_gb = per_layer_activation
    } else {
        mem.activation_size_gb = per_layer_activation * double(num_layers)
    }
    mem.total_without_optimization_gb = mem.model_size_gb + mem.gradient_size_gb + mem.optimizer_size_gb + mem.activation_size_gb
    if use_zero_3 {
        mem.total_with_zero_3_gb = (mem.model_size_gb + mem.gradient_size_gb + mem.optimizer_size_gb) / double(num_gpus) + mem.activation_size_gb
    }
    if use_gradient_checkpointing {
        mem.total_with_gradient_ckpt_gb = (mem.model_size_gb + mem.gradient_size_gb + mem.optimizer_size_gb) / double(num_gpus) + per_layer_activation
    }
    return mem
}

struct communication_requirements_2t {
    double all_reduce_bytes
    double all_to_all_bytes
    double reduce_scatter_bytes
    double all_gather_bytes
    double total_bytes_per_step
    double total_gb_per_epoch
}

func calculate_2t_communication_volume(
    int num_gpus,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_steps_per_epoch,
    bool use_tensor_parallel,
    bool use_sequence_parallel,
    bool use_zero_3) communication_requirements_2t {
    communication_requirements_2t comm
    comm.all_reduce_bytes = 2000000.0 * 2.0 * 2.0 * 1024.0 * 1024.0
    if use_sequence_parallel {
        comm.all_to_all_bytes = double(batch_size) * double(seq_len) * double(hidden_dim) * 2.0 * 1024.0 * 1024.0
    }
    if use_zero_3 {
        comm.reduce_scatter_bytes = comm.all_reduce_bytes
        comm.all_gather_bytes = 2000000.0 * 2.0 * 1024.0 * 1024.0
    }
    comm.total_bytes_per_step = comm.all_reduce_bytes + comm.all_to_all_bytes + comm.reduce_scatter_bytes
    comm.total_gb_per_epoch = comm.total_bytes_per_step * double(num_steps_per_epoch) / (1024.0 * 1024.0 * 1024.0)
    return comm
}

struct training_time_estimate_2t {
    double flops_per_token
    double peak_throughput_tokens_sec
    double actual_throughput_tokens_sec
    double time_per_epoch_hours
    double time_for_1t_tokens_hours
    double communication_overhead_percent
}

func estimate_2t_training_time(
    int num_gpus,
    string gpu_type,
    double gpu_peak_flops_per_sec,
    int tokens_per_step,
    int num_steps_per_epoch,
    double communication_efficiency) training_time_estimate_2t {
    training_time_estimate_2t estimate
    double flops_per_token = 0.0
    double peak_throughput = 0.0
    double actual_throughput = 0.0
    double tokens_per_epoch = 0.0
    double time_per_epoch_hours = 0.0
    double time_for_1t_tokens_hours = 0.0
    tokens_per_epoch = double(tokens_per_step * num_steps_per_epoch)
    estimate.flops_per_token = flops_per_token
    estimate.peak_throughput_tokens_sec = peak_throughput
    estimate.actual_throughput_tokens_sec = actual_throughput
    estimate.time_per_epoch_hours = time_per_epoch_hours
    estimate.time_for_1t_tokens_hours = time_for_1t_tokens_hours
    estimate.communication_overhead_percent = 0.0
    estimate
}

struct recommended_2t_training_setup {
    int num_gpus
    int tensor_parallel_degree
    int pipeline_parallel_degree
    int data_parallel_degree
    int sequence_parallel_degree
    int zero_stage
    int batch_size
    int micro_batch_size
    int seq_len
    double learning_rate
    int warmup_steps
    int total_steps
}

func recommended_2t_setup_256_gpus() recommended_2t_training_setup {
    recommended_2t_training_setup setup
    setup.num_gpus = 256
    setup.tensor_parallel_degree = 16
    setup.pipeline_parallel_degree = 8
    setup.data_parallel_degree = 2
    setup.sequence_parallel_degree = 4
    setup.zero_stage = 3
    setup.batch_size = 2048
    setup.micro_batch_size = 4
    setup.seq_len = 8192
    setup.learning_rate = 2e-4
    setup.warmup_steps = 10000
    setup.total_steps = 1000000
    return setup
}

func recommended_2t_ultra_setup_512_gpus() recommended_2t_training_setup {
    recommended_2t_training_setup setup
    setup.num_gpus = 512
    setup.tensor_parallel_degree = 32
    setup.pipeline_parallel_degree = 16
    setup.data_parallel_degree = 1
    setup.sequence_parallel_degree = 4
    setup.zero_stage = 3
    setup.batch_size = 2048
    setup.micro_batch_size = 2
    setup.seq_len = 8192
    setup.learning_rate = 2e-4
    setup.warmup_steps = 20000
    setup.total_steps = 1000000
    return setup
}

func print_2t_model_specification(model_2t_config cfg) {
}
