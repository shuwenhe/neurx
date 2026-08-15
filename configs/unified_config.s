package config

import "core"

type model_config struct {
    model_id              string
    model_path            string
    model_name            string
    model_type            string
    hidden_size           int32
    num_hidden_layers      int32
    num_attention_heads    int32
    num_kv_heads           int32
    vocab_size            int32
    intermediate_size     int32
    max_position_embeddings int32
    init_method           string
    layer_norm_eps         float32
    rms_norm_eps           float32
    dtype                string
    torch_dtype           string
    use_logits_all_gather   bool
    use_aligned_input_ids   bool
    eos_token_id           int32
    pad_token_id           int32
}

type attention_config struct {
    attention_type        string
    backend_impl           string
    use_flash_attn         bool
    use_paged_attention    bool
    use_encoder_decoder    bool
    use_sdpa              bool
    use_xformers          bool
    use_custom_attn        bool
    attention_dropout     float32
}

type quantization_config struct {
    quantization         string
    group_size            int32
    symmetric_quant       bool
    aweight              bool
    weight_symmetric      bool
    weight_asymmetric     bool
    output_tokenization   bool
    token_wise_lsq         bool
    lsq_finetuning        bool
    calibration_data_type  string
}

type parallel_config struct {
    tensor_parallel_size   int32
    pipeline_parallel_size int32
    data_parallel_size     int32
    expert_parallel_size   int32
    disable_custom_all_gather bool
    disable_custom_all_reduce bool
    local_rank_zero        bool
    tensor_parallel_rank   int32
    pipeline_parallel_rank int32
    data_parallel_rank     int32
}

type scheduler_config struct {
    max_batch_size         int32
    max_num_seqs           int32
    max_num_tokens         int32
    max_num_tokens_list     []int32
    max_log_probs          int32
    prefill_batch_size     int32
    decode_batch_size      int32
    continuous_batching   bool
    disaggregated_prefill_decode bool
}

type cache_config struct {
    block_size            int32
    cpu_cache_size         int32
    gpu_cache_size         int32
    cache_dtype           string
    num_cpu_blocks         int32
    num_gpu_blocks         int32
    use_paged_attention    bool
    enable_prefix_cache    bool
    blocks_per_sequence    int32
}

type lora_config struct {
    max_lora_modules       int32
    max_lora_dim           int32
    lora_max_slots         int32
    lora_num_query_heads    int32
    lora_num_gqa_heads      int32
    lora_head_size         int32
    dtype                string
    torch_dtype           string
}

type multimodal_config struct {
    max_multimodal_tokens  int32
    patch_tokens_per_image  int32
    max_tokens_per_image    int32
    encoding_budget       int32
    weights_budget        int32
    depth_budget          int32
    vit_patch_size         int32
    image_norm_shape       []int32
    enable_image_feed      bool
    max_image_shape       []int32
    max_video_shape       []int32
}

type device_config struct {
    device_type           string
    device_id             int32
    cuda_devices          []int32
    ray_worker_use_colocated_pg bool
    ray_extra_resources_per_worker map[string]float32
    tensor_parallel_devices []int32
    pipeline_parallel_devices [][]int32
}

type speculative_config struct {
    spec_method           string
    num_speculative_tokens int32
    speculative_model    string
    best_of_n              int32
    mlp_type              string
}

type tracing_config struct {
    tracing_enabled       bool
    tracing_dir           string
    tracing_level         string
}

type profiler_config struct {
    enable_profiler       bool
    profiler_interval     int32
    profiler_output_dir    string
}

type config struct {
    model                model_config
    attention            attention_config
    quantization         quantization_config
    parallel             parallel_config
    scheduler            scheduler_config
    cache                cache_config
    lora                 lora_config
    multimodal           multimodal_config
    device               device_config
    speculative          speculative_config
    tracing              tracing_config
    profiler             profiler_config
}

func new_model_config() model_config {
    return model_config{
        hidden_size:           4096,
        num_hidden_layers:      32,
        num_attention_heads:    32,
        num_kv_heads:           8,
        vocab_size:            128000,
        intermediate_size:     14336,
        max_position_embeddings: 8192,
        layer_norm_eps:         1e-6,
        rms_norm_eps:           1e-6,
        dtype:                "bfloat16",
        torch_dtype:           "torch.bfloat16",
        use_logits_all_gather:   false,
        use_aligned_input_ids:   false,
        eos_token_id:           151645,
        pad_token_id:           151643,
    }
}

func new_attention_config() attention_config {
    return attention_config{
        attention_type:     "auto",
        backend_impl:        "auto",
        use_flash_attn:      true,
        use_paged_attention: true,
        use_encoder_decoder: false,
        use_sdpa:           false,
        use_xformers:       false,
        use_custom_attn:     false,
        attention_dropout:  0.0,
    }
}

