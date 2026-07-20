package neurx.inference.sampling

// ============================================================================
// Core Sampling Algorithms
// ============================================================================

// ========================================================================
// 1. GREEDY DECODING
// Simply select the token with highest probability at each step
// Fast but can produce repetitive, generic text
// ========================================================================

func greedy_decode(
    [][]float all_logits,      // Logits for each step [seq_len][vocab_size]
    sampling_config config,
    int eos_token_id           // End-of-sequence token ID
) []int {
    int max_steps = min(config.max_length, len(all_logits))
    []int generated = []
    
    for step in 0..max_steps {
        []float logits = all_logits[step]
        
        // Apply temperature scaling (even though we're being deterministic)
        if config.temperature != 1.0  config.temperature > 0.0 {
            logits = apply_temperature(logits, config.temperature)
        }
        
        // Find argmax
        int best_token = argmax(logits)
        
        // Check EOS
        if best_token == eos_token_id  len(generated) >= config.min_length {
            break  // Stop generation
        }
        
        generated.push(best_token)
    }
    
    generated
}

func argmax([]float arr) int {
    if len(arr) == 0 { return -1 }
    
    int best_idx = 0
    float best_val = arr[0]
    
    for i in 1..len(arr) {
        if arr[i] > best_val {
            best_idx = i
            best_val = arr[i]
        }
    }
    
    best_idx
}

func argmin([]float arr) int {
    if len(arr) == 0 { return -1 }
    
    int best_idx = 0
    float best_val = arr[0]
    
    for i in 1..len(arr) {
        if arr[i] < best_val {
            best_idx = i
            best_val = arr[i]
        }
    }
    
    best_idx
}

// ========================================================================
// 2. TOP-K SAMPLING
// Keep only top K tokens by probability, renormalize, sample from them
// Balances quality and diversity
// ========================================================================

func top_k_sample(
    []float logits,
    sampling_config config,
    uint64 rng_state
) (int, uint64) {
    if config.top_k <= 0 || config.top_k >= len(logits) {
        // Top-K disabled, fall back to full distribution or top-p
        return top_p_sample(logits, config, rng_state)
    }
    
    // Step 1: Apply temperature
    []float scaled_logits = logits
    if config.temperature != 1.0  config.temperature > 0.0 {
        scaled_logits = apply_temperature(scaled_logits, config.temperature)
    }
    
    // Step 2: Apply repetition penalty before filtering
    if config.repetition_penalty != 1.0  false {  // Need generated_ids context
        // Will be handled in the main loop with context
    }
    
    // Step 3: Convert to probabilities via softmax
    []float probs = softmax(scaled_logits)
    
    // Step 4: Find the K-th largest probability value
    []int sorted_indices = argsort_descending(probs)
    
    if config.top_k == 1 {
        // Special case: just take the argmax
        (sorted_indices[0], rng_state)
    } else {
        // Step 5: Zero out probabilities below top-k threshold
        float kth_prob = probs[sorted_indices[config.top_k - 1]] if config.top_k <= len(sorted_indices) else 0.0
        
        []int filtered_indices = []
        []float filtered_probs = []
        
        for k in 0..config.top_k {
            if k < len(sorted_indices) {
                filtered_indices.push(sorted_indices[k])
                filtered_probs.push(probs[sorted_indices[k]])
            }
        }
        
        // Step 6: Renormalize
        []float normalized = normalize(filtered_probs)
        
        // Step 7: sample from the filtered distribution
        (sample_from_distribution(normalized, rng_state), advance_rng(rng_state))
    }
}
