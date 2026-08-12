package neurx.distributed.megatron.interleaved_schedule
struct interleaved_config {
    int pipeline_parallel_size
    int pipeline_parallel_rank
    int num_model_chunks
    int num_microbatches
    int microbatch_group_size_per_vp_stage
    bool forward_only
}


struct interleaved_plan {
    int total_num_microbatches
    bool are_all_microbatches_in_warmup
    int num_warmup_microbatches
    int num_microbatches_remaining
}


struct schedule_op {
    string op_type
    int virtual_microbatch_id
    int model_chunk_id
    int microbatch_id
    bool is_forward
}


func compute_warmup_microbatches(interleaved_config config) interleaved_plan {
    int total_num_microbatches = config.num_microbatches * config.num_model_chunks
    bool all_in_warmup = false
    int num_warmup = 0
    if config.forward_only {
        num_warmup = total_num_microbatches
    } else {
        if config.pipeline_parallel_size > 1 {
            num_warmup = (config.pipeline_parallel_size - config.pipeline_parallel_rank - 1) * 2
            num_warmup = num_warmup + (config.num_model_chunks - 1) * config.microbatch_group_size_per_vp_stage
        } else {
            num_warmup = 0
        }
    }
    if num_warmup >= total_num_microbatches {
        num_warmup = total_num_microbatches
        all_in_warmup = true
    }
    int remaining = total_num_microbatches - num_warmup
    interleaved_plan {
        total_num_microbatches: total_num_microbatches,
        are_all_microbatches_in_warmup: all_in_warmup,
        num_warmup_microbatches: num_warmup,
        num_microbatches_remaining: remaining,
    }
}


func get_model_chunk_id(
    interleaved_config config,
    int virtual_microbatch_id,
    bool forward
) int {
    int group_size = config.microbatch_group_size_per_vp_stage
    int microbatch_group_size = group_size * config.num_model_chunks
    int microbatch_id_in_group = pp_mod(virtual_microbatch_id, microbatch_group_size)
    int model_chunk_id = microbatch_id_in_group / group_size
    if !forward {
        model_chunk_id = config.num_model_chunks - model_chunk_id - 1
    }
    return model_chunk_id
}


func get_microbatch_id_in_model_chunk(
    interleaved_config config,
    int virtual_microbatch_id
) int {
    int group_size = config.microbatch_group_size_per_vp_stage
    int microbatch_group_size = group_size * config.num_model_chunks
    int group_idx = virtual_microbatch_id / microbatch_group_size
    int microbatch_id_in_group = pp_mod(virtual_microbatch_id, group_size)
    return group_idx * group_size + microbatch_id_in_group
}


func build_interleaved_schedule(interleaved_config config) []schedule_op {
    interleaved_plan plan = compute_warmup_microbatches(config)
    []schedule_op ops = make([]schedule_op, 0)
    for int k = 0; k < plan.num_warmup_microbatches; k = k + 1 {
        int chunk_id = get_model_chunk_id(config, k, true)
        int mb_id = get_microbatch_id_in_model_chunk(config, k)
        schedule_op op = schedule_op {
            op_type: "forward",
            virtual_microbatch_id: k,
            model_chunk_id: chunk_id,
            microbatch_id: mb_id,
            is_forward: true,
        }
        ops = append(ops, op)
    }
    for int k = 0; k < plan.num_microbatches_remaining; k = k + 1 {
        int forward_k = k + plan.num_warmup_microbatches
        int fwd_chunk_id = get_model_chunk_id(config, forward_k, true)
        int fwd_mb_id = get_microbatch_id_in_model_chunk(config, forward_k)
        schedule_op fwd_op = schedule_op {
            op_type: "forward",
            virtual_microbatch_id: forward_k,
            model_chunk_id: fwd_chunk_id,
            microbatch_id: fwd_mb_id,
            is_forward: true,
        }
        ops = append(ops, fwd_op)
        int backward_k = k
        int bwd_chunk_id = get_model_chunk_id(config, backward_k, false)
        int bwd_mb_id = get_microbatch_id_in_model_chunk(config, backward_k)
        schedule_op bwd_op = schedule_op {
            op_type: "backward",
            virtual_microbatch_id: backward_k,
            model_chunk_id: bwd_chunk_id,
            microbatch_id: bwd_mb_id,
            is_forward: false,
        }
        ops = append(ops, bwd_op)
    }
    for int k = 0; k < plan.num_warmup_microbatches; k = k + 1 {
        int backward_k = k + plan.num_microbatches_remaining
        int bwd_chunk_id = get_model_chunk_id(config, backward_k, false)
        int bwd_mb_id = get_microbatch_id_in_model_chunk(config, backward_k)
        schedule_op bwd_op = schedule_op {
            op_type: "backward",
            virtual_microbatch_id: backward_k,
            model_chunk_id: bwd_chunk_id,
            microbatch_id: bwd_mb_id,
            is_forward: false,
        }
        ops = append(ops, bwd_op)
    }
    return ops
}


func pp_mod(int val, int div) int {
    int r = val - (val / div) * div
    if r < 0 {
        r = r + div
    }
    return r
}

