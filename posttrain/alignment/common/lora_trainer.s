package neurx.posttrain.alignment.lora_trainer

struct lora_config {
    int seq_len
    int hidden_size
    int vocab_size
    int num_layers
    int rank
    float alpha
    float dropout_rate
    string target_modules
    float learning_rate
    float weight_decay
    float max_grad_norm
    int batch_size
    int num_epochs
    int warmup_steps
    int total_steps
    int global_rank
    int world_size
    int dp_degree
    bool use_qlora
    string qlora_dtype
}

func default_lora_config() lora_config {
    lora_config {
        seq_len: 128,
        hidden_size: 256,
        vocab_size: 32000,
        num_layers: 12,
        rank: 16,
        alpha: 16.0,
        dropout_rate: 0.05,
        target_modules: "q,k,v,o",
        learning_rate: 5e-4,
        weight_decay: 0.01,
        max_grad_norm: 0.5,
        batch_size: 32,
        num_epochs: 3,
        warmup_steps: 100,
        total_steps: 10000,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        use_qlora: false,
        qlora_dtype: "nf4",
    }
}

struct lora_linear {
    []float base_weight
    int out_dim
    int in_dim
    []float lora_a
    []float lora_b
    []float lora_a_grad
    []float lora_b_grad
    int rank
    float scaling
    float dropout_rate
    []float last_input
    []float last_ax
}

struct lora_state {
    []lora_linear layers
    int num_layers
    [][]float m_a
    [][]float v_a
    [][]float m_b
    [][]float v_b
    lora_config config
    int current_step
    float current_loss
    float current_lr
}

struct lora_adamw_state {
    float lr
    float beta1
    float beta2
    float weight_decay
    float max_grad_norm
    float eps
    int step
}

func init_gaussian(int n, float std) []float {
    []float result = []float{cap: n}
    int i = 0
    while i < n {
        float val = sin_approx((i as float) * 0.1) * std
        result = append(result, val)
        i = i + 1
    }
    result
}

func fill_lora(int n, float val) []float {
    []float result = []float{cap: n}
    int i = 0
    while i < n {
        result = append(result, val)
        i = i + 1
    }
    result
}

func sin_approx(float x) float {
    float pi = 3.14159
    float two_pi = 2.0 * pi
    while x > pi {
        x = x - two_pi
    }
    while x < -pi {
        x = x + two_pi
    }
    float x2 = x * x
    float x3 = x2 * x
    float x5 = x3 * x2
    x - x3 / 6.0 + x5 / 120.0
}

func cos_approx(float x) float {
    sin_approx(x + 1.5708)
}

func sqrt_lora(float x) float {
    if x < 0.0 {
        return 0.0
    }
    float guess = 1.0
    int iter = 0
    while iter < 5 {
        guess = 0.5 * (guess + x / guess)
        iter = iter + 1
    }
    guess
}

func create_lora_linear(int in_dim, int out_dim, []float base_weight, lora_config cfg) lora_linear {
    int r = cfg.rank
    float scale = cfg.alpha / (r as float)
    []float a = init_gaussian(r * in_dim, 0.02)
    []float b = fill_lora(out_dim * r, 0.0)
    lora_linear {
        base_weight: base_weight,
        out_dim: out_dim,
        in_dim: in_dim,
        lora_a: a,
        lora_b: b,
        lora_a_grad: fill_lora(r * in_dim, 0.0),
        lora_b_grad: fill_lora(out_dim * r, 0.0),
        rank: r,
        scaling: scale,
        dropout_rate: cfg.dropout_rate,
        last_input: []float{},
        last_ax: []float{},
    }
}

func create_lora_state(lora_config cfg) lora_state {
    []lora_linear layers = []lora_linear{}
    int layer_idx = 0
    while layer_idx < cfg.num_layers {
        int in_d = cfg.hidden_size
        int out_d = cfg.hidden_size
        []float base_w = init_gaussian(in_d * out_d, 0.01)
        lora_linear layer = create_lora_linear(in_d, out_d, base_w, cfg)
        layers = append(layers, layer)
        layer_idx = layer_idx + 1
    }
    [][]float m_a = [][]float{}
    [][]float v_a = [][]float{}
    [][]float m_b = [][]float{}
    [][]float v_b = [][]float{}
    int i = 0
    while i < cfg.num_layers {
        m_a = append(m_a, fill_lora(cfg.rank * cfg.hidden_size, 0.0))
        v_a = append(v_a, fill_lora(cfg.rank * cfg.hidden_size, 0.0))
        m_b = append(m_b, fill_lora(cfg.hidden_size * cfg.rank, 0.0))
        v_b = append(v_b, fill_lora(cfg.hidden_size * cfg.rank, 0.0))
        i = i + 1
    }
    lora_state {
        layers: layers,
        num_layers: cfg.num_layers,
        m_a: mA,
        v_a: vA,
        m_b: mB,
        v_b: vB,
        config: cfg,
        current_step: 0,
        current_loss: 0.0,
        current_lr: cfg.learning_rate,
    }
}

