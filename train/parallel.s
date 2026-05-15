package neurx.train.parallel

use neurx.distributed.comm
use neurx.distributed.tp
use neurx.distributed.tp_collective

struct train_parallel_state {
    process_group_state pg
    tp_state tp
    tp_collective_state collective
}

func new_train_parallel_state(string backend, int world_size, int rank, int shard_dim) train_parallel_state {
    process_group_state pg = new_process_group(backend, rank, world_size)
    tp_state tp = new_tp_state(world_size, rank, shard_dim)
    tp_collective_state collective = new_tp_collective_state(tp, pg)
    train_parallel_state {
        pg: pg,
        tp: tp,
        collective: collective,
    }
}

func train_parallel_all_reduce_grad(train_parallel_state state, []float grads) []float {
    tp_all_reduce_sum(state.collective, grads)
}

func train_parallel_all_gather_activation(train_parallel_state state, []float activations) []float {
    tp_all_gather(state.collective, activations)
}

func train_parallel_enabled(train_parallel_state state) bool {
    tp_enabled(state.tp)
}

func train_parallel_world_size(train_parallel_state state) int {
    state.tp.world_size
}

func train_parallel_state_dict(train_parallel_state state) train_parallel_state {
    state
}

func train_parallel_load_state_dict(train_parallel_state state, train_parallel_state other) train_parallel_state {
    other
}