func new_quantization_config() quantization_config {
    return quantization_config{
        quantization:        "none",
        group_size:           128,
        symmetric_quant:      true,
        aweight:             false,
        weight_symmetric:     true,
        weight_asymmetric:    false,
        output_tokenization: false,
        token_wise_lsq:        false,
        lsq_finetuning:       false,
        calibration_data_type: "float32",
    }
}

func new_parallel_config() parallel_config {
    return parallel_config{
        tensor_parallel_size:   1,
        pipeline_parallel_size: 1,
        data_parallel_size:     1,
        expert_parallel_size:   1,
        disable_custom_all_gather: false,
        disable_custom_all_reduce: false,
        local_rank_zero:        true,
        tensor_parallel_rank:   0,
        pipeline_parallel_rank: 0,
        data_parallel_rank:     0,
    }
}

func new_scheduler_config() scheduler_config {
    return scheduler_config{
        max_batch_size:       256,
        max_num_seqs:         256,
        max_num_tokens:       8192,
        max_num_tokens_list:   []int32{8192, 16384},
        max_log_probs:        0,
        prefill_batch_size:   64,
        decode_batch_size:    256,
        continuous_batching: true,
        disaggregated_prefill_decode: false,
    }
}

func new_cache_config() cache_config {
    return cache_config{
        block_size:           16,
        cpu_cache_size:        0,
        gpu_cache_size:        4,
        cache_dtype:          "bfloat16",
        num_cpu_blocks:        0,
        num_gpu_blocks:        2048,
        use_paged_attention:   true,
        enable_prefix_cache:   false,
        blocks_per_sequence:   256,
    }
}

func new_lora_config() lora_config {
    return lora_config{
        max_lora_modules:   64,
        max_lora_dim:       16,
        lora_max_slots:     2,
        lora_num_query_heads: 32,
        lora_num_gqa_heads:   8,
        lora_head_size:      128,
        dtype:             "bfloat16",
        torch_dtype:        "torch.bfloat16",
    }
}

func new_multimodal_config() multimodal_config {
    return multimodal_config{
        max_multimodal_tokens: 32000,
        patch_tokens_per_image: 576,
        max_tokens_per_image:   2048,
        encoding_budget:      4096,
        weights_budget:       20000,
        depth_budget:         2000,
        vit_patch_size:        14,
        image_norm_shape:      []int32{3, 224, 224},
        enable_image_feed:     false,
        max_image_shape:       []int32{2048, 2048},
        max_video_shape:       []int32{1080, 1920},
    }
}

func new_device_config() device_config {
    return device_config{
        device_type:        "cuda",
        device_id:          0,
        cuda_devices:       []int32{0},
        ray_worker_use_colocated_pg: true,
        ray_extra_resources_per_worker: make(map[string]float32),
        tensor_parallel_devices: []int32{0},
        pipeline_parallel_devices: [][]int32{{0}},
    }
}

func new_speculative_config() speculative_config {
    return speculative_config{
        spec_method:           "none",
        num_speculative_tokens: 0,
        speculative_model:     "",
        best_of_n:              0,
        mlp_type:              "mlp",
    }
}

func new_tracing_config() tracing_config {
    return tracing_config{
        tracing_enabled: false,
        tracing_dir:     "/tmp/vllm_trace",
        tracing_level:   "INFO",
    }
}

func new_profiler_config() profiler_config {
    return profiler_config{
        enable_profiler:     false,
        profiler_interval:   1000,
        profiler_output_dir:  "/tmp/vllm_profile",
    }
}

func new_config() config {
    return config{
        model:       new_model_config(),
        attention:   new_attention_config(),
        quantization: new_quantization_config(),
        parallel:    new_parallel_config(),
        scheduler:   new_scheduler_config(),
        cache:       new_cache_config(),
        lora:        new_lora_config(),
        multimodal:  new_multimodal_config(),
        device:      new_device_config(),
        speculative: new_speculative_config(),
        tracing:     new_tracing_config(),
        profiler:    new_profiler_config(),
    }
}

func (c *config) validate() error {
    if c.model.hidden_size <= 0 {
        return core.Errorf("hidden_size must be positive")
    }
    if c.model.num_hidden_layers <= 0 {
        return core.Errorf("num_hidden_layers must be positive")
    }
    if c.parallel.tensor_parallel_size <= 0 {
        return core.Errorf("tensor_parallel_size must be positive")
    }
    if c.scheduler.max_batch_size <= 0 {
        return core.Errorf("max_batch_size must be positive")
    }
    if c.cache.block_size <= 0 {
        return core.Errorf("block_size must be positive")
    }
    return nil
}

func (c *config) to_map() map[string]interface{} {
    result := make(map[string]interface{})
    result["model"] = c.model
    result["attention"] = c.attention
    result["quantization"] = c.quantization
    result["parallel"] = c.parallel
    result["scheduler"] = c.scheduler
    result["cache"] = c.cache
    result["lora"] = c.lora
    result["multimodal"] = c.multimodal
    result["device"] = c.device
    result["speculative"] = c.speculative
    result["tracing"] = c.tracing
    result["profiler"] = c.profiler
    return result
}
