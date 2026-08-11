package neurx.posttrain.optimizer.adamw
use neurx.posttrain.model.model_loader.{fill_model_tensor}
struct adamw_optimizer {
    []float param_groups
    [][]float param_states_m
    [][]float param_states_v
    float learning_rate
    float beta1
    float beta2
    float epsilon
    float weight_decay
    int step_count
    int warmup_steps
}
struct gradient_state {
    []float gradients
    float total_grad_norm
    int grad_count
}
struct optimizer_config {
    float learning_rate
    float beta1
    float beta2
    float epsilon
    float weight_decay
    float max_grad_norm
    int warmup_steps
    int total_steps
    string scheduler_type
}
struct learning_rate_schedule {
    float current_lr
    float base_lr
    float warmup_steps
    float total_steps
    string scheduler_type
    int current_step
}
func create_optimizer_config(float lr, float wd) optimizer_config {
    optimizer_config config
    config.learning_rate = lr
    config.beta1 = 0.9
    config.beta2 = 0.999
    config.epsilon = 1e-8
    config.weight_decay = wd
    config.max_grad_norm = 1.0
    config.warmup_steps = 100
    config.total_steps = 1000
    config.scheduler_type = "cosine"
    return config
}
func create_adamw_optimizer(int num_params, optimizer_config config) adamw_optimizer {
    adamw_optimizer optimizer
    optimizer.learning_rate = config.learning_rate
    optimizer.beta1 = config.beta1
    optimizer.beta2 = config.beta2
    optimizer.epsilon = config.epsilon
    optimizer.weight_decay = config.weight_decay
    optimizer.step_count = 0
    optimizer.warmup_steps = config.warmup_steps
    optimizer.param_groups = fill_model_tensor(num_params, 0.0)
    optimizer.param_states_m = [][]float{}
    optimizer.param_states_v = [][]float{}
    int i = 0
    while i < num_params {
        optimizer.param_states_m.push(fill_model_tensor(num_params, 0.0))
        optimizer.param_states_v.push(fill_model_tensor(num_params, 0.0))
        i = i + 1
    }
    return optimizer
}
func clip_grad_norm([]float gradients, float max_norm) []float {
    float total_norm = 0.0
    int i = 0
    while i < len(gradients) {
        total_norm = total_norm + gradients[i] * gradients[i]
        i = i + 1
    }
    total_norm = sqrt(total_norm)
    []float clipped = fill_model_tensor(len(gradients), 0.0)
    if total_norm > max_norm && total_norm > 0.0 {
        float scale = max_norm / total_norm
        i = 0
        while i < len(gradients) {
            clipped[i] = gradients[i] * scale
            i = i + 1
        }
    } else {
        i = 0
        while i < len(gradients) {
            clipped[i] = gradients[i]
            i = i + 1
        }
    }
    return clipped
}
func get_learning_rate_with_warmup(adamw_optimizer opt, optimizer_config config) float {
    if opt.step_count < config.warmup_steps {
        return config.learning_rate * (((opt.step_count as float)) / ((config.warmup_steps as float)))
    }
    return config.learning_rate
}
func get_learning_rate_cosine_annealing(adamw_optimizer opt, optimizer_config config) float {
    float progress = (((opt.step_count as float)) / ((config.total_steps as float)))
    if progress > 1.0 {
        progress = 1.0
    }
    float cosine_decay = 0.5 * (1.0 + cos(3.14159265359 * progress))
    return config.learning_rate * cosine_decay
}
func adamw_step(adamw_optimizer opt, []float params, []float gradients, optimizer_config config) adamw_optimizer {
    opt.step_count = opt.step_count + 1
    float lr = get_learning_rate_with_warmup(opt, config)
    if config.scheduler_type == "cosine" {
        lr = get_learning_rate_cosine_annealing(opt, config)
    }
    []float clipped_grads = clip_grad_norm(gradients, config.max_grad_norm)
    int i = 0
    while i < len(params) && i < len(clipped_grads) {
        float g = clipped_grads[i]
        float m_t = opt.beta1 * opt.param_states_m[0][i] + (1.0 - opt.beta1) * g
        float v_t = opt.beta2 * opt.param_states_v[0][i] + (1.0 - opt.beta2) * g * g
        opt.param_states_m[0][i] = m_t
        opt.param_states_v[0][i] = v_t
        float m_hat = m_t / (1.0 - pow(opt.beta1, ((opt.step_count as float))))
        float v_hat = v_t / (1.0 - pow(opt.beta2, ((opt.step_count as float))))
        params[i] = params[i] - lr * m_hat / (sqrt(v_hat) + opt.epsilon) - lr * config.weight_decay * params[i]
        i = i + 1
    }
    return opt
}
func adamw_zero_grad(adamw_optimizer opt) adamw_optimizer {
    int i = 0
    while i < len(opt.param_states_m) {
        int j = 0
        while j < len(opt.param_states_m[i]) {
            opt.param_states_m[i][j] = 0.0
            opt.param_states_v[i][j] = 0.0
            j = j + 1
        }
        i = i + 1
    }
    return opt
}
func create_learning_rate_schedule(optimizer_config config) learning_rate_schedule {
    learning_rate_schedule schedule
    schedule.base_lr = config.learning_rate
    schedule.current_lr = config.learning_rate
    schedule.warmup_steps = config.warmup_steps
    schedule.total_steps = config.total_steps
    schedule.scheduler_type = config.scheduler_type
    schedule.current_step = 0
    return schedule
}
func get_learning_rate_from_schedule(learning_rate_schedule schedule) float {
    float progress = (((schedule.current_step as float)) / ((schedule.total_steps as float)))
    if progress > 1.0 {
        progress = 1.0
    }
    if schedule.current_step < schedule.warmup_steps {
        return schedule.base_lr * (((schedule.current_step as float)) / ((schedule.warmup_steps as float)))
    }
    if schedule.scheduler_type == "cosine" {
        return schedule.base_lr * 0.5 * (1.0 + cos(3.14159265359 * progress))
    }
    if schedule.scheduler_type == "linear" {
        return schedule.base_lr * (1.0 - progress)
    }
    return schedule.base_lr
}
func step_learning_rate_schedule(learning_rate_schedule schedule) learning_rate_schedule {
    schedule.current_step = schedule.current_step + 1
    schedule.current_lr = get_learning_rate_from_schedule(schedule)
    return schedule
}
