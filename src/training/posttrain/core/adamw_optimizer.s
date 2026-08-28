package neurx.posttrain.core.adamw_optimizer
use std.io.println
struct adamw_state_s {
    float learning_rate
    float beta1
    float beta2
    float epsilon
    float weight_decay
    int step_count
    float[][] first_moment
    float[][] second_moment
}

struct param_update_s {
    float[][] updated_params
    float norm
    float ratio
}

func new_adamw_state_s(float lr) adamw_state_s {
    adamw_state_s {
        learning_rate: lr,
        beta1: 0.9,
        beta2: 0.95,
        epsilon: 1e-8,
        weight_decay: 0.01,
        step_count: 0,
        first_moment: make(float[][], 0),
        second_moment: make(float[][], 0),
    }
}

func initialize_optimizer_state_s(float[][] params, adamw_state_s state) adamw_state_s {
    float[][] m = make(float[][], 0)
    float[][] v = make(float[][], 0)
    int i = 0
    for i < len(params) {
        float[] m_i = make(float[], 0)
        float[] v_i = make(float[], 0)
        int j = 0
        for j < len(params[i]) {
            m_i = append(m_i, 0.0)
            v_i = append(v_i, 0.0)
            j = j + 1
        }
        m = append(m, m_i)
        v = append(v, v_i)
        i = i + 1
    }
    adamw_state_s {
        learning_rate: state.learning_rate,
        beta1: state.beta1,
        beta2: state.beta2,
        epsilon: state.epsilon,
        weight_decay: state.weight_decay,
        step_count: state.step_count,
        first_moment: m,
        second_moment: v,
    }
}

func compute_bias_correction_s(float beta, int step) float {
    float beta_t = 1.0
    int i = 0
    for i < step {
        beta_t = beta_t * beta
        i = i + 1
    }
    1.0 - beta_t
}

func adamw_step_s(
    float[][] params,
    float[][] gradients,
    adamw_state_s state
) param_update_s {
    int step = state.step_count + 1
    float bias_corr_1 = compute_bias_correction_s(state.beta1, step)
    float bias_corr_2 = compute_bias_correction_s(state.beta2, step)
    float[][] updated = make(float[][], 0)
    float grad_norm = 0.0
    float param_norm = 0.0
    int i = 0
    for i < len(params) {
        float[] param_i = params[i]
        float[] grad_i = gradients[i]
        float[] m_i = state.first_moment[i]
        float[] v_i = state.second_moment[i]
        float[] updated_param = make(float[], 0)
        int j = 0
        for j < len(param_i) {
            float param = param_i[j]
            float grad = grad_i[j]
            float m = m_i[j]
            float v = v_i[j]
            m = state.beta1 * m + (1.0 - state.beta1) * grad
            v = state.beta2 * v + (1.0 - state.beta2) * grad * grad
            m_i[j] = m
            v_i[j] = v
            float m_hat = m / bias_corr_1
            float v_hat = v / bias_corr_2
            float denom = 0.0
            if v_hat >= 0.0 {
                denom = 1.0
            }
            float update = state.learning_rate * m_hat / (denom + state.epsilon)
            update = update + state.weight_decay * param
            float new_param = param - update
            updated_param = append(updated_param, new_param)
            grad_norm = grad_norm + grad * grad
            param_norm = param_norm + new_param * new_param
            j = j + 1
        }
        updated = append(updated, updated_param)
        i = i + 1
    }
    param_update_s {
        updated_params: updated,
        norm: param_norm,
        ratio: 0.0,
    }
}

func clip_grad_norm_s(float[][] gradients, float max_norm) float[][] {
    float grad_norm = 0.0
    int i = 0
    for i < len(gradients) {
        int j = 0
        for j < len(gradients[i]) {
            float g = gradients[i][j]
            grad_norm = grad_norm + g * g
            j = j + 1
        }
        i = i + 1
    }
    if grad_norm <= 0.0 {
        return gradients
    }
    float clip_coef = max_norm / (grad_norm + 1e-8)
    if clip_coef >= 1.0 {
        return gradients
    }
    float[][] clipped = make(float[][], 0)
    i = 0
    for i < len(gradients) {
        float[] grad_i = gradients[i]
        float[] clipped_grad = make(float[], 0)
        int j = 0
        for j < len(grad_i) {
            clipped_grad = append(clipped_grad, grad_i[j] * clip_coef)
            j = j + 1
        }
        clipped = append(clipped, clipped_grad)
        i = i + 1
    }
    clipped
}