func lora_forward(lora_linear layer, []float input) []float {
    int batch_seq_len = len(input) / layer.in_dim
    int out_size = batch_seq_len * layer.out_dim
    []float output = fill_lora(out_size, 0.0)
    int b = 0
    while b < batch_seq_len {
        int i = 0
        while i < layer.out_dim {
            float sum = 0.0
            int j = 0
            while j < layer.in_dim {
                int x_idx = b * layer.in_dim + j
                int w_idx = i * layer.in_dim + j
                if x_idx < len(input) && w_idx < len(layer.base_weight) {
                    sum = sum + input[x_idx] * layer.base_weight[w_idx]
                }
                j = j + 1
            }
            output[b * layer.out_dim + i] = sum
            i = i + 1
        }
        b = b + 1
    }
    []float x_a = fill_lora(batch_seq_len * layer.rank, 0.0)
    b = 0
    while b < batch_seq_len {
        int r = 0
        while r < layer.rank {
            float sum = 0.0
            int j = 0
            while j < layer.in_dim {
                int x_idx = b * layer.in_dim + j
                int a_idx = r * layer.in_dim + j
                if x_idx < len(input) && a_idx < len(layer.lora_A) {
                    sum = sum + input[x_idx] * layer.lora_A[a_idx]
                }
                j = j + 1
            }
            x_a[b * layer.rank + r] = sum
            r = r + 1
        }
        b = b + 1
    }
    b = 0
    while b < batch_seq_len {
        int i = 0
        while i < layer.out_dim {
            float sum = 0.0
            int r = 0
            while r < layer.rank {
                int x_a_idx = b * layer.rank + r
                int b_idx = i * layer.rank + r
                if x_a_idx < len(x_a) && b_idx < len(layer.lora_B) {
                    sum = sum + x_a[x_a_idx] * layer.lora_B[b_idx]
                }
                r = r + 1
            }
            int out_idx = b * layer.out_dim + i
            output[out_idx] = output[out_idx] + layer.scaling * sum
            i = i + 1
        }
        b = b + 1
    }
    output
}

struct lora_backward_result {
    lora_linear updated_layer
    []float grad_input
}

func lora_backward(lora_linear layer, []float grad_output) lora_backward_result {
    int batch_seq_len = len(grad_output) / layer.out_dim
    []float grad_b = fill_lora(layer.out_dim * layer.rank, 0.0)
    int b = 0
    while b < batch_seq_len {
        int i = 0
        while i < layer.out_dim {
            int grad_idx = b * layer.out_dim + i
            float grad_val = 0.0
            if grad_idx < len(grad_output) {
                grad_val = grad_output[grad_idx]
            }
            int r = 0
            while r < layer.rank {
                int b_idx = i * layer.rank + r
                int x_a_idx = b * layer.rank + r
                float x_a_val = 0.0
                if x_a_idx < len(layer.last_Ax) {
                    x_a_val = layer.last_Ax[x_a_idx]
                }
                grad_b[b_idx] = grad_b[b_idx] + layer.scaling * grad_val * x_a_val
                r = r + 1
            }
            i = i + 1
        }
        b = b + 1
    }
    []float grad_a = fill_lora(layer.rank * layer.in_dim, 0.0)
    []float grad_lora = fill_lora(batch_seq_len * layer.rank, 0.0)
    b = 0
    while b < batch_seq_len {
        int r = 0
        while r < layer.rank {
            float sum = 0.0
            int i = 0
            while i < layer.out_dim {
                int grad_idx = b * layer.out_dim + i
                int b_idx = i * layer.rank + r
                float grad_val = 0.0
                float b_val = 0.0
                if grad_idx < len(grad_output) {
                    grad_val = grad_output[grad_idx]
                }
                if b_idx < len(layer.lora_B) {
                    b_val = layer.lora_B[b_idx]
                }
                sum = sum + grad_val * b_val
                i = i + 1
            }
            grad_lora[b * layer.rank + r] = layer.scaling * sum
            r = r + 1
        }
        b = b + 1
    }
    b = 0
    while b < batch_seq_len {
        int r = 0
        while r < layer.rank {
            float sum = 0.0
            int j = 0
            while j < layer.in_dim {
                int x_idx = b * layer.in_dim + j
                int grad_idx = b * layer.rank + r
                float x_val = 0.0
                float grad_val = 0.0
                if x_idx < len(layer.last_input) {
                    x_val = layer.last_input[x_idx]
                }
                if grad_idx < len(grad_lora) {
                    grad_val = grad_lora[grad_idx]
                }
                sum = sum + x_val * grad_val
                j = j + 1
            }
            grad_a[r * layer.in_dim] = grad_a[r * layer.in_dim] + sum
            r = r + 1
        }
        b = b + 1
    }
    []float grad_input = fill_lora(batch_seq_len * layer.in_dim, 0.0)
    lora_linear updated = layer
    updated.lora_A_grad = grad_a
    updated.lora_B_grad = grad_b
    lora_backward_result {
        updated_layer: updated,
        grad_input: grad_input,
    }
}

