package neurx.train.parallel

use neurx.distributed.comm
use neurx.distributed.ddp
use neurx.distributed.tp
use neurx.distributed.tp_collective
use neurx.distributed.zero

struct train_parallel_state {
    process_group_state pg
    tp_state tp
    tp_collective_state collective
    ddp_state ddp
    zero_state zero
}

func new_train_parallel_state(string backend, int world_size, int rank, int shard_dim) train_parallel_state {
    process_group_state pg = new_process_group(backend, rank, world_size)
    tp_state tp = new_tp_state(world_size, rank, shard_dim)
    tp_collective_state collective = new_tp_collective_state(tp, pg)
    ddp_state ddp = new_ddp_state("train_ddp", 256, false)
    zero_state zero = new_zero_state("train_zero", backend, world_size, rank, shard_dim, 256, "zero-2")
    train_parallel_state {
        pg: pg,
        tp: tp,
        collective: collective,
        ddp: ddp,
        zero: zero,
    }
}

func train_parallel_all_reduce_grad(train_parallel_state state, []float grads) []float {
    tp_all_reduce_sum(state.collective, grads)
}

func train_parallel_reduce_scatter_grad(train_parallel_state state, []float grads) []float {
    zero_reduce_scatter_grads(state.zero, grads)
}

func train_parallel_all_gather_activation(train_parallel_state state, []float activations) []float {
    tp_all_gather(state.collective, activations)
}

func train_parallel_all_gather_params(train_parallel_state state, []float params) []float {
    zero_all_gather_params(state.zero, params)
}

func train_parallel_enabled(train_parallel_state state) bool {
    tp_enabled(state.tp)
}

func train_parallel_zero_enabled(train_parallel_state state) bool {
    zero_enabled(state.zero)
}

func train_parallel_optimizer_sharded(train_parallel_state state) bool {
    zero_optimizer_sharded(state.zero)
}

func train_parallel_world_size(train_parallel_state state) int {
    state.tp.world_size
}

func train_parallel_state_dict(train_parallel_state state) train_parallel_state {
    train_parallel_state {
        pg: process_group_state_dict(state.pg),
        tp: tp_state_dict(state.tp),
        collective: tp_collective_state_dict(state.collective),
        ddp: ddp_state_dict(state.ddp),
        zero: zero_state_dict(state.zero),
    }
}

func train_parallel_load_state_dict(train_parallel_state state, train_parallel_state other) train_parallel_state {
    train_parallel_state {
        pg: process_group_load_state_dict(state.pg, other.pg),
        tp: tp_load_state_dict(state.tp, other.tp),
        collective: tp_collective_load_state_dict(state.collective, other.collective),
        ddp: ddp_load_state_dict(state.ddp, other.ddp),
        zero: zero_load_state_dict(state.zero, other.zero),
    }
}

func train_parallel_register_param(train_parallel_state state, string param_name, int size) train_parallel_state {
    train_parallel_state {
        pg: process_group_state_dict(state.pg),
        tp: tp_state_dict(state.tp),
        collective: tp_collective_state_dict(state.collective),
        ddp: ddp_add_param(state.ddp, param_name, size),
        zero: zero_add_param(state.zero, param_name, size),
    }
}

func train_parallel_mark_grad_ready(train_parallel_state state, string param_name) train_parallel_state {
    train_parallel_state {
        pg: process_group_state_dict(state.pg),
        tp: tp_state_dict(state.tp),
        collective: tp_collective_state_dict(state.collective),
        ddp: ddp_mark_grad_ready(state.ddp, param_name),
        zero: zero_mark_grad_ready(state.zero, param_name),
    }
}

func train_parallel_finalize_step(train_parallel_state state) train_parallel_state {
    train_parallel_state {
        pg: process_group_state_dict(state.pg),
        tp: tp_state_dict(state.tp),
        collective: tp_collective_state_dict(state.collective),
        ddp: ddp_finalize_step(state.ddp),
        zero: zero_finalize_step(state.zero),
    }
}

func train_parallel_state_ddp(train_parallel_state state) ddp_state {
    state.ddp
}

func train_parallel_state_zero(train_parallel_state state) zero_state {
    state.zero
}
