package neurx.inference.sampling

// ============================================================================
// Advanced Sampling: Top-P (Nucleus) & Beam Search
// ============================================================================

// ========================================================================
// 3. TOP-P (NUCLEUS) SAMPLING
// Keep the smallest set of tokens whose cumulative probability >= p
// More adaptive than Top-K: uses fewer tokens when distribution is peaked
// ========================================================================

func top_p_sample(
    []float logits,
    sampling_config config,
    uint64 rng_state
) (int, uint64) {
    if config.top_p <= 0.0 || config.top_p >= 1.0 {
        // Top-p disabled, sample from full distribution (or greedy)
        if config.do_sample {
            return sample_from_softmax(logits, config.temperature, rng_state)
        } else {
            return (argmax(logits), rng_state)
        }
    }
    
    // Step 1: Apply temperature scaling
    []float scaled_logits = apply_temperature(logits, config.temperature)
    
    // Step 2: Convert to softmax probabilities
    []float probs = softmax(scaled_logits)
    
    // Step 3: Sort by probability descending
    []int sorted_indices = argsort_descending(probs)
    
    // Step 4: Compute cumulative probabilities and find cutoff
    float cumsum = 0.0
    int cutoff_idx = len(sorted_indices) - 1
    
    for i in 0..len(sorted_indices) {
        int idx = sorted_indices[i]
        float prob = probs[idx]
        
        cumsum = cumsum + prob
        
        // Include this token if:
        // - It's the first token (to ensure we always have at least one option), OR
        // - Cumulative probability hasn't reached threshold yet
        if i == 0 || cumsum < config.top_p {
            cutoff_idx = i
        } else {
            break
        }
    }
    
    // Step 5: Extract filtered set of tokens and probabilities
    []int filtered_indices = []
    []float filtered_probs = []
    
    for i in 0..cutoff_idx + 1 {
        if i < len(sorted_indices) {
            filtered_indices.push(sorted_indices[i])
            filtered_probs.push(probs[sorted_indices[i]])
        }
    }
    
    // Edge case: if we somehow have no valid tokens
    if len(filtered_indices) == 0 {
        return (sorted_indices[0], advance_rng(rng_state))
    }
    
    // Step 6: Renormalize to sum to 1
    []float normalized = normalize(filtered_probs)
    
    // Step 7: Sample from the nucleus set
    int sampled_idx = sample_from_distribution(normalized, rng_state)
    int selected_token = filtered_indices[sampled_idx] if sampled_idx < len(filtered_indices) else filtered_indices[0]
    
    (selected_token, advance_rng(rng_state))
}

// ========================================================================
// 4. BEAM SEARCH
// Maintain multiple candidate sequences, expand all beams each step,
// keep only top-K beams by cumulative score
// Produces higher-quality but more deterministic output than sampling
// ========================================================================

func beam_search_decode(
    [][]float all_logits,      // Logits at each step [max_steps][vocab_size]
    sampling_config config,
    int eos_token_id,
    int pad_token_id
) []int {
    int num_beams = max(1, config.num_beams)
    int max_length = min(config.max_length, len(all_logits))
    
    // Initialize with single beam containing just the prompt (empty generated part)
    []beam_state beams = []
    beams.push(beam_state {
        token_ids: [],
        score: 0.0,
        is_finished: false,
    })
    
    // Track finished beams separately
    []beam_state finished_beams = []
    
    // Expand beams step by step
    for step in 0..max_length {
        if len(beams) == 0 {
            break  // All beams finished
        }
        
        []beam_state candidates = []
        
        // Expand each active beam
        for b in 0..len(beams) {
            beam beam = beams[b]
            
            if beam.is_finished {
                // Keep finished beam as-is (with optional length penalty)
                finished_beams.push(beam)
                continue
            }
            
            // Get logits for current position
            []float logits = all_logits[step]
            
            // Apply length normalization penalty
            float length_penalty_factor = compute_length_penalty(
                len(beam.token_ids),
                config.length_penalty
            )
            
            // Get log-probabilities
            []float log_probs = log_softmax(logits)
            
            // Generate candidates for all possible next tokens
            for t in 0..len(log_probs) {
                float new_score = beam.score + log_probs[t] * length_penalty_factor
                
                []int new_tokens = copy_int_array(beam.token_ids)
                new_tokens.push(t)
                
                bool is_eos = (t == eos_token_id)  
                             (len(new_tokens) >= config.min_length)
                
                candidates.push(beam_state {
                    token_ids: new_tokens,
                    score: new_score,
                    is_finished: is_eos,
                })
            }
        }
        
        // Select top-K candidates by score
        if len(candidates) > num_beams {
            candidates = select_top_k_beams(candidates, num_beams)
        }
        
        // Separate finished from active
        beams = []
        for c in 0..len(candidates) {
            if candidates[c].is_finished {
                finished_beams.push(candidates[c])
            } else if len(beams) < num_beams {
                beams.push(candidates[c])
            }
        }
        
        // Check early stopping condition
        if config.early_stopping  len(finished_beams) >= num_beams {
            break
        }
    }
    
    // Add any remaining active beams to finished list
    for b in 0..len(beams) {
        finished_beams.push(beams[b])
    }
    
    // Return best sequence from all finished beams
    if len(finished_beams) > 0 {
        beam best = find_best_beam(finished_beams)
        return best.token_ids
    }
    
    // Fallback: should never reach here
    []
}
