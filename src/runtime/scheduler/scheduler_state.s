package neurx.scheduler.scheduler_state
struct scheduler_state_dict {
    int last_epoch
    []float last_lr
    []string state_keys
    []float[] state_values
}

func scheduler_state_dict_create(
    int last_epoch,
    []float last_lr
) scheduler_state_dict {
    scheduler_state_dict {
        last_epoch: last_epoch,
        last_lr: clone_lr_array(last_lr),
        state_keys: [],
        state_values: [],
    }
}

func scheduler_state_dict_add_state(
    scheduler_state_dict state,
    string key,
    []float value
) scheduler_state_dict {
    state.state_keys = append(state.state_keys, key)
    state.state_values = append(state.state_values, clone_lr_array(value))
    return state
}

func scheduler_state_dict_get_state(
    scheduler_state_dict state,
    string key
) []float {
    int i = 0
    for i < len(state.state_keys) {
        if state.state_keys[i] == key {
            return clone_lr_array(state.state_values[i])
        }
        i = i + 1
    }
    return []float{}
}

func scheduler_load_state_dict(
    scheduler_state_dict state,
    int current_epoch
) int {
    if state.last_epoch > current_epoch {
        return state.last_epoch
    }
    return current_epoch
}

func scheduler_get_last_lr([]float current_lrs) []float {
    return clone_lr_array(current_lrs)
}

func clone_lr_array([]float values) []float {
    []float out = make([]float, len(values))
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    return out
}
