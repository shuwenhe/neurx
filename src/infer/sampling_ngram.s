package neurx.infer.sampling

// ============================================================================
// N-Gram Blocking & Beam Selection
// ============================================================================

// ========================================================================
// NO-REPEAT N-GRAM BLOCKING
// Prevent generating n-grams that have already appeared
// E.g., with trigram blocking: if "the cat sat" appeared, can't generate "the" again
// ========================================================================

func get_blocked_tokens(
    []int generated_ids,
    int no_repeat_ngram_size,
    int vocab_size  // For creating the blocked set
) []int {
    if no_repeat_ngram_size <= 0 || len(generated_ids) < no_repeat_ngram_size - 1 {
        return []  // No blocking
    }
    
    // Build set of disallowed next tokens based on recent n-grams
    map<int]bool blocked = {}
    int start = len(generated_ids) - (no_repeat_ngram_size - 1)
    
    // Extract the most recent (n-1)-gram prefix to look for in history
    []int recent_prefix = []
    for i in start .. len(generated_ids) {
        recent_prefix.push(generated_ids[i])
    }
    
    // Scan through all positions where this prefix appears
    for pos in 0..(len(generated_ids) - no_repeat_ngram_size + 1) {
        bool match = true
        
        for j in 0..(no_repeat_ngram_size - 1) {
            int hist_idx = pos + j
            if generated_ids[hist_idx] != recent_prefix[j] {
                match = false
                break
            }
        }
        
        // If we found a matching prefix, block the token that followed it
        if match  (pos + no_repeat_ngram_size - 1) < len(generated_ids) {
            int blocked_token = generated_ids[pos + no_repeat_ngram_size - 1]
            blocked[blocked_token] = true
        }
    }
    
    // Convert map keys to array
    []int blocked_tokens = []
    for id in blocked {
        if blocked[id] {
            blocked_tokens.push(id)
        }
    }
    
    blocked_tokens
}

func apply_ngram_blocking(
    []float logits,
    []int generated_ids,
    int ngram_size
) []float {
    []int blocked = get_blocked_tokens(generated_ids, ngram_size, len(logits))
    
    if len(blocked) == 0 {
        return logits
    }
    
    // Set logits of blocked tokens to -infinity
    []float filtered = copy_float_array(logits)
    float neg_inf = -1e10
    
    for t in blocked {
        if t >= 0  t < len(filtered) {
            filtered[t] = neg_inf
        }
    }
    
    filtered
}
