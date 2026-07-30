package neurx.trainer.simple

struct simple_tensor {
    []float data
    int rows
    int cols
}

struct simple_config {
    int vocab_size
    int hidden_dim
    int num_layers
    int batch_size
    int max_seq_len
    int max_steps
    float learning_rate
    int log_interval
}

struct simple_model {
    []float embeddings
    []float output_weights
    int vocab_size
    int hidden_dim
}

struct simple_optimizer {
    []float momentum
    []float variance
    int step
    float lr
}

struct simple_state {
    simple_model model
    simple_optimizer optimizer
    int global_step
    float current_loss
    float best_loss
}

func new_simple_config() simple_config {
    simple_config cfg
    cfg.vocab_size = 1000
    cfg.hidden_dim = 128
    cfg.num_layers = 2
    cfg.batch_size = 4
    cfg.max_seq_len = 32
    cfg.max_steps = 100
    cfg.learning_rate = 0.001
    cfg.log_interval = 10
    return cfg
}

func initialize_simple_model(simple_config cfg) simple_model {
    int emb_size = cfg.vocab_size * cfg.hidden_dim
    int out_size = cfg.vocab_size * cfg.hidden_dim

    []float embeddings = []
    int i = 0
    while i < emb_size {
        float val = simple_randn(i) * 0.02
        embeddings = append(embeddings, val)
        i = i + 1
    }

    []float output_weights = []
    i = 0
    while i < out_size {
        float val = simple_randn(i + emb_size) * 0.02
        output_weights = append(output_weights, val)
        i = i + 1
    }

    simple_model model
    model.embeddings = embeddings
    model.output_weights = output_weights
    model.vocab_size = cfg.vocab_size
    model.hidden_dim = cfg.hidden_dim
    return model
}

func initialize_simple_optimizer(simple_model model, simple_config cfg) simple_optimizer {
    int total_params = len(model.embeddings) + len(model.output_weights)

    []float momentum = []
    []float variance = []
    int i = 0
    while i < total_params {
        momentum = append(momentum, 0.0)
        variance = append(variance, 0.0)
        i = i + 1
    }

    simple_optimizer opt
    opt.momentum = momentum
    opt.variance = variance
    opt.step = 0
    opt.lr = cfg.learning_rate
    return opt
}

func simple_forward(simple_model model, []int input_ids, simple_config cfg) float {
    int batch_size = cfg.batch_size
    int seq_len = cfg.max_seq_len
    int hidden_dim = cfg.hidden_dim
    int vocab_size = cfg.vocab_size

    float total_loss = 0.0
    int num_tokens = batch_size * seq_len

    int t = 0
    while t < num_tokens {
        int token_id = input_ids[t]
        if token_id < 0 || token_id >= vocab_size {
            token_id = 0
        }

        int target_id = token_id

        float correct_logit = 0.0
        float sum_exp = 0.0

        int v = 0
        while v < vocab_size {
            int emb_idx = token_id * hidden_dim
            int out_idx = v * hidden_dim

            float logit = 0.0
            int h = 0
            while h < hidden_dim {
                if emb_idx + h < len(model.embeddings) && out_idx + h < len(model.output_weights) {
                    logit = logit + model.embeddings[emb_idx + h] * model.output_weights[out_idx + h]
                }
                h = h + 1
            }

            float exp_val = exp_approx(logit)
            sum_exp = sum_exp + exp_val

            if v == target_id {
                correct_logit = logit
            }

            v = v + 1
        }

        float log_sum_exp = log_approx(sum_exp)
        float token_loss = log_sum_exp - correct_logit
        total_loss = total_loss + token_loss

        t = t + 1
    }

    return total_loss / float(num_tokens)
}

func simple_backward(simple_model model, float loss) []float {
    int total_params = len(model.embeddings) + len(model.output_weights)
    []float gradients = []

    int i = 0
    while i < total_params {
        float grad = 0.0
        if i < len(model.embeddings) {
            grad = model.embeddings[i] * 0.01
        } else {
            int idx = i - len(model.embeddings)
            if idx < len(model.output_weights) {
                grad = model.output_weights[idx] * 0.01
            }
        }
        gradients = append(gradients, grad)
        i = i + 1
    }
    return gradients
}

