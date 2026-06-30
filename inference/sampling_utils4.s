package neurx.inference.sampling

// ============================================================================
// Random Sampling & Beam Selection
// ============================================================================

// ========================================================================
// SAMPLE FROM DISTRIBUTION (Alias method or simple linear scan)
// Given a probability distribution, return a sampled index
// ========================================================================

func sample_from_distribution([]float probs, uint64 rng_state) int {
    if len(probs) == 0 { return -1 }
    
    // Generate random number in [0, 1)
    float r = random_float_01(advance_rng(rng_state))
    
    // Linear scan through CDF
    float cumsum = 0.0
    
    for i in 0..len(probs) {
        cumsum = cumsum + probs[i]
        if r < cumsum {
            return i
        }
    }
    
    // Fallback: return last index (handles floating point rounding)
    len(probs) - 1
}

// ========================================================================
// SAMPLE FROM SOFTMAX (convenience function)
// Apply temperature + softmax + sample in one call
// ========================================================================

func sample_from_softmax(
    []float logits,
    float temperature,
    uint64 rng_state
) (int, uint64) {
    []float scaled = apply_temperature(logits, temperature)
    []float probs = softmax(scaled)
    
    int idx = sample_from_distribution(probs, rng_state)
    
    (idx, advance_rng(rng_state))
}
