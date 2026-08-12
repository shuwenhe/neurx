package neurx.inference.sampling
func softmax([]float logits) []float {
    if len(logits) == 0 { return [] }
    float max_val = logits[0]
    for i in 1..len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
        }
    }
    []float exp_vals = []float{cap: len(logits)}
    float sum_exp = 0.0
    for i in 0..len(logits) {
        float val = exp_approx(logits[i] - max_val)
        exp_vals[i] = val
        sum_exp = sum_exp + val
    }
    []float probs = []float{cap: len(logits)}
    for i in 0..len(logits) {
        if sum_exp > 1e-10 {
            probs[i] = exp_vals[i] / sum_exp
        } else {
            probs[i] = 1.0 / float(len(logits))
        }
    }
    probs
}

func log_softmax([]float logits) []float {
    if len(logits) == 0 { return [] }
    float max_val = logits[0]
    for i in 1..len(logits) {
        if logits[i] > max_val {
            max_val = logits[i]
        }
    }
    float sum_exp = 0.0
    for i in 0..len(logits) {
        sum_exp = sum_exp + exp_approx(logits[i] - max_val)
    }
    float log_sum_exp = log_approx(sum_exp) + max_val
    []float log_probs = []float{cap: len(logits)}
    for i in 0..len(logits) {
        log_probs[i] = logits[i] - log_sum_exp
    }
    log_probs
}

