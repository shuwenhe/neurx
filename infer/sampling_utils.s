package neurx.infer.sampling

// ============================================================================
// Sampling Utility Functions
// Softmax, Temperature, Normalization, Repetition Penalty, etc.
// ============================================================================

// ========================================================================
// SOFTMAX (Numerically stable with max subtraction)
// ========================================================================

func softmax([]float logits) []float {
    if len(logits) == 0 { return [] }
    
    // Find max for numerical stability
    float max_val = logits[0]
    for i in 1..len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
        }
    }
    
    // Compute exp(x - max) and sum
    []float exp_vals = []float{cap: len(logits)}
    float sum_exp = 0.0
    
    for i in 0..len(logits) {
        float val = exp_approx(logits[i] - max_val)
        exp_vals[i] = val
        sum_exp = sum_exp + val
    }
    
    // Normalize to probabilities
    []float probs = []float{cap: len(logits)}
    for i in 0..len(logits) {
        if sum_exp > 1e-10 {
            probs[i] = exp_vals[i] / sum_exp
        } else {
            // Edge case: all logits were -inf or similar
            probs[i] = 1.0 / float(len(logits))
        }
    }
    
    probs
}

// Log-softmax (more numerically stable than log(softmax(x)))
func log_softmax([]float logits) []float {
    if len(logits) == 0 { return [] }
    
    // Find max for numerical stability
    float max_val = logits[0]
    for i in 1..len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
        }
    }
    
    // Compute log-sum-exp
    float sum_exp = 0.0
    for i in 0..len(logits) {
        sum_exp = sum_exp + exp_approx(logits[i] - max_val)
    }
    
    float log_sum_exp = log_approx(sum_exp) + max_val
    
    // Compute log-probabilities
    []float log_probs = []float{cap: len(logits)}
    for i in 0..len(logits) {
        log_probs[i] = logits[i] - log_sum_exp
    }
    
    log_probs
}
