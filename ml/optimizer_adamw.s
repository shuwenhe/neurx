// =====================================================================
// Complete AdamW Optimizer Implementation
// completeEnglish textAdamWoptimizeEnglish text - English textweight decayEnglish textlearning rate schedule
// =====================================================================

package neurx.ml.optimizer

use neurx.tensor.{tensor, zeros, ones, fill, new}

// =====================================================================
// AdamWoptimizeEnglish textstate
// =====================================================================

struct adam_state {
    float learning_rate      // learning rate
    float beta1              // English text (default0.9)
    float beta2              // English text (default0.999)
    float epsilon            // English textparameter (default1e-8)
    float weight_decay       // L2English text

    int timestep             // English texttimestep

    []tensor m               // English text (gradientEnglish text)
    []tensor v               // English text (gradientEnglish text)
    []tensor param           // parameter
}

struct optimizer_config {
    float learning_rate
    float beta1
    float beta2
    float epsilon
    float weight_decay
    int warmup_steps
    string lr_schedule       // "constant", "linear", "cosine"
}

// =====================================================================
// initialize
// =====================================================================

func init_adam_state(
    []tensor parameters,
    optimizer_config config
) adam_state {
    []tensor m_states = []tensor{cap: len(parameters)}
    []tensor v_states = []tensor{cap: len(parameters)}

    int i = 0
    while i < len(parameters) {
        m_states.push(zeros(parameters[i].shape))
        v_states.push(zeros(parameters[i].shape))
        i = i + 1
    }

    adam_state {
        learning_rate: config.learning_rate,
        beta1: config.beta1,
        beta2: config.beta2,
        epsilon: config.epsilon,
        weight_decay: config.weight_decay,

        timestep: 0,
        m: m_states,
        v: v_states,
        param: parameters,
    }
}

// =====================================================================
// learning rateEnglish text
// =====================================================================

func get_learning_rate(
    float base_lr,
    string schedule,
    int timestep,
    int total_steps,
    int warmup_steps
) float {
    // English textphase
    if timestep < warmup_steps {
        return base_lr * float_from_int(timestep) / float_from_int(warmup_steps)
    }

    int warmup_done = timestep - warmup_steps
    int total_after_warmup = total_steps - warmup_steps

    if total_after_warmup <= 0 { return base_lr }

    float progress = float_from_int(warmup_done) / float_from_int(total_after_warmup)
    if progress > 1.0 { progress = 1.0 }

    if schedule == "linear" {
        // Linear decay: lr * (1 - progress)
        return base_lr * (1.0 - progress)
    }

    if schedule == "cosine" {
        // Cosine annealing: lr * (1 + cos(pi * progress)) / 2
        float pi = 3.141592653589793
        return base_lr * (1.0 + cos_approx(pi * progress)) / 2.0
    }

    // Default: constant
    base_lr
}

// =====================================================================
// gradientEnglish text (Gradient Clipping)
// =====================================================================

func clip_grad_norm([]tensor gradients, float max_norm) []tensor {
    // computegradientEnglish textL2English text
    float total_norm = 0.0
    int i = 0
    while i < len(gradients) {
        int j = 0
        while j < len(gradients[i].data) {
            total_norm = total_norm + gradients[i].data[j] * gradients[i].data[j]
            j = j + 1
        }
        i = i + 1
    }
    total_norm = sqrt_approx(total_norm)

    // computeEnglish text
    float scale = 1.0
    if total_norm > max_norm {
        scale = max_norm / total_norm
    }

    // English text
    i = 0
    while i < len(gradients) {
        int j = 0
        while j < len(gradients[i].data) {
            gradients[i].data[j] = gradients[i].data[j] * scale
            j = j + 1
        }
        i = i + 1
    }

    gradients
}

// =====================================================================
// English textparameterEnglish textAdamWEnglish text
// =====================================================================

func adam_step_param(
    tensor param,
    tensor grad,
    tensor m,
    tensor v,
    float lr,
    float beta1,
    float beta2,
    float eps,
    float weight_decay,
    int timestep
) (tensor, tensor, tensor) {
    // English text
    float bias_correction1 = 1.0 - pow_approx(beta1, float_from_int(timestep))
    float bias_correction2 = 1.0 - pow_approx(beta2, float_from_int(timestep))

    // English text
    int i = 0
    while i < len(param.data) {
        // 1. English text: m = beta1 * m + (1 - beta1) * grad
        m.data[i] = beta1 * m.data[i] + (1.0 - beta1) * grad.data[i]

        // 2. English text: v = beta2 * v + (1 - beta2) * grad^2
        v.data[i] = beta2 * v.data[i] + (1.0 - beta2) * grad.data[i] * grad.data[i]

        // 3. English text
        float m_hat = m.data[i] / bias_correction1
        float v_hat = v.data[i] / bias_correction2

        // 4. parameterEnglish text: param = param - lr * (m_hat / (sqrt(v_hat) + eps))
        float denominator = sqrt_approx(v_hat) + eps
        float update = lr * (m_hat / denominator)

        // 5. Weight decay (L2English text)
        update = update + lr * weight_decay * param.data[i]

        param.data[i] = param.data[i] - update

        i = i + 1
    }

    (param, m, v)
}