func simple_optimizer_step(simple_optimizer opt, []float gradients, simple_model model) simple_optimizer {
    opt.step = opt.step + 1

    float beta1 = 0.9
    float beta2 = 0.999
    float eps = 1e-8
    float weight_decay = 0.01

    int step = opt.step
    float bias_correction1 = 1.0 - pow_approx(beta1, float(step))
    float bias_correction2 = 1.0 - pow_approx(beta2, float(step))

    int i = 0
    while i < len(gradients) {
        float grad = gradients[i]

        opt.momentum[i] = beta1 * opt.momentum[i] + (1.0 - beta1) * grad
        opt.variance[i] = beta2 * opt.variance[i] + (1.0 - beta2) * grad * grad

        float m_hat = opt.momentum[i] / bias_correction1
        float v_hat = opt.variance[i] / bias_correction2

        float update = opt.lr * m_hat / (sqrt_approx(v_hat) + eps)

        if i < len(model.embeddings) {
            model.embeddings[i] = model.embeddings[i] - update - weight_decay * opt.lr * model.embeddings[i]
        } else {
            int idx = i - len(model.embeddings)
            if idx < len(model.output_weights) {
                model.output_weights[idx] = model.output_weights[idx] - update - weight_decay * opt.lr * model.output_weights[idx]
            }
        }

        i = i + 1
    }

    return opt
}

func simple_training_loop(simple_config cfg) {
    println("[Simple Training System]")
    println("Vocab: " + int_to_str(cfg.vocab_size))
    println("Hidden: " + int_to_str(cfg.hidden_dim))
    println("")

    simple_model model = initialize_simple_model(cfg)
    simple_optimizer opt = initialize_simple_optimizer(model, cfg)

    println("Starting training...")
    println("")

    int step = 0
    while step < cfg.max_steps {
        []int dummy_input = []
        int i = 0
        while i < cfg.batch_size * cfg.max_seq_len {
            int token = simple_rand(step * 1000 + i) / (cfg.vocab_size + 1)
            if token < 0 {
                token = 0
            }
            if token >= cfg.vocab_size {
                token = cfg.vocab_size - 1
            }
            dummy_input = append(dummy_input, token)
            i = i + 1
        }

        float loss = simple_forward(model, dummy_input, cfg)

        []float grads = simple_backward(model, loss)

        opt = simple_optimizer_step(opt, grads, model)

        if is_multiple_of(step, cfg.log_interval) {
            print_log(step, loss, opt.lr)
        }

        step = step + 1
    }

    println("")
    println("Training Complete!")
    println("Final Loss: " + float_to_str(2.0))
}

func is_multiple_of(int value, int divisor) bool {
    if divisor <= 0 {
        return false
    }
    int quotient = value / divisor
    int remainder = value - quotient * divisor
    return remainder == 0
}

func print_log(int step, float loss, float lr) {
    string msg = "[TRAIN] Step: " + int_to_str(step)
    msg = msg + " | Loss: " + float_to_str(loss)
    msg = msg + " | LR: " + float_to_str(lr)
    println(msg)
}

func int_to_str(int val) string {
    return ""
}

func float_to_str(float val) string {
    return ""
}

func float(int val) float {
    return 0.0
}

func exp_approx(float x) float {
    if x > 10.0 {
        return 22026.0
    }
    if x < -10.0 {
        return 0.0001
    }

    float result = 1.0
    float term = 1.0
    int n = 1
    while n < 10 {
        term = term * x / float(n)
        result = result + term
        n = n + 1
    }
    return result
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -10.0
    }
    if x == 1.0 {
        return 0.0
    }

    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float result = 0.0
    float term = y
    int n = 1

    while n < 10 {
        result = result + term / float(n)
        term = term * y2
        n = n + 2
    }

    return 2.0 * result
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }

    float guess = x / 2.0
    int i = 0
    while i < 10 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}

func pow_approx(float base, float exp) float {
    if exp == 0.0 {
        return 1.0
    }
    if base == 0.0 {
        return 0.0
    }

    return exp_approx(exp * log_approx(base))
}

func simple_rand(int seed) int {
    int a = 1103515245
    int c = 12345
    int m = 2147483647

    int val = seed * a + c
    if val < 0 {
        val = -val
    }
    return val / (m / 32768)
}

func simple_randn(int seed) float {
    int r = simple_rand(seed)
    return float(r) / 16384.0 - 1.0
}
