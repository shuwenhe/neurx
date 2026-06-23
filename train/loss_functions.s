package neurx.train.loss_functions

// =====================================================================
// Cross-Entropy Loss Implementation for Language Model Training
// =====================================================================
// Implements:
// - Standard Cross-Entropy Loss for classification
// - Label smoothing support
// - Numerical stability (log-sum-exp trick)
// - Perplexity calculation

// =====================================================================
// Configuration
// =====================================================================

struct cross_entropy_config {
    bool use_label_smoothing
    float smoothing_alpha         // typically 0.1
    bool reduction_mean           // true: mean, false: sum
    int vocab_size
}

// =====================================================================
// Core Loss Computation
// =====================================================================

// Compute softmax with numerical stability
// logits: raw scores [batch_size, vocab_size]
// Returns: probabilities [batch_size, vocab_size]
func softmax_stable(
    []float logits,
    int batch_size,
    int vocab_size
) []float {
    []float probs = allocate_vector(batch_size * vocab_size, 0.0)
    
    int b = 0
    while b < batch_size {
        int base = b * vocab_size
        
        // Find max for numerical stability
        float max_logit = logits[base]
        int c = 1
        while c < vocab_size {
            if logits[base + c] > max_logit {
                max_logit = logits[base + c]
            }
            c = c + 1
        }
        
        // Compute exp(logits - max_logit)
        float sum_exp = 0.0
        c = 0
        while c < vocab_size {
            float exp_val = exp_float(logits[base + c] - max_logit)
            probs[base + c] = exp_val
            sum_exp = sum_exp + exp_val
            c = c + 1
        }
        
        // Normalize
        c = 0
        while c < vocab_size {
            probs[base + c] = probs[base + c] / sum_exp
            c = c + 1
        }
        
        b = b + 1
    }
    
    return probs
}

// Compute log softmax with numerical stability
// logits: raw scores [batch_size, vocab_size]
// Returns: log(softmax(logits)) [batch_size, vocab_size]
func log_softmax_stable(
    []float logits,
    int batch_size,
    int vocab_size
) []float {
    []float log_probs = allocate_vector(batch_size * vocab_size, 0.0)
    
    int b = 0
    while b < batch_size {
        int base = b * vocab_size
        
        // Find max for numerical stability
        float max_logit = logits[base]
        int c = 1
        while c < vocab_size {
            if logits[base + c] > max_logit {
                max_logit = logits[base + c]
            }
            c = c + 1
        }
        
        // Compute log_sum_exp
        float sum_exp = 0.0
        c = 0
        while c < vocab_size {
            float exp_val = exp_float(logits[base + c] - max_logit)
            sum_exp = sum_exp + exp_val
            c = c + 1
        }
        float log_sum_exp = log_float(sum_exp) + max_logit
        
        // Compute log(softmax)
        c = 0
        while c < vocab_size {
            log_probs[base + c] = logits[base + c] - log_sum_exp
            c = c + 1
        }
        
        b = b + 1
    }
    
    return log_probs
}

// Cross-Entropy Loss
// logits: [batch_size, vocab_size] - raw model outputs
// target_indices: [batch_size] - ground truth token indices
// Returns: scalar loss value
func cross_entropy_loss(
    []float logits,
    []int target_indices,
    cross_entropy_config config
) float {
    int batch_size = length(target_indices)
    int vocab_size = config.vocab_size
    
    // Get log probabilities
    []float log_probs = log_softmax_stable(logits, batch_size, vocab_size)
    
    // Compute loss
    float total_loss = 0.0
    int valid_count = 0
    
    int b = 0
    while b < batch_size {
        int target_idx = target_indices[b]
        
        // Validate target index
        if target_idx < 0 || target_idx >= vocab_size {
            b = b + 1
            continue
        }
        
        int base = b * vocab_size
        float log_prob = log_probs[base + target_idx]
        
        // Apply label smoothing if enabled
        if config.use_label_smoothing {
            float uniform_prob = 1.0 / float(vocab_size)
            float smoothed_prob = (1.0 - config.smoothing_alpha) * log_prob + 
                                  config.smoothing_alpha * log_float(uniform_prob)
            total_loss = total_loss - smoothed_prob
        } else {
            total_loss = total_loss - log_prob
        }
        
        valid_count = valid_count + 1
        b = b + 1
    }
    
    // Apply reduction
    if config.reduction_mean  valid_count > 0 {
        return total_loss / float(valid_count)
    }
    
    return total_loss
}

