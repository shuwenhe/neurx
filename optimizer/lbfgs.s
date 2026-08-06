package neurx.optimizer.lbfgs
use neurx.tensor.tensor
use neurx.tensor.new

struct lbfgs_optimizer {
    float lr
    int max_iter
    int history_size
    float tolerance_grad
    float tolerance_change
    int step
    []float prev_flat_grad
    [][]float old_dirs
    [][]float old_stps
    []float rho
    []float prev_params
}

func new_lbfgs(
    float lr,
    int max_iter,
    int history_size,
    float tolerance_grad,
    float tolerance_change
) lbfgs_optimizer {
    lbfgs_optimizer {
        lr: lr,
        max_iter: max_iter,
        history_size: history_size,
        tolerance_grad: tolerance_grad,
        tolerance_change: tolerance_change,
        step: 0,
        prev_flat_grad: [],
        old_dirs: [],
        old_stps: [],
        rho: [],
        prev_params: [],
    }
}

func lbfgs_step(lbfgs_optimizer optimizer, tensor params, tensor grads) lbfgs_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    []float flat_grad = copy_float_array(grads.data, n)
    float grad_max = lbfgs_abs_max(flat_grad, n)
    if grad_max <= optimizer.tolerance_grad {
        return lbfgs_optimizer_step_output {
            optimizer: optimizer,
            params: params,
        }
    }
    []float direction = []float{cap: n}
    if optimizer.step == 1 {
        int i = 0
        while i < n {
            direction[i] = 0.0 - flat_grad[i]
            i = i + 1
        }
    } else {
        []float y = []float{cap: n}
        []float s = []float{cap: n}
        int i = 0
        while i < n {
            y[i] = flat_grad[i] - optimizer.prev_flat_grad[i]
            s[i] = params.data[i] - optimizer.prev_params[i]
            i = i + 1
        }
        float ys = lbfgs_dot(y, s, n)
        if ys > 0.0000000001 {
            if len(optimizer.old_dirs) >= optimizer.history_size {
                optimizer.old_dirs = pop_front_2d(optimizer.old_dirs)
                optimizer.old_stps = pop_front_2d(optimizer.old_stps)
                optimizer.rho = pop_front_1d(optimizer.rho)
            }
            optimizer.old_dirs = append(optimizer.old_dirs, y)
            optimizer.old_stps = append(optimizer.old_stps, s)
            optimizer.rho = append(optimizer.rho, 1.0 / ys)
        }
        float yy = lbfgs_dot(y, y, n)
        float h_diag = ys / yy
        direction = two_loop_recursion(optimizer, flat_grad, h_diag, n)
    }
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = params.data[i] + optimizer.lr * direction[i]
        i = i + 1
    }
    optimizer.prev_flat_grad = flat_grad
    optimizer.prev_params = copy_float_array(params.data, n)
    lbfgs_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

func two_loop_recursion(
    lbfgs_optimizer optimizer,
    []float flat_grad,
    float h_diag,
    int n
) []float {
    int num_old = len(optimizer.old_dirs)
    []float q = []float{cap: n}
    int i = 0
    while i < n {
        q[i] = 0.0 - flat_grad[i]
        i = i + 1
    }
    []float alpha = []float{cap: num_old}
    int j = 0
    while j < num_old {
        alpha[j] = 0.0
        j = j + 1
    }
    int k = num_old - 1
    while k >= 0 {
        float a = optimizer.rho[k] * lbfgs_dot(optimizer.old_stps[k], q, n)
        alpha[k] = a
        i = 0
        while i < n {
            q[i] = q[i] - a * optimizer.old_dirs[k][i]
            i = i + 1
        }
        k = k - 1
    }
    i = 0
    while i < n {
        q[i] = q[i] * h_diag
        i = i + 1
    }
    k = 0
    while k < num_old {
        float beta = optimizer.rho[k] * lbfgs_dot(optimizer.old_dirs[k], q, n)
        i = 0
        while i < n {
            q[i] = q[i] + (alpha[k] - beta) * optimizer.old_stps[k][i]
            i = i + 1
        }
        k = k + 1
    }
    return q
}

struct lbfgs_optimizer_step_output {
    lbfgs_optimizer optimizer
    tensor params
}

func copy_float_array([]float src, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func lbfgs_dot([]float a, []float b, int n) float {
    float sum = 0.0
    int i = 0
    while i < n {
        sum = sum + a[i] * b[i]
        i = i + 1
    }
    sum
}

func lbfgs_abs_max([]float values, int n) float {
    float max_val = 0.0
    int i = 0
    while i < n {
        float v = values[i]
        if v < 0.0 {
            v = 0.0 - v
        }
        if v > max_val {
            max_val = v
        }
        i = i + 1
    }
    max_val
}

func pop_front_2d([][]float arr) [][]float {
    [][]float out = [][]float{cap: len(arr) - 1}
    int i = 1
    while i < len(arr) {
        out[i - 1] = arr[i]
        i = i + 1
    }
    out
}

func pop_front_1d([]float arr) []float {
    []float out = []float{cap: len(arr) - 1}
    int i = 1
    while i < len(arr) {
        out[i - 1] = arr[i]
        i = i + 1
    }
    out
}
