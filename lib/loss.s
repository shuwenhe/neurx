package neurx.lib.loss

// Loss functions and optimizers for S language training
// Implements common loss functions and gradient-based optimization algorithms

use neurx.lib.tensor.{Vector, Matrix, create_vector, create_matrix, vector_scale, vector_subtract, matrix_scale}

// Mean Squared Error Loss
struct MSELoss {
    string name
}

// Cross-Entropy Loss
struct CrossEntropyLoss {
    float epsilon
    string name
}

// Binary Cross-Entropy Loss
struct BCELoss {
    float epsilon
    string name
}

// Smooth L1 Loss (Huber Loss)
struct SmoothL1Loss {
    float delta
    string name
}

// Creates MSE loss
func create_mse_loss() MSELoss {
    MSELoss loss
    loss.name = "MSE"
    loss
}

// Computes MSE loss: mean((y_pred - y_true)^2)
func mse_loss_forward(Vector pred, Vector target) float {
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

// Computes MSE loss gradient: 2 * (y_pred - y_true) / N
func mse_loss_backward(Vector pred, Vector target) Vector {
    if pred.size != target.size {
        return create_vector(pred.size)
    }
    
    Vector grad = create_vector(pred.size)
    float scale = 2.0 / (pred.size as float)
    
    int i = 0
    while i < pred.size {
        grad.data[i] = scale * (pred.data[i] - target.data[i])
        i = i + 1
    }
    
    grad
}

// Creates cross-entropy loss
func create_cross_entropy_loss() CrossEntropyLoss {
    CrossEntropyLoss loss
    loss.epsilon = 0.0000001  // 1e-7 for numerical stability
    loss.name = "CrossEntropy"
    loss
}

// Cross-entropy loss: -sum(y_true * log(y_pred))
func cross_entropy_loss_forward(Vector pred, Vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    
    float loss = 0.0
    int i = 0
    while i < pred.size {
        float p = pred.data[i]
        
        // Clamp to [epsilon, 1-epsilon]
        if p < 0.0000001 {
            p = 0.0000001
        }
        if p > 0.9999999 {
            p = 0.9999999
        }
        
        // Compute log(p) using Taylor series approximation
        float log_p = 0.0
        if p > 0.0 {
            // log(p) approximation
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

// Cross-entropy loss gradient: (y_pred - y_true) / N
func cross_entropy_loss_backward(Vector pred, Vector target) Vector {
    if pred.size != target.size {
        return create_vector(pred.size)
    }
    
    Vector grad = create_vector(pred.size)
    float scale = 1.0 / (pred.size as float)
    
    int i = 0
    while i < pred.size {
        grad.data[i] = scale * (pred.data[i] - target.data[i])
        i = i + 1
    }
    
    grad
}

// Creates binary cross-entropy loss
func create_bce_loss() BCELoss {
    BCELoss loss
    loss.epsilon = 0.0000001
    loss.name = "BCE"
    loss
}

// Binary cross-entropy loss
func bce_loss_forward(Vector pred, Vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    
    float loss = 0.0
    int i = 0
    while i < pred.size {
        float p = pred.data[i]
        
        // Clamp to [epsilon, 1-epsilon]
        if p < 0.0000001 {
            p = 0.0000001
        }
        if p > 0.9999999 {
            p = 0.9999999
        }
        
        float y = target.data[i]
        
        // BCE: -[y*log(p) + (1-y)*log(1-p)]
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

// Creates smooth L1 loss
func create_smooth_l1_loss() SmoothL1Loss {
    SmoothL1Loss loss
    loss.delta = 1.0
    loss.name = "SmoothL1"
    loss
}

// Smooth L1 (Huber) loss
func smooth_l1_loss_forward(Vector pred, Vector target) float {
    if pred.size != target.size {
        return 0.0
    }
    
    float loss = 0.0
    int i = 0
    while i < pred.size {
        float diff = pred.data[i] - target.data[i]
        
        // Absolute value
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

// ===== OPTIMIZERS =====

// SGD optimizer state
struct SGDOptimizer {
    float learning_rate
    float momentum
    float weight_decay
    Vector velocity  // For momentum
}

// Adam optimizer state
struct AdamOptimizer {
    float learning_rate
    float beta1
    float beta2
    float epsilon
    int step_count
    Vector m  // First moment estimate
    Vector v  // Second moment estimate
}

// Creates SGD optimizer
func create_sgd_optimizer(float lr, float momentum, float weight_decay) SGDOptimizer {
    SGDOptimizer opt
    opt.learning_rate = lr
    opt.momentum = momentum
    opt.weight_decay = weight_decay
    opt
}

// SGD update step
func sgd_step(SGDOptimizer opt, Vector params, Vector grads) Vector {
    if params.size != grads.size {
        return params
    }
    
    // Initialize velocity if needed
    if opt.velocity.size == 0 {
        opt.velocity = create_vector(params.size)
    }
    
    Vector updated = create_vector(params.size)
    
    int i = 0
    while i < params.size {
        // Gradient with weight decay
        float grad = grads.data[i] + opt.weight_decay * params.data[i]
        
        // Update velocity (momentum)
        opt.velocity.data[i] = opt.momentum * opt.velocity.data[i] - opt.learning_rate * grad
        
        // Update parameter
        updated.data[i] = params.data[i] + opt.velocity.data[i]
        
        i = i + 1
    }
    
    updated
}

// Creates Adam optimizer
func create_adam_optimizer(float lr) AdamOptimizer {
    AdamOptimizer opt
    opt.learning_rate = lr
    opt.beta1 = 0.9
    opt.beta2 = 0.999
    opt.epsilon = 0.00000001  // 1e-8
    opt.step_count = 0
    opt
}

// Adam update step
func adam_step(AdamOptimizer opt, Vector params, Vector grads) Vector {
    if params.size != grads.size {
        return params
    }
    
    // Initialize moment estimates if needed
    if opt.m.size == 0 {
        opt.m = create_vector(params.size)
        opt.v = create_vector(params.size)
    }
    
    opt.step_count = opt.step_count + 1
    
    Vector updated = create_vector(params.size)
    
    int i = 0
    while i < params.size {
        // Update biased first moment estimate
        opt.m.data[i] = opt.beta1 * opt.m.data[i] + (1.0 - opt.beta1) * grads.data[i]
        
        // Update biased second moment estimate
        float grad_sq = grads.data[i] * grads.data[i]
        opt.v.data[i] = opt.beta2 * opt.v.data[i] + (1.0 - opt.beta2) * grad_sq
        
        // Compute bias-corrected first moment estimate
        float m_hat = opt.m.data[i] / (1.0 - (opt.beta1 ^ (opt.step_count as float)))
        
        // Compute bias-corrected second raw moment estimate
        float v_hat = opt.v.data[i] / (1.0 - (opt.beta2 ^ (opt.step_count as float)))
        
        // Compute square root of v_hat
        float sqrt_v_hat = v_hat
        int j = 0
        while j < 10 {
            sqrt_v_hat = (sqrt_v_hat + v_hat / sqrt_v_hat) * 0.5
            j = j + 1
        }
        
        // Update parameter
        updated.data[i] = params.data[i] - opt.learning_rate * m_hat / (sqrt_v_hat + opt.epsilon)
        
        i = i + 1
    }
    
    updated
}

// RMSprop optimizer state
struct RMSpropOptimizer {
    float learning_rate
    float alpha
    float epsilon
    Vector mean_square  // Moving average of squared gradients
}

// Creates RMSprop optimizer
func create_rmsprop_optimizer(float lr) RMSpropOptimizer {
    RMSpropOptimizer opt
    opt.learning_rate = lr
    opt.alpha = 0.99
    opt.epsilon = 0.00000001
    opt
}

// RMSprop update step
func rmsprop_step(RMSpropOptimizer opt, Vector params, Vector grads) Vector {
    if params.size != grads.size {
        return params
    }
    
    // Initialize mean square if needed
    if opt.mean_square.size == 0 {
        opt.mean_square = create_vector(params.size)
    }
    
    Vector updated = create_vector(params.size)
    
    int i = 0
    while i < params.size {
        float grad_sq = grads.data[i] * grads.data[i]
        
        // Update moving average of squared gradients
        opt.mean_square.data[i] = opt.alpha * opt.mean_square.data[i] + (1.0 - opt.alpha) * grad_sq
        
        // Compute denominator
        float sqrt_mean_sq = opt.mean_square.data[i]
        int j = 0
        while j < 10 {
            sqrt_mean_sq = (sqrt_mean_sq + opt.mean_square.data[i] / sqrt_mean_sq) * 0.5
            j = j + 1
        }
        
        // Update parameter
        updated.data[i] = params.data[i] - opt.learning_rate * grads.data[i] / (sqrt_mean_sq + opt.epsilon)
        
        i = i + 1
    }
    
    updated
}