// Cross-Entropy Loss with mask support (for sequence masking)
// logits: [batch_size * seq_len, vocab_size] - flattened
// target_indices: [batch_size * seq_len] - flattened targets
// attention_mask: [batch_size * seq_len] - 1 for valid positions, 0 for padding
// Returns: scalar loss value
func cross_entropy_loss_masked(
    []float logits,
    []int target_indices,
    []int attention_mask,
    cross_entropy_config config
) float {
    int seq_len = length(target_indices)
    int vocab_size = config.vocab_size
    int batch_size = 1  // When flattened, conceptually batch_size * seq_len
    
    // Get log probabilities
    []float log_probs = log_softmax_stable(logits, seq_len, vocab_size)
    
    // Compute masked loss
    float total_loss = 0.0
    int valid_count = 0
    
    int i = 0
    while i < seq_len {
        // Skip if masked out
        if attention_mask[i] == 0 {
            i = i + 1
            continue
        }
        
        int target_idx = target_indices[i]
        
        // Validate target index
        if target_idx < 0 || target_idx >= vocab_size {
            i = i + 1
            continue
        }
        
        int base = i * vocab_size
        float log_prob = log_probs[base + target_idx]
        
        // Apply label smoothing if enabled
        if config.use_label_smoothing {
            float uniform_prob = 1.0 / float(vocab_size)
            float smoothed_log_prob = (1.0 - config.smoothing_alpha) * log_prob + 
                                      config.smoothing_alpha * log_float(uniform_prob)
            total_loss = total_loss - smoothed_log_prob
        } else {
            total_loss = total_loss - log_prob
        }
        
        valid_count = valid_count + 1
        i = i + 1
    }
    
    // Apply reduction
    if config.reduction_mean  valid_count > 0 {
        return total_loss / float(valid_count)
    }
    
    return total_loss
}

// =====================================================================
// Perplexity Calculation
// =====================================================================

// Compute perplexity from loss
// perplexity = exp(loss)
func compute_perplexity(float loss) float {
    return exp_float(loss)
}

// Compute perplexity directly from logits
// logits: [batch_size, vocab_size]
// target_indices: [batch_size]
func compute_perplexity_direct(
    []float logits,
    []int target_indices,
    cross_entropy_config config
) float {
    float loss = cross_entropy_loss(logits, target_indices, config)
    return compute_perplexity(loss)
}

// =====================================================================
// Label Smoothing Helper
// =====================================================================

// Apply label smoothing to target probability distribution
// Creates uniform distribution mixed with original labels
func apply_label_smoothing(
    []int target_indices,
    int vocab_size,
    float smoothing_alpha
) []float {
    int batch_size = length(target_indices)
    []float smoothed = allocate_vector(batch_size * vocab_size, 0.0)
    
    float uniform_prob = smoothing_alpha / float(vocab_size)
    float target_prob = 1.0 - smoothing_alpha + (smoothing_alpha / float(vocab_size))
    
    int b = 0
    while b < batch_size {
        int base = b * vocab_size
        int target_idx = target_indices[b]
        
        // Set all positions to uniform probability
        int c = 0
        while c < vocab_size {
            smoothed[base + c] = uniform_prob
            c = c + 1
        }
        
        // Increase probability of target class
        if target_idx >= 0  target_idx < vocab_size {
            smoothed[base + target_idx] = target_prob
        }
        
        b = b + 1
    }
    
    return smoothed
}

// =====================================================================
// Helper Functions
// =====================================================================

// Exponential function with numerical stability
func exp_float(float x) float {
    if x > 20.0 {
        return 2147483647.0  // Large value
    }
    if x < -20.0 {
        return 0.0000001  // Small value
    }
    
    // Taylor series approximation
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 15 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    
    return result
}

// Natural logarithm with numerical stability
func log_float(float x) float {
    if x <= 0.0 {
        return -20.0  // Large negative value
    }
    if x == 1.0 {
        return 0.0
    }
    
    // Approximation for better numerical accuracy
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    float y7 = y5 * y2
    float y9 = y7 * y2
    
    return 2.0 * (y + (y3 / 3.0) + (y5 / 5.0) + (y7 / 7.0) + (y9 / 9.0))
}

// Allocate float vector
func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v.push(init_val)
        i = i + 1
    }
    return v
}

// Get vector length
func length([]float v) int {
    return len(v)
}

func length([]int v) int {
    return len(v)
}

// Create default config
func new_cross_entropy_config(int vocab_size) cross_entropy_config {
    cross_entropy_config config
    config.vocab_size = vocab_size
    config.use_label_smoothing = false
    config.smoothing_alpha = 0.1
    config.reduction_mean = true
    return config
}
