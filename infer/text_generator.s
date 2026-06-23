package neurx.infer

// ============================================================================
// TEXT GENERATOR - High-Level API
// Orchestrates model inference + sampling strategies
// ============================================================================

use neurx.infer.sampling.sampling_strategies_impl
use neurx.infer.sampling.sampling_core
use neurx.infer.sampling.sampling_advanced
use neurx.infer.sampling.sampling_utils
use neurx.infer.sampling.sampling_utils2
use neurx.infer.sampling.sampling_utils3
use neurx.infer.sampling.sampling_utils4
use neurx.infer.sampling.sampling_penalties
use neurx.infer.sampling.sampling_ngram
use neurx.infer.sampling.sampling_beam

// ---- Generator Configuration ----
struct generator_config {
    sampling_config sampling
    
    // Model settings
    int eos_token_id           // End-of-sequence token ID
    int pad_token_id           // Padding token ID (for attention mask)
    
    // Generation constraints
    bool force_eos             // Force EOS at max_length if not generated
    int min_new_tokens         // Minimum new tokens to generate (beyond prompt)
    int max_new_tokens         // Maximum new tokens to generate
    
    // Output control
    bool return_scores         // Return log-probabilities of each step
    bool return_full_text      // Return full sequence including prompt
    
    // Streaming/batch
    int num_return_sequences   // How many different sequences to return
}

// Create default generator configuration
func default_generator_config() generator_config {
    generator_config {
        sampling: default_sampling_config(),
        eos_token_id: 2,       // Common EOS token for GPT-like models
        pad_token_id: 0,
        force_eos: true,
        min_new_tokens: 1,
        max_new_tokens: 256,
        return_scores: false,
        return_full_text: true,
        num_return_sequences: 1,
    }
}

// ---- Generator Result ----
struct generation_result {
    []int[] sequences          // Generated token sequences [num_seq][seq_len]
    [][]float scores           // Scores per step [num_seq][step][vocab] (optional)
    []string texts             // Decoded text strings (if tokenizer available)
    bool finished              // Did all sequences end with EOS?
    float avg_score            // Average score across sequences
}

// ========================================================================
// MAIN GENERATE FUNCTION
// Takes prompt + config, returns generated text(s)
// ========================================================================

func generate(
    []int prompt_ids,          // Input/prompt token IDs
    model_forward_fn forward,  // Function that runs one forward step
    generator_config cfg
) generation_result {
    // Initialize state
    int total_generated = 0
    int max_steps = min(cfg.max_new_tokens, cfg.sampling.max_length)
    uint64 rng = cfg.sampling.seed
    
    // Storage for all sequences and scores
    []int[] all_sequences = []
    [][]float all_scores = []
    
    // Generate multiple sequences if requested
    for seq_idx in 0..cfg.num_return_sequences {
        rng = advance_rng(rng)
        
        // Initialize with prompt
        []int current_ids = copy_int_array(prompt_ids)
        [][]float step_logits = []
        bool done = false
        
        // Generation loop
        for step in 0..max_steps {
            if done { break }
            
            // Run model forward pass to get next-token logits
            []float logits = forward(current_ids)
            
            // Store logits (for scoring/debugging)
            step_logits.push(logits)
            
            // Apply penalties based on already-generated tokens (excluding prompt)
            []int gen_part = extract_generated_part(current_ids, len(prompt_ids))
            
            if cfg.sampling.repetition_penalty != 1.0 {
                logits = apply_repetition_penalty(logits, gen_part, 
                                                   cfg.sampling.repetition_penalty)
            }
            
            if cfg.sampling.no_repeat_ngram_size > 0 {
                logits = apply_ngram_blocking(logits, gen_part,
                                               cfg.sampling.no_repeat_ngram_size)
            }
            
            // Select next token using configured strategy
            int next_token
            
            switch cfg.sampling.strategy {
                case "greedy":
                    (next_token, rng) = greedy_step(logits, cfg.sampling, rng)
                case "top_k":
                    (next_token, rng) = top_k_sample(logits, cfg.sampling, rng)
                case "top_p":
                    (next_token, rng) = top_p_sample(logits, cfg.sampling, rng)
                case "beam_search":
                    // Beam search needs all logits at once - handled separately
                    break
                default:
                    // Fallback to greedy
                    (next_token, rng) = greedy_step(logits, cfg.sampling, rng)
            }
            
            // Append token
            current_ids.push(next_token)
            total_generated = total_generated + 1
            
            // Check stopping conditions
            if next_token == cfg.eos_token_id  total_generated >= cfg.min_new_tokens {
                done = true
            }
            
            if total_generated >= cfg.max_new_tokens {
                if cfg.force_eos  current_ids[len(current_ids)-1] != cfg.eos_token_id {
                    current_ids.push(cfg.eos_token_id)
                }
                done = true
            }
        }
        
        all_sequences.push(current_ids)
        if cfg.return_scores {
            all_scores.push(step_logits)
        }
    }
    
    // Build result
    generation_result {
        sequences: all_sequences,
        scores: all_scores if cfg.return_scores else [],
        texts: [],  // Will be filled by tokenizer if available
        finished: check_all_finished(all_sequences, cfg.eos_token_id),
        avg_score: compute_avg_score(all_scores),
    }
}
