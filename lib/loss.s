package neurx.lib.loss
use neurx.lib.tensor.{vector, matrix, create_vector, create_matrix, vector_scale, vector_subtract, matrix_scale}
struct mse_loss {
    string name
}

struct cross_entropy_loss {
    float epsilon
    string name
}

struct bceloss {
    float epsilon
    string name
}

struct smooth_l1_loss {
    float delta
    string name
}
func create_mse_loss() mse_loss {
    mse_loss loss
    loss.name = "MSE"
    loss
}

func mse_loss_forward(vector pred, vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    float sum = 0.0
    int i = 0
    while i < pred.size {
        float diff = pred.data[i] - target.data[i]
        sum = sum + diff * diff
        i = i + 1
    }
    sum / (pred.size as float)
}

func mse_loss_backward(vector pred, vector target) vector {
    if pred.size != target.size {
        return create_vector(pred.size)
    }
    vector grad = create_vector(pred.size)
    float scale = 2.0 / (pred.size as float)
    int i = 0
    while i < pred.size {
        grad.data[i] = scale * (pred.data[i] - target.data[i])
        i = i + 1
    }
    grad
}

func create_cross_entropy_loss() cross_entropy_loss {
    cross_entropy_loss loss
    loss.epsilon = 0.0000001
    loss.name = "CrossEntropy"
    loss
}

func cross_entropy_loss_forward(vector pred, vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    float loss = 0.0
    int i = 0
    while i < pred.size {
        float p = pred.data[i]
        if p < 0.0000001 {
            p = 0.0000001
        }
        if p > 0.9999999 {
            p = 0.9999999
        }
        float log_p = 0.0
        if p > 0.0 {
            float x = p - 1.0
            log_p = x
            int j = 2
            float term = x
            while j < 5 {
                term = term * x
                int sign = 1
                if j % 2 == 0 {
                    sign = -1
                }
                log_p = log_p + sign as float * term / (j as float)
                j = j + 1
            }
        }
        loss = loss - target.data[i] * log_p
        i = i + 1
    }
    loss / (pred.size as float)
}

func cross_entropy_loss_backward(vector pred, vector target) vector {
    if pred.size != target.size {
        return create_vector(pred.size)
    }
    vector grad = create_vector(pred.size)
    float scale = 1.0 / (pred.size as float)
    int i = 0
    while i < pred.size {
        grad.data[i] = scale * (pred.data[i] - target.data[i])
        i = i + 1
    }
    grad
}

func create_bce_loss() bceloss {
    bceloss loss
    loss.epsilon = 0.0000001
    loss.name = "BCE"
    loss
}

func bce_loss_forward(vector pred, vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    float loss = 0.0
    int i = 0
    while i < pred.size {
        float p = pred.data[i]
        if p < 0.0000001 {
            p = 0.0000001
        }
        if p > 0.9999999 {
            p = 0.9999999
        }
        float y = target.data[i]
        float log_p = 0.0
        if p > 0.0 {
            float x = p - 1.0
            log_p = x
            int j = 2
            float term = x
            while j < 5 {
                term = term * x
                int sign = 1
                if j % 2 == 0 {
                    sign = -1
                }
                log_p = log_p + sign as float * term / (j as float)
                j = j + 1
            }
        }
        float log_1_p = 0.0
        float one_minus_p = 1.0 - p
        if one_minus_p > 0.0 {
            float x = one_minus_p - 1.0
            log_1_p = x
            int j = 2
            float term = x
            while j < 5 {
                term = term * x
                int sign = 1
                if j % 2 == 0 {
                    sign = -1
                }
                log_1_p = log_1_p + sign as float * term / (j as float)
                j = j + 1
            }
        }
        loss = loss - (y * log_p + (1.0 - y) * log_1_p)
        i = i + 1
    }
    loss / (pred.size as float)
}

func create_smooth_l1_loss() smooth_l1_loss {
    smooth_l1_loss loss
    loss.delta = 1.0
    loss.name = "SmoothL1"
    loss
}