// =====================================================================
// completeEnglish textoptimizestepEnglish text
// =====================================================================

func adam_step(
    adam_state state,
    []tensor gradients,
    string lr_schedule,
    int total_steps,
    int warmup_steps,
    float max_grad_norm
) adam_state {
    // English texttimestep
    state.timestep = state.timestep + 1

    // computeEnglish textlearning rate
    float current_lr = get_learning_rate(
        state.learning_rate,
        lr_schedule,
        state.timestep,
        total_steps,
        warmup_steps
    )

    // gradientEnglish text
    []tensor clipped_grads = clip_grad_norm(gradients, max_grad_norm)

    // English textparameter
    int i = 0
    while i < len(state.param) {
        (state.param[i], state.m[i], state.v[i]) = adam_step_param(
            state.param[i],
            clipped_grads[i],
            state.m[i],
            state.v[i],
            current_lr,
            state.beta1,
            state.beta2,
            state.epsilon,
            state.weight_decay,
            state.timestep
        )
        i = i + 1
    }

    state
}

// =====================================================================
// learning rateEnglish text
// =====================================================================

func linear_warmup_scheduler(int current_step, int warmup_steps, float base_lr) float {
    if current_step < warmup_steps {
        return base_lr * float_from_int(current_step) / float_from_int(warmup_steps)
    }
    base_lr
}

func cosine_warmup_scheduler(
    int current_step,
    int warmup_steps,
    int total_steps,
    float base_lr
) float {
    if current_step < warmup_steps {
        // English textphase: English text
        return base_lr * float_from_int(current_step) / float_from_int(warmup_steps)
    }

    // English textphase
    float pi = 3.141592653589793
    int remaining_steps = total_steps - warmup_steps
    int step_after_warmup = current_step - warmup_steps

    float progress = float_from_int(step_after_warmup) / float_from_int(remaining_steps)
    if progress > 1.0 { progress = 1.0 }

    base_lr * (1.0 + cos_approx(pi * progress)) / 2.0
}

// =====================================================================
// learning rateEnglish textcheckpointrecover
// =====================================================================

struct optimizer_checkpoint {
    adam_state state
    int global_step
    float best_loss
}

func save_optimizer_state(adam_state state, int step, float loss) optimizer_checkpoint {
    optimizer_checkpoint {
        state: state,
        global_step: step,
        best_loss: loss,
    }
}

func restore_optimizer_state(optimizer_checkpoint ckpt) adam_state {
    ckpt.state
}

// =====================================================================
// toolfunction
// =====================================================================

func float_from_int(int x) float {
    0.0 + x
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func pow_approx(float base, float exp) float {
    // English text pow function: base^exp ≈ exp(exp * ln(base))
    if base <= 0.0 { return 0.0 }
    if exp == 0.0 { return 1.0 }

    float ln_base = log_approx(base)
    exp_approx(exp * ln_base)
}

func log_approx(float x) float {
    float v = x
    if v <= 0.0 { v = 0.000000000001 }
    float y = (v - 1.0) / (v + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    2.0 * (y + (y3 / 3.0) + (y5 / 5.0))
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / float_from_int(i)
        result = result + term
        i = i + 1
    }
    result
}

func cos_approx(float x) float {
    float pi = 3.141592653589793
    float x_mod = x - float_from_int(int_from_float(x / (2.0 * pi))) * 2.0 * pi
    if x_mod > pi { x_mod = 2.0 * pi - x_mod }
    float x2 = x_mod * x_mod
    float result = 1.0
    result = result - (x2 / 2.0)
    result = result + (x2 * x2 / 24.0)
    result = result - (x2 * x2 * x2 / 720.0)
    result
}

func int_from_float(float x) int {
    int n = 0
    float y = x
    if y < 0.0 {
        while y < 0.0 {
            y = y + 1.0
            n = n - 1
        }
    }
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}
