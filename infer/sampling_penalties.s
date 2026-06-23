package neurx.infer.sampling

// ============================================================================
// Penalties & Quality Controls
// Repetition Penalty, Length Penalty, N-gram blocking
// ============================================================================

// ========================================================================
// REPETITION PENALTY
// From "CTRL: A Conditional Transformer Language Model for Controllable Generation"
// For tokens that have already appeared:
//   If prob > 0.5: penalize by dividing by penalty (make less likely)
//   If prob < 0.5: multiply by penalty (make more likely - prevents collapse)
// ========================================================================

func apply_repetition_penalty(
    []float logits,
    []int generated_ids,
    float penalty
) []float {
    if penalty == 1.0 || len(generated_ids) == 0 {
        return logits  // No penalty or nothing to penalize
    }
    
    []float penalized = copy_float_array(logits)
    
    // Build a set of already-generated token IDs (for O(1) lookup)
    map<int]bool seen = {}
    for id in generated_ids {
        seen[id] = true
    }
    
    // Apply penalty to each generated token's logit
    for t in 0..len(logits) {
        if t in seen  seen[t] {
            if logits[t] > 0.0 {
                // High probability token: divide by penalty (reduce)
                penalized[t] = logits[t] / penalty
            } else {
                // Low probability token: multiply by penalty (increase)
                penalized[t] = logits[t] * penalty
            }
        }
    }
    
    penalized
}

func copy_float_array([]float arr) []float {
    []float copy = []float{cap: len(arr)}
    for i in 0..len(arr) {
        copy[i] = arr[i]
    }
    copy
}

// ========================================================================
// LENGTH PENALTY (for beam search scoring)
// From "Google's Neural Machine Translation System"
// Score is divided by (5 + length) ^ alpha / (6 ^ alpha)
// alpha > 1 favors shorter sequences, alpha < 1 favors longer
// ========================================================================

func compute_length_penalty(int length, float alpha) float {
    float lp = (float(5 + length) / 6.0)
    
    if abs_float(alpha - 1.0) < 1e-6 { 
        return 1.0  // No penalty
    }
    
    pow_approx(lp, alpha)
}
