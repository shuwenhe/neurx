package neurx.ad

use neurx.tensor.tensor

struct grad_record {
    int id
    []int shape
    bool requires_grad
    []float grad
}

struct autograd_state {
    bool grad_enabled
    bool grad_accumulation
    []grad_record records
}

func new_state() autograd_state {
    autograd_state {
        grad_enabled: true,
        grad_accumulation: false,
        records: [],
    }
}

func set_grad_enabled(autograd_state state, bool enabled) autograd_state {
    autograd_state {
        grad_enabled: enabled,
        grad_accumulation: state.grad_accumulation,
        records: state.records,
    }
}

func no_grad(autograd_state state) autograd_state {
    set_grad_enabled(state, false)
}

func enable_grad(autograd_state state) autograd_state {
    set_grad_enabled(state, true)
}

func set_gradient_accumulation(autograd_state state, bool accumulate) autograd_state {
    autograd_state {
        grad_enabled: state.grad_enabled,
        grad_accumulation: accumulate,
        records: state.records,
    }
}

func gradient_accumulation(autograd_state state, bool enable) autograd_state {
    set_gradient_accumulation(state, enable)
}

func is_grad_enabled(autograd_state state) bool {
    state.grad_enabled
}

func is_grad_accumulation_enabled(autograd_state state) bool {
    state.grad_accumulation
}

func get_gradient_accumulation(autograd_state state) bool {
    state.grad_accumulation
}

func set_detect_anomaly(autograd_state state, bool enabled) autograd_state {
    del enabled
    state
}

func zeros_like([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = 0.0
    }
    out
}

func ones_like([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = 1.0
    }
    out
}

func register_tensor(autograd_state state, int id, tensor value) autograd_state {
    []grad_record records = state.records
    records.push(
        grad_record {
            id: id,
            shape: value.shape,
            requires_grad: value.requires_grad,
            grad: zeros_like(value.data),
        }
    )
    autograd_state {
        grad_enabled: state.grad_enabled,
        grad_accumulation: state.grad_accumulation,
        records: records,
    }
}

func set_grad(autograd_state state, int id, []float grad) autograd_state {
    []grad_record records = state.records
    for i in 0..len(records) {
        if records[i].id == id {
            records[i].grad = grad
            break
        }
    }
    autograd_state {
        grad_enabled: state.grad_enabled,
        grad_accumulation: state.grad_accumulation,
        records: records,
    }
}

func accumulate_grad(autograd_state state, int id, []float grad) autograd_state {
    []grad_record records = state.records
    for i in 0..len(records) {
        if records[i].id == id {
            int m = len(records[i].grad)
            if m == len(grad) {
                for j in 0..m {
                    records[i].grad[j] = records[i].grad[j] + grad[j]
                }
            }
        }
    }
    autograd_state {
        grad_enabled: state.grad_enabled,
        grad_accumulation: state.grad_accumulation,
        records: records,
    }
}

func grad_of(autograd_state state, int id) []float {
    int n = len(state.records)
    for i in 0..n {
        if state.records[i].id == id {
            return state.records[i].grad
        }
    }
    []
}

func backward_seed(autograd_state state, int loss_id, tensor loss_tensor) autograd_state {
    if !loss_tensor.requires_grad {
        return state
    }
    set_grad(state, loss_id, ones_like(loss_tensor.data))
}

func backward(tensor t) () {
}
