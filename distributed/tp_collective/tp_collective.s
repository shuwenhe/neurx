package neurx.distributed.tp_collective
use neurx.distributed.tp
use neurx.distributed.comm

struct tp_collective_state {
    tp_state tp
    process_group_state pg
}

func new_tp_collective_state(tp_state tp, process_group_state pg) tp_collective_state {
    tp_collective_state {
        tp: tp,
        pg: pg,
    }
}

func tp_collective_world_size(tp_collective_state state) int {
    state.tp.world_size
}

func tp_all_reduce_sum(tp_collective_state state, []float values) []float {
    if !tp_enabled(state.tp) {
        return copy_float(values)
    }
    all_reduce_sum(state.pg, values)
}

func tp_all_gather(tp_collective_state state, []float values) []float {
    if !tp_enabled(state.tp) {
        return copy_float(values)
    }
    all_gather(state.pg, values)
}

func tp_collective_state_dict(tp_collective_state state) tp_collective_state {
    state
}

func tp_collective_load_state_dict(tp_collective_state state, tp_collective_state other) tp_collective_state {
    other
}

