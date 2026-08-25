package neurx.posttrain.advanced.hybrid_engine
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}
use neurx.distributed.{distributed_context}

struct hybrid_engine_config {
    int tensor_parallel_size_train
    int tensor_parallel_size_gen
    int pipeline_parallel_size_train
    int pipeline_parallel_size_gen
    int data_parallel_size
    bool overlap_comm_comp
    bool use_zero_redundancy_optimizer
    int resharding_buffer_size
}

struct model_partition {
    []tensor params
    int tp_rank
    int pp_rank
    int dp_rank
    string mode
}

struct resharding_plan {
    []int src_ranks
    []int dst_ranks
    []int param_indices
    []int sizes
    bool use_alltoall
}

struct hybrid_engine {
    module model
    hybrid_engine_config config
    model_partition train_partition
    model_partition gen_partition
    distributed_context ctx
    resharding_plan plan
}

func new_hybrid_engine_config() hybrid_engine_config {
    hybrid_engine_config {
        tensor_parallel_size_train: 8,
        tensor_parallel_size_gen: 4,
        pipeline_parallel_size_train: 4,
        pipeline_parallel_size_gen: 1,
        data_parallel_size: 1,
        overlap_comm_comp: true,
        use_zero_redundancy_optimizer: true,
        resharding_buffer_size: 1024 * 1024 * 1024,
    }
}

func compute_resharding_plan(
    model_partition src,
    model_partition dst,
    hybrid_engine_config config
) resharding_plan {
    int src_tp = config.tensor_parallel_size_train
    int dst_tp = config.tensor_parallel_size_gen
    []int src_ranks = []int{}
    []int dst_ranks = []int{}
    []int param_indices = []int{}
    []int sizes = []int{}
    int i = 0
    for i < src.params.len {
        tensor param = src.params[i]
        int src_rank_start = (i % src_tp) * (param.shape[0] / src_tp)
        int src_rank_end = src_rank_start + (param.shape[0] / src_tp)
        int dst_rank_start = (i % dst_tp) * (param.shape[0] / dst_tp)
        int dst_rank_end = dst_rank_start + (param.shape[0] / dst_tp)
        src_ranks[src_ranks.len] = src_rank_start
        dst_ranks[dst_ranks.len] = dst_rank_start
        param_indices[param_indices.len] = i
        sizes[sizes.len] = param.shape[0]
        i = i + 1
    }
    bool use_alltoall = src_tp != dst_tp
    resharding_plan {
        src_ranks: src_ranks,
        dst_ranks: dst_ranks,
        param_indices: param_indices,
        sizes: sizes,
        use_alltoall: use_alltoall,
    }
}

func execute_resharding(
    hybrid_engine engine,
    string target_mode
) {
    if target_mode == "train" {
        if engine.plan.use_alltoall {
            int i = 0
            for i < engine.gen_partition.params.len {
                tensor param = engine.gen_partition.params[i]
                tensor resharded = engine.ctx.all_to_all(
                    param,
                    engine.plan.src_ranks,
                    engine.plan.dst_ranks
                )
                engine.train_partition.params[i] = resharded
                i = i + 1
            }
        } else {
            int i = 0
            for i < engine.plan.param_indices.len {
                int param_idx = engine.plan.param_indices[i]
                int src_rank = engine.plan.src_ranks[i]
                int dst_rank = engine.plan.dst_ranks[i]
                if engine.ctx.rank == src_rank {
                    tensor param = engine.gen_partition.params[param_idx]
                    engine.ctx.send(param, dst_rank)
                }
                if engine.ctx.rank == dst_rank {
                    tensor param = engine.ctx.recv(src_rank)
                    engine.train_partition.params[param_idx] = param
                }
                i = i + 1
            }
        }
    } else if target_mode == "gen" {
        if engine.plan.use_alltoall {
            int i = 0
            for i < engine.train_partition.params.len {
                tensor param = engine.train_partition.params[i]
                tensor resharded = engine.ctx.all_to_all(
                    param,
                    engine.plan.dst_ranks,
                    engine.plan.src_ranks
                )
                engine.gen_partition.params[i] = resharded
                i = i + 1
            }
        } else {
            int i = 0
            for i < engine.plan.param_indices.len {
                int param_idx = engine.plan.param_indices[i]
                int src_rank = engine.plan.dst_ranks[i]
                int dst_rank = engine.plan.src_ranks[i]
                if engine.ctx.rank == src_rank {
                    tensor param = engine.train_partition.params[param_idx]
                    engine.ctx.send(param, dst_rank)
                }
                if engine.ctx.rank == dst_rank {
                    tensor param = engine.ctx.recv(src_rank)
                    engine.gen_partition.params[param_idx] = param
                }
                i = i + 1
            }
        }
    }
}

func hybrid_engine_switch_to_generation(hybrid_engine engine) {
    execute_resharding(engine, "gen")
    engine.model.load_parameters(engine.gen_partition.params)
}

func hybrid_engine_switch_to_training(hybrid_engine engine) {
    execute_resharding(engine, "train")
    engine.model.load_parameters(engine.train_partition.params)
}

func new_hybrid_engine(
    module model,
    hybrid_engine_config config,
    distributed_context ctx
) hybrid_engine {
    []tensor params = model.parameters()
    model_partition train_part = model_partition {
        params: params,
        tp_rank: ctx.rank % config.tensor_parallel_size_train,
        pp_rank: ctx.rank / config.tensor_parallel_size_train,
        dp_rank: 0,
        mode: "train",
    }
    model_partition gen_part = model_partition {
        params: []tensor{cap: params.len},
        tp_rank: ctx.rank % config.tensor_parallel_size_gen,
        pp_rank: 0,
        dp_rank: 0,
        mode: "gen",
    }
    resharding_plan plan = compute_resharding_plan(
        train_part,
        gen_part,
        config
    )
    hybrid_engine {
        model: model,
        config: config,
        train_partition: train_part,
        gen_partition: gen_part,
        ctx: ctx,
        plan: plan,
    }
}