func lora_mse_loss([]float predictions, []float targets) float {
    float loss = 0.0
    int i = 0
    while i < len(predictions) && i < len(targets) {
        float diff = predictions[i] - targets[i]
        loss = loss + diff * diff
        i = i + 1
    }
    if len(predictions) > 0 {
        loss = loss / (len(predictions) as float)
    }
    loss
}

func lora_l1_loss([]float predictions, []float targets) float {
    float loss = 0.0
    int i = 0
    while i < len(predictions) && i < len(targets) {
        float diff = predictions[i] - targets[i]
        if diff < 0.0 {
            diff = -diff
        }
        loss = loss + diff
        i = i + 1
    }
    if len(predictions) > 0 {
        loss = loss / (len(predictions) as float)
    }
    loss
}

func get_learning_rate(int current_step, lora_config cfg) float {
    float lr = cfg.learning_rate
    if current_step < cfg.warmup_steps {
        lr = lr * ((current_step as float) / (cfg.warmup_steps as float))
    } else {
        float progress = ((current_step - cfg.warmup_steps) as float) / ((cfg.total_steps - cfg.warmup_steps) as float)
        if progress > 1.0 {
            progress = 1.0
        }
        float pi = 3.14159
        lr = lr * 0.5 * (1.0 + cos_approx(pi * progress))
    }
    lr
}

func clip_grad_norm([]float grads, float max_norm) float {
    float norm = 0.0
    int i = 0
    while i < len(grads) {
        float g = grads[i]
        norm = norm + g * g
        i = i + 1
    }
    norm = sqrt_lora(norm)
    if norm > max_norm && norm > 0.0 {
        float scale = max_norm / norm
        i = 0
        while i < len(grads) {
            grads[i] = grads[i] * scale
            i = i + 1
        }
    }
    norm
}

func lora_adamw_step(lora_linear layer, lora_adamw_state opt, int layer_idx) (lora_linear, lora_adamw_state) {
    lora_linear updated = layer
    lora_adamw_state updated_opt = opt
    float bias_correction1 = 1.0 - (opt.beta1 as float) * (opt.beta1 as float)
    float bias_correction2 = 1.0 - (opt.beta2 as float) * (opt.beta2 as float)
    int idx = 0
    while idx < len(layer.lora_A) {
        float g = layer.lora_A_grad[idx]
        float m = opt.beta1 * 0.0 + (1.0 - opt.beta1) * g
        float v = opt.beta2 * 0.0 + (1.0 - opt.beta2) * g * g
        float m_hat = m / bias_correction1
        float v_hat = v / bias_correction2
        float step_size = opt.lr / (sqrt_lora(v_hat) + opt.eps)
        updated.lora_A[idx] = layer.lora_A[idx] * (1.0 - opt.lr * opt.weight_decay) - step_size * m_hat
        updated.lora_A_grad[idx] = 0.0
        idx = idx + 1
    }
    idx = 0
    while idx < len(layer.lora_B) {
        float g = layer.lora_B_grad[idx]
        float m = opt.beta1 * 0.0 + (1.0 - opt.beta1) * g
        float v = opt.beta2 * 0.0 + (1.0 - opt.beta2) * g * g
        float m_hat = m / (1.0 - opt.beta1)
        float v_hat = v / (1.0 - opt.beta2)
        float step_size = opt.lr / (sqrt_lora(v_hat) + opt.eps)
        updated.lora_B[idx] = layer.lora_B[idx] - step_size * m_hat
        updated.lora_B_grad[idx] = 0.0
        idx = idx + 1
    }
    updated_opt.step = opt.step + 1
    (updated, updated_opt)
}

