package neurx.loss.cross_entropy
use std.io.eprintln

// CrossEntropy Loss for language modeling
// Input: logits [batch_size, seq_len, vocab_size]
// Target: labels [batch_size, seq_len] (token IDs)

func cross_entropy_loss(
    []float logits,         // [batch_size * seq_len * vocab_size]
    []int labels,           // [batch_size * seq_len]
    int batch_size,
    int seq_len,
    int vocab_size,
    int ignore_index        // -100 or pad_token_id
) float {
    float total_loss = 0.0
    int valid_count = 0
    
    int i = 0
    while i < batch_size * seq_len {
        int label = labels[i]
        
        // Skip padding tokens
        if label == ignore_index {
            i = i + 1
            continue
        }
        
        // Clamp label to valid range
        if label < 0 { label = 0 }
        if label >= vocab_size { label = vocab_size - 1 }
        
        // Get logits for this position
        int logits_offset = i * vocab_size
        
        // Compute log_softmax
        float max_logit = logits[logits_offset]
        int j = 1
        while j < vocab_size {
            if logits[logits_offset + j] > max_logit {
                max_logit = logits[logits_offset + j]
            }
            j = j + 1
        }
        
        // Compute exp sum
        float sum_exp = 0.0
        j = 0
        while j < vocab_size {
            float exp_val = exp_approx(logits[logits_offset + j] - max_logit)
            sum_exp = sum_exp + exp_val
            j = j + 1
        }
        
        float log_sum_exp = log_approx(sum_exp)
        
        // log_softmax[label] = logits[label] - max_logit - log_sum_exp
        float log_prob = logits[logits_offset + label] - max_logit - log_sum_exp
        
        // NLL loss: -log_prob
        total_loss = total_loss - log_prob
        valid_count = valid_count + 1
        
        i = i + 1
    }
    
    if valid_count == 0 { return 0.0 }
    total_loss / (valid_count as float)
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / (i as float)
        result = result + term
        i = i + 1
    }
    result
}

func log_approx(float x) float {
    if x <= 0.0 { return -10.0 }
    if x == 1.0 { return 0.0 }
    
    // log(x) = log(1 + (x-1)) using Taylor series
    // For better convergence, use log(x) = 2 * atanh((x-1)/(x+1))
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float result = y
    float term = y
    
    int i = 1
    while i < 10 {
        term = term * y2
        result = result + term / ((2 * i + 1) as float)
        i = i + 1
    }
    
    result * 2.0
}

// Compute gradients for cross entropy loss
func cross_entropy_gradient(
    []float logits,         // [batch_size * seq_len * vocab_size]
    []int labels,           // [batch_size * seq_len]
    int batch_size,
    int seq_len,
    int vocab_size,
    int ignore_index
) []float {
    []float grad = []float{cap: batch_size * seq_len * vocab_size}
    
    int i = 0
    while i < batch_size * seq_len {
        int label = labels[i]
        int logits_offset = i * vocab_size
        
        if label == ignore_index {
            // Zero gradient for ignored positions
            int j = 0
            while j < vocab_size {
                grad[logits_offset + j] = 0.0
                j = j + 1
            }
            i = i + 1
            continue
        }
        
        // Clamp label
        if label < 0 { label = 0 }
        if label >= vocab_size { label = vocab_size - 1 }
        
        // Compute softmax
        float max_logit = logits[logits_offset]
        int j = 1
        while j < vocab_size {
            if logits[logits_offset + j] > max_logit {
                max_logit = logits[logits_offset + j]
            }
            j = j + 1
        }
        
        float sum_exp = 0.0
        j = 0
        while j < vocab_size {
            float exp_val = exp_approx(logits[logits_offset + j] - max_logit)
            sum_exp = sum_exp + exp_val
            j = j + 1
        }
        
        // Gradient: softmax(logits) - one_hot(label)
        j = 0
        while j < vocab_size {
            float prob = exp_approx(logits[logits_offset + j] - max_logit) / sum_exp
            if j == label {
                grad[logits_offset + j] = prob - 1.0
            } else {
                grad[logits_offset + j] = prob
            }
            j = j + 1
        }
        
        i = i + 1
    }
    
    grad
}

// Compute perplexity from loss
func perplexity_from_loss(float loss) float {
    exp_approx(loss)
}