func smooth_l1_loss_forward(vector pred, vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    float loss = 0.0
    int i = 0
    while i < pred.size {
        float diff = pred.data[i] - target.data[i]
        if diff < 0.0 {
            diff = 0.0 - diff
        }
        float delta = 1.0
        float element_loss = 0.0
        if diff < delta {
            element_loss = 0.5 * diff * diff
        } else {
            element_loss = delta * (diff - 0.5 * delta)
        }
        loss = loss + element_loss
        i = i + 1
    }
    loss / (pred.size as float)
}

struct sgd_optimizer {
    float learning_rate
    float momentum
    float weight_decay
    vector velocity
}

struct adam_optimizer {
    float learning_rate
    float beta1
    float beta2
    float epsilon
    int step_count
    vector m
    vector v
}

func create_sgd_optimizer(float lr, float momentum, float weight_decay) sgd_optimizer {
    sgd_optimizer opt
    opt.learning_rate = lr
    opt.momentum = momentum
    opt.weight_decay = weight_decay
    opt
}

func sgd_step(sgd_optimizer opt, vector params, vector grads) vector {
    if params.size != grads.size {
        return params
    }
    if opt.velocity.size == 0 {
        opt.velocity = create_vector(params.size)
    }
    vector updated = create_vector(params.size)
    int i = 0
    while i < params.size {
        float grad = grads.data[i] + opt.weight_decay * params.data[i]
        opt.velocity.data[i] = opt.momentum * opt.velocity.data[i] - opt.learning_rate * grad
        updated.data[i] = params.data[i] + opt.velocity.data[i]
        i = i + 1
    }
    updated
}

func create_adam_optimizer(float lr) adam_optimizer {
    adam_optimizer opt
    opt.learning_rate = lr
    opt.beta1 = 0.9
    opt.beta2 = 0.999
    opt.epsilon = 0.00000001
    opt.step_count = 0
    opt
}

func adam_step(adam_optimizer opt, vector params, vector grads) vector {
    if params.size != grads.size {
        return params
    }
    if opt.m.size == 0 {
        opt.m = create_vector(params.size)
        opt.v = create_vector(params.size)
    }
    opt.step_count = opt.step_count + 1
    vector updated = create_vector(params.size)
    int i = 0
    while i < params.size {
        opt.m.data[i] = opt.beta1 * opt.m.data[i] + (1.0 - opt.beta1) * grads.data[i]
        float grad_sq = grads.data[i] * grads.data[i]
        opt.v.data[i] = opt.beta2 * opt.v.data[i] + (1.0 - opt.beta2) * grad_sq
        float m_hat = opt.m.data[i] / (1.0 - (opt.beta1 ^ (opt.step_count as float)))
        float v_hat = opt.v.data[i] / (1.0 - (opt.beta2 ^ (opt.step_count as float)))
        float sqrt_v_hat = v_hat
        int j = 0
        while j < 10 {
            sqrt_v_hat = (sqrt_v_hat + v_hat / sqrt_v_hat) * 0.5
            j = j + 1
        }
        updated.data[i] = params.data[i] - opt.learning_rate * m_hat / (sqrt_v_hat + opt.epsilon)
        i = i + 1
    }
    updated
}

struct rmsprop_optimizer {
    float learning_rate
    float alpha
    float epsilon
    vector mean_square
}

func create_rmsprop_optimizer(float lr) rmsprop_optimizer {
    rmsprop_optimizer opt
    opt.learning_rate = lr
    opt.alpha = 0.99
    opt.epsilon = 0.00000001
    opt
}

func rmsprop_step(rmsprop_optimizer opt, vector params, vector grads) vector {
    if params.size != grads.size {
        return params
    }
    if opt.mean_square.size == 0 {
        opt.mean_square = create_vector(params.size)
    }
    vector updated = create_vector(params.size)
    int i = 0
    while i < params.size {
        float grad_sq = grads.data[i] * grads.data[i]
        opt.mean_square.data[i] = opt.alpha * opt.mean_square.data[i] + (1.0 - opt.alpha) * grad_sq
        float sqrt_mean_sq = opt.mean_square.data[i]
        int j = 0
        while j < 10 {
            sqrt_mean_sq = (sqrt_mean_sq + opt.mean_square.data[i] / sqrt_mean_sq) * 0.5
            j = j + 1
        }
        updated.data[i] = params.data[i] - opt.learning_rate * grads.data[i] / (sqrt_mean_sq + opt.epsilon)
        i = i + 1
    }
    updated
}
