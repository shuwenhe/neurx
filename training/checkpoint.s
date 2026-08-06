package neurx.training.checkpoint

struct checkpoint_state {
    [][]float model_weights
    [][]float optimizer_states
    int epoch
    int step
    float best_metric
    string best_model_path
}

func new_checkpoint_state() checkpoint_state {
    checkpoint_state {
        model_weights: make([][]float, 0),
        optimizer_states: make([][]float, 0),
        epoch: 0,
        step: 0,
        best_metric: -1000000000.0,
        best_model_path: "",
    }
}

func checkpoint_save_weights(checkpoint_state ckpt, [][]float weights) checkpoint_state {
    ckpt.model_weights = clone_weights(weights)
    return ckpt
}

func checkpoint_save_optimizer_state(checkpoint_state ckpt, [][]float opt_state) checkpoint_state {
    ckpt.optimizer_states = clone_weights(opt_state)
    return ckpt
}

func checkpoint_save_metadata(checkpoint_state ckpt, int epoch, int step, float metric) checkpoint_state {
    ckpt.epoch = epoch
    ckpt.step = step
    ckpt.best_metric = metric
    return ckpt
}

func checkpoint_load_weights(checkpoint_state ckpt) [][]float {
    return clone_weights(ckpt.model_weights)
}

func checkpoint_load_optimizer_state(checkpoint_state ckpt) [][]float {
    return clone_weights(ckpt.optimizer_states)
}

func checkpoint_is_better(checkpoint_state ckpt, float current_metric, bool higher_is_better) bool {
    if higher_is_better {
        return current_metric > ckpt.best_metric
    }
    return current_metric < ckpt.best_metric
}

func clone_weights([][]float weights) [][]float {
    [][]float cloned = make([][]float, 0)
    int i = 0
    while i < len(weights) {
        cloned = append(cloned, clone_float_array(weights[i]))
        i = i + 1
    }
    return cloned
}

func clone_float_array([]float arr) []float {
    []float cloned = []float{cap: len(arr)}
    int i = 0
    while i < len(arr) {
        cloned[i] = arr[i]
        i = i + 1
    }
    return cloned
}

