package neurx.posttrain.backend.megatron
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}
use neurx.distributed.{distributed_context}
struct megatron_config {
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    bool use_sequence_parallel
    bool use_selective_recompute
    int num_layers_per_pipeline_stage
    string position_embedding_type
    bool use_flash_attention
    int micro_batch_size
    int global_batch_size
    bool use_distributed_optimizer
}

struct tensor_parallel_state {
    int tp_rank
    int tp_world_size
    []int tp_group_ranks
    distributed_context tp_ctx
}

struct pipeline_parallel_state {
    int pp_rank
    int pp_world_size
    []int pp_group_ranks
    distributed_context pp_ctx
    int num_microbatches
}

struct megatron_module {
    module base_module
    megatron_config config
    tensor_parallel_state tp_state
    pipeline_parallel_state pp_state
    distributed_context global_ctx
}

func new_megatron_config() megatron_config {
    megatron_config {
        tensor_parallel_size: 1,
        pipeline_parallel_size: 1,
        data_parallel_size: 1,
        use_sequence_parallel: false,
        use_selective_recompute: true,
        num_layers_per_pipeline_stage: 24,
        position_embedding_type: "rope",
        use_flash_attention: true,
        micro_batch_size: 1,
        global_batch_size: 8,
        use_distributed_optimizer: true,
    }
}

func megatron_column_parallel_linear(
    tensor input,
    tensor weight,
    tensor_parallel_state tp_state
) tensor {
    int hidden_size = weight.shape[0]
    int output_size = weight.shape[1]
    int tp_size = tp_state.tp_world_size
    int rank = tp_state.tp_rank
    int shard_size = output_size / tp_size
    int start = rank * shard_size
    int end = start + shard_size
    tensor weight_shard = tensor_ops.slice(weight, 1, start, end)
    tensor output_shard = tensor_ops.matmul(input, weight_shard)
    output_shard
}

func megatron_row_parallel_linear(
    tensor input,
    tensor weight,
    tensor_parallel_state tp_state
) tensor {
    int hidden_size = weight.shape[0]
    int output_size = weight.shape[1]
    int tp_size = tp_state.tp_world_size
    int rank = tp_state.tp_rank
    int shard_size = hidden_size / tp_size
    int start = rank * shard_size
    int end = start + shard_size
    tensor weight_shard = tensor_ops.slice(weight, 0, start, end)
    tensor input_shard = tensor_ops.slice(input, -1, start, end)
    tensor output_shard = tensor_ops.matmul(input_shard, weight_shard)
    tensor output = tp_state.tp_ctx.all_reduce(output_shard)
    output
}

func megatron_attention_with_tp(
    tensor query,
    tensor key,
    tensor value,
    tensor_parallel_state tp_state
) tensor {
    int batch_size = query.shape[0]
    int seq_len = query.shape[1]
    int num_heads = query.shape[2]
    int head_dim = query.shape[3]
    int tp_size = tp_state.tp_world_size
    int rank = tp_state.tp_rank
    int heads_per_rank = num_heads / tp_size
    int head_start = rank * heads_per_rank
    int head_end = head_start + heads_per_rank
    tensor q_local = tensor_ops.slice(query, 2, head_start, head_end)
    tensor k_local = tensor_ops.slice(key, 2, head_start, head_end)
    tensor v_local = tensor_ops.slice(value, 2, head_start, head_end)
    tensor scores = tensor_ops.matmul(
        q_local,
        tensor_ops.transpose(k_local, -2, -1)
    )
    float scale = 1.0 / (head_dim * 1.0)
    scores = tensor_ops.mul_scalar(scores, scale)
    tensor attn_weights = tensor_ops.softmax(scores, -1)
    tensor output_local = tensor_ops.matmul(attn_weights, v_local)
    output_local
}

func megatron_pipeline_forward(
    megatron_module meg_mod,
    tensor input
) tensor {
    pipeline_parallel_state pp_state = meg_mod.pp_state
    if pp_state.pp_rank == 0 {
        tensor output = meg_mod.base_module.forward(input)
        if pp_state.pp_world_size > 1 {
            pp_state.pp_ctx.send_to_next_rank(output)
        }
        return output
    } else if pp_state.pp_rank == pp_state.pp_world_size - 1 {
        tensor received = pp_state.pp_ctx.recv_from_prev_rank()
        tensor output = meg_mod.base_module.forward(received)
        return output
    } else {
        tensor received = pp_state.pp_ctx.recv_from_prev_rank()
        tensor output = meg_mod.base_module.forward(received)
        pp_state.pp_ctx.send_to_next_rank(output)
        return output
    }
}

func megatron_sequence_parallel_forward(
    tensor input,
    tensor_parallel_state tp_state
) tensor {
    int batch_size = input.shape[0]
    int seq_len = input.shape[1]
    int hidden_dim = input.shape[2]
    int tp_size = tp_state.tp_world_size
    int rank = tp_state.tp_rank
    int tokens_per_rank = seq_len / tp_size
    int seq_start = rank * tokens_per_rank
    int seq_end = seq_start + tokens_per_rank
    tensor input_shard = tensor_ops.slice(input, 1, seq_start, seq_end)
    input_shard
}

func new_megatron_module(
    module base_module,
    megatron_config config,
    distributed_context global_ctx
) megatron_module {
    tensor_parallel_state tp_state = tensor_parallel_state {
        tp_rank: global_ctx.rank % config.tensor_parallel_size,
        tp_world_size: config.tensor_parallel_size,
        tp_group_ranks: []int{},
        tp_ctx: global_ctx,
    }
    pipeline_parallel_state pp_state = pipeline_parallel_state {
        pp_rank: global_ctx.rank / config.tensor_parallel_size,
        pp_world_size: config.pipeline_parallel_size,
        pp_group_ranks: []int{},
        pp_ctx: global_ctx,
        num_microbatches: config.global_batch_size / config.micro_batch_size,
    }
    megatron_module {
        base_module: base_module,
        config: config,
        tp_state: tp_state,
        pp_state: pp_state,
        global_ctx: global_ctx,
    }
}
