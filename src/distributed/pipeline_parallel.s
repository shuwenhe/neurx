package neurx.distributed.pipeline_parallel

use std.vec.vec
use neurx.device.abi
use neurx.model.transformer_block
use neurx.distributed.nccl_comm

struct pipeline_stage_config {
    int stage_id
    int num_stages
    int blocks_per_stage
    int start_block
    int end_block
}

struct activation_cache {
    vec[abi.device_tensor] activations
    vec[int] stage_ids
    int max_cache_size
    int current_size
}

struct pipeline_batch {
    vec[int] input_ids
    int batch_size
    int seq_len
    int microbatch_idx
    int num_microbatches
}

pipeline_stage_config g_pp_config
activation_cache g_activation_cache

func pipeline_parallel_init(
    stage_id: int,
    num_stages: int,
    total_blocks: int
) (bool, string) {
    if stage_id < 0 || stage_id >= num_stages {
        return false, "Invalid stage_id"
    }

    if num_stages <= 0 || total_blocks <= 0 {
        return false, "Invalid num_stages or total_blocks"
    }

    if total_blocks < num_stages {
        return false, "Total blocks less than num_stages"
    }

    blocks_per_stage := total_blocks / num_stages
    start_block := stage_id * blocks_per_stage
    end_block := start_block + blocks_per_stage

    if stage_id == num_stages - 1 {
        end_block = total_blocks
    }

    g_pp_config = pipeline_stage_config {
        stage_id: stage_id,
        num_stages: num_stages,
        blocks_per_stage: blocks_per_stage,
        start_block: start_block,
        end_block: end_block,
    }

    g_activation_cache = activation_cache {
        activations: vec[abi.device_tensor](),
        stage_ids: vec[int](),
        max_cache_size: 100,
        current_size: 0,
    }

    return true, ""
}

func compute_stage_forward(
    input_tensor: abi.device_tensor,
    stage_weights: vec[transformer_block.transformer_block_weights]
) (abi.device_tensor, bool, string) {
    if input_tensor.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid input"
    }

    if stage_weights.len() <= 0 {
        return abi.device_tensor{}, false, "No weights for stage"
    }

    hidden_states := input_tensor

    for block_idx := 0; block_idx < stage_weights.len(); block_idx = block_idx + 1 {
        kv_cache, cache_success, cache_err := transformer_block.kv_cache_init(32, 128, 2048)
        if !cache_success {
            return abi.device_tensor{}, false, "KV cache init failed: " + cache_err
        }

        output, block_success, block_err := transformer_block.transformer_block_forward(hidden_states, stage_weights[block_idx], kv_cache)
        if !block_success {
            return abi.device_tensor{}, false, "Block forward failed: " + block_err
        }

        hidden_states = output
    }

    return hidden_states, true, ""
}

func send_activation_to_next_stage(
    activation: abi.device_tensor,
    next_stage: int
) (bool, string) {
    if activation.element_count <= 0 {
        return false, "Invalid activation"
    }

    if next_stage < 0 {
        return false, "Invalid next_stage"
    }

    return true, ""
}

func recv_activation_from_prev_stage(
    prev_stage: int
) (abi.device_tensor, bool, string) {
    if prev_stage < 0 {
        return abi.device_tensor{}, false, "Invalid prev_stage"
    }

    dummy_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    return dummy_tensor, true, ""
}

func cache_activation(
    activation: abi.device_tensor,
    stage_id: int
) (bool, string) {
    if activation.element_count <= 0 {
        return false, "Invalid activation"
    }

    if g_activation_cache.current_size >= g_activation_cache.max_cache_size {
        return false, "Activation cache full"
    }

    g_activation_cache.activations.push(activation)
    g_activation_cache.stage_ids.push(stage_id)
    g_activation_cache.current_size = g_activation_cache.current_size + 1

    return true, ""
}

func get_cached_activation(
    cache_idx: int
) (abi.device_tensor, bool, string) {
    if cache_idx < 0 || cache_idx >= g_activation_cache.current_size {
        return abi.device_tensor{}, false, "Invalid cache index"
    }

    return g_activation_cache.activations[cache_idx], true, ""
}

func clear_activation_cache() (bool, string) {
    g_activation_cache.activations = vec[abi.device_tensor]()
    g_activation_cache.stage_ids = vec[int]()
    g_activation_cache.current_size = 0

    return true, ""
}

func microbatch_pipeline_forward(
    input_ids: vec[int],
    num_microbatches: int,
    num_stages: int
) (abi.device_tensor, bool, string) {
    if input_ids.len() <= 0 {
        return abi.device_tensor{}, false, "Empty input"
    }

    if num_microbatches <= 0 {
        return abi.device_tensor{}, false, "Invalid num_microbatches"
    }

    dummy_output := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(input_ids.len() * 32000),
        ref_count: 1,
        is_view: false,
    }

    return dummy_output, true, ""
}

func get_pipeline_config() (pipeline_stage_config, bool, string) {
    if g_pp_config.num_stages <= 0 {
        return pipeline_stage_config{}, false, "PP not initialized"
    }

    return g_pp_config, true, ""
}

func synchronize_stages() (bool, string) {
    return true, ""
}
