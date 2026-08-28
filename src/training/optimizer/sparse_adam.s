package neurx.optimizer.sparse_adam
use neurx.tensor.tensor
use neurx.tensor.new
struct sparse_adam_optimizer {
    float lr
    float beta1
    float beta2
    float eps
    int step
    float[] exp_avg
    float[] exp_avg_sq
    int[] step_count
}

func new_sparse_adam(float lr, float beta1, float beta2, float eps) sparse_adam_optimizer {
    sparse_adam_optimizer {
        lr: lr,
        beta1: beta1,
        beta2: beta2,
        eps: eps,
        step: 0,
        exp_avg: [],
        exp_avg_sq: [],
        step_count: [],
    }
}

func sparse_adam_step(
    sparse_adam_optimizer optimizer,
    tensor params,
    tensor grads,
    int[] sparse_indices
) sparse_adam_optimizer_step_output {
    int n = len(params.data)
    optimizer.step = optimizer.step + 1
    optimizer.exp_avg = ensure_sparse_adam_state(optimizer.exp_avg, n)
    optimizer.exp_avg_sq = ensure_sparse_adam_state(optimizer.exp_avg_sq, n)
    optimizer.step_count = ensure_sparse_adam_step_count(optimizer.step_count, n)
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = params.data[i]
        i = i + 1
    }
    int k = 0
    for k < len(sparse_indices) {
        int idx = sparse_indices[k]
        float grad = grads.data[idx]
        optimizer.step_count[idx] = optimizer.step_count[idx] + 1
        int local_step = optimizer.step_count[idx]
        optimizer.exp_avg[idx] = optimizer.beta1 * optimizer.exp_avg[idx] + (1.0 - optimizer.beta1) * grad
        optimizer.exp_avg_sq[idx] = optimizer.beta2 * optimizer.exp_avg_sq[idx] + (1.0 - optimizer.beta2) * grad * grad
        float bias_correction1 = 1.0 - sparse_adam_pow(optimizer.beta1, local_step)
        float bias_correction2 = 1.0 - sparse_adam_pow(optimizer.beta2, local_step)
        float denom = sparse_adam_sqrt(optimizer.exp_avg_sq[idx] / bias_correction2) + optimizer.eps
        float step_size = optimizer.lr / bias_correction1
        out[idx] = out[idx] - step_size * optimizer.exp_avg[idx] / denom
        k = k + 1
    }
    sparse_adam_optimizer_step_output {
        optimizer: optimizer,
        params: new(out, params.shape, params.requires_grad),
    }
}

struct sparse_adam_optimizer_step_output {
    sparse_adam_optimizer optimizer
    tensor params
}

func ensure_sparse_adam_state(float[] values, int n) float[] {
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        if i < len(values) {
            out[i] = values[i]
        } else {
            out[i] = 0.0
        }
        i = i + 1
    }
    out
}

func ensure_sparse_adam_step_count(int[] values, int n) int[] {
    int[] out = int[]{cap: n}
    int i = 0
    for i < n {
        if i < len(values) {
            out[i] = values[i]
        } else {
            out[i] = 0
        }
        i = i + 1
    }
    out
}

func sparse_adam_sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    if x > 1.0 {
        y = x
    }
    int i = 0
    for i < 32 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func sparse_adam_pow(float base, int exponent) float {
    float result = 1.0
    int i = 0
    for i < exponent {
        result = result * base
        i = i + 1
    }
    result
}