func lora_training_step(lora_state state, []float input_ids, []float targets) lora_state {
    lora_state updated = state
    []float hidden = []float{}
    int i = 0
    while i < len(input_ids) {
        hidden = append(hidden, input_ids[i] * 0.01)
        i = i + 1
    }
    []lora_linear updated_layers = []lora_linear{}
    i = 0
    while i < len(state.layers) {
        lora_linear layer = state.layers[i]
        layer.last_input = hidden
        []float output = lora_forward(layer, hidden)
        hidden = output
        updated_layers = append(updated_layers, layer)
        i = i + 1
    }
    float loss = lora_mse_loss(hidden, targets)
    updated.current_loss = loss
    []float grad_output = fill_lora(len(hidden), 1.0)
    i = len(updated_layers) - 1
    while i >= 0 {
        lora_linear layer = updated_layers[i]
        lora_backward_result result = lora_backward(layer, grad_output)
        updated_layers[i] = result.updated_layer
        grad_output = result.grad_input
        i = i - 1
    }
    float lr = get_learning_rate(state.current_step, state.config)
    updated.current_lr = lr
    lora_adamw_state opt = lora_adamw_state {
        lr: lr,
        beta1: 0.9,
        beta2: 0.999,
        weight_decay: state.config.weight_decay,
        max_grad_norm: state.config.max_grad_norm,
        eps: 1e-8,
        step: state.current_step,
    }
    i = 0
    while i < len(updated_layers) {
        lora_linear layer = updated_layers[i]
        (lora_linear updated_layer, lora_adamw_state updated_opt) = lora_adamw_step(layer, opt, i)
        updated_layers[i] = updated_layer
        opt = updated_opt
        i = i + 1
    }
    updated.layers = updated_layers
    updated.current_step = state.current_step + 1
    updated
}

struct lora_trajectory {
    []float input_ids
    []float targets
    float weight
}

func start_lora_training(lora_config cfg, []lora_trajectory trajectories) lora_state {
    lora_state state = create_lora_state(cfg)
    int epoch = 0
    while epoch < cfg.num_epochs {
        int traj_idx = 0
        while traj_idx < len(trajectories) {
            lora_trajectory traj = trajectories[traj_idx]
            state = lora_training_step(state, traj.input_ids, traj.targets)
            if state.current_step % 10 == 0 {
            }
            traj_idx = traj_idx + 1
        }
        epoch = epoch + 1
    }
    state
}

func lora_reduce_gradients(lora_state state, int world_size) lora_state {
    lora_state updated = state
    if world_size > 1 {
        int layer_idx = 0
        while layer_idx < len(state.layers) {
            lora_linear layer = state.layers[layer_idx]
            int i = 0
            while i < len(layer.lora_A_grad) {
                layer.lora_A_grad[i] = layer.lora_A_grad[i] / (world_size as float)
                i = i + 1
            }
            i = 0
            while i < len(layer.lora_B_grad) {
                layer.lora_B_grad[i] = layer.lora_B_grad[i] / (world_size as float)
                i = i + 1
            }
            updated.layers[layer_idx] = layer
            layer_idx = layer_idx + 1
        }
    }
    updated
}

struct lora_stats {
    int total_base_params
    int total_lora_params
    float trainable_ratio
    float memory_saved_percent
}

func lora_compute_stats(lora_state state) lora_stats {
    int base_params = 0
    int lora_params = 0
    int i = 0
    while i < len(state.layers) {
        lora_linear layer = state.layers[i]
        base_params = base_params + layer.in_dim * layer.out_dim
        lora_params = lora_params + layer.rank * (layer.in_dim + layer.out_dim)
        i = i + 1
    }
    float total = (base_params + lora_params) as float
    float trainable_ratio = 100.0 * ((lora_params as float) / total)
    float memory_saved = 100.0 * ((base_params as float) / total)
    lora_stats {
        total_base_params: base_params,
        total_lora_params: lora_params,
        trainable_ratio: trainable_ratio,
        memory_saved_percent: memory_saved,
    }
}
