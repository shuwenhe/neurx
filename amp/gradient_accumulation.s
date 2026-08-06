package neurx.amp.gradient_accumulation
struct gradient_accumulator {
    [][]float accumulated_grads
    int accumulation_steps
    int current_step
    int num_params
}
func new_gradient_accumulator(int num_params, int accumulation_steps) gradient_accumulator {
    [][]float grads = make([][]float, 0)
    int i = 0
    while i < num_params {
        grads = append(grads, make_zero_array(1))
        i = i + 1
    }
    gradient_accumulator {
        accumulated_grads: grads,
        accumulation_steps: accumulation_steps,
        current_step: 0,
        num_params: num_params,
    }
}
func accumulate_gradients(
    gradient_accumulator acc,
    []float batch_grads
) gradient_accumulator {
    int i = 0
    while i < len(batch_grads) {
        if i < len(acc.accumulated_grads) {
            acc.accumulated_grads[i][0] = acc.accumulated_grads[i][0] + batch_grads[i]
        }
        i = i + 1
    }
    acc.current_step = acc.current_step + 1
    return acc
}
func should_update_params(gradient_accumulator acc) bool {
    return acc.current_step >= acc.accumulation_steps
}
func get_accumulated_grads(gradient_accumulator acc) []float {
    []float grads = []float{cap: len(acc.accumulated_grads)}
    int i = 0
    while i < len(acc.accumulated_grads) {
        grads[i] = acc.accumulated_grads[i][0]
        i = i + 1
    }
    return grads
}
func average_accumulated_grads(gradient_accumulator acc) []float {
    []float grads = []float{cap: len(acc.accumulated_grads)}
    float denom = float(acc.accumulation_steps)
    if denom < 1.0 {
        denom = 1.0
    }
    int i = 0
    while i < len(acc.accumulated_grads) {
        grads[i] = acc.accumulated_grads[i][0] / denom
        i = i + 1
    }
    return grads
}
func reset_accumulator(gradient_accumulator acc) gradient_accumulator {
    int i = 0
    while i < len(acc.accumulated_grads) {
        acc.accumulated_grads[i][0] = 0.0
        i = i + 1
    }
    acc.current_step = 0
    return acc
}
func make_zero_array(int n) []float {
    []float arr = []float{cap: n}
    int i = 0
    while i < n {
        arr[i] = 0.0
        i = i + 1
    }
    return arr
}
