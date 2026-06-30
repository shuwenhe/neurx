package neurx.inference

// ============================================================================
// TEXT GENERATOR - High-Level API
// Orchestrates model inference + sampling strategies
// ============================================================================

use neurx.inference.sampling.sampling_strategies_impl
use neurx.inference.sampling.sampling_core
use neurx.inference.sampling.sampling_advanced
use neurx.inference.sampling.sampling_utils
use neurx.inference.sampling.sampling_utils2
use neurx.inference.sampling.sampling_utils3
use neurx.inference.sampling.sampling_utils4
use neurx.inference.sampling.sampling_penalties
use neurx.inference.sampling.sampling_ngram
use neurx.inference.sampling.sampling_beam

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
    []int sequences            // Generated token sequence (stub form)
    []float scores             // Scores per step (stub form)
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
    generator_config cfg
) generation_result {
    // Initialize state
    int total_generated = 0
    int max_steps = min(cfg.max_new_tokens, cfg.sampling.max_length)
    uint64 rng = cfg.sampling.seed
    
    // Storage for all sequences and scores
    []int all_sequences = []int{cap: 0}
    []float all_scores = []float{cap: 0}
    
    // Generate multiple sequences if requested
    int seq_idx = 0
    while seq_idx < cfg.num_return_sequences {
        rng = advance_rng(rng)
        
        // Initialize with prompt
        []int current_ids = copy_int_array(prompt_ids)
        []float step_logits = []float{cap: 0}
        bool done = false
        
        // Generation loop
        int step = 0
        while step < max_steps {
            if done { break }
            
            // Run model forward pass to get next-token logits
            []float logits = []float{cap: 0}
            
            // Store logits (for scoring/debugging)
            step_logits.push(0.0)
            
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
            
            if cfg.sampling.strategy == "greedy" {
                next_token = 0
            } else if cfg.sampling.strategy == "top_k" {
                next_token = 0
            } else if cfg.sampling.strategy == "top_p" {
                next_token = 0
            } else if cfg.sampling.strategy == "beam_search" {
                // Beam search needs all logits at once - handled separately
                break
            } else {
                // Fallback to greedy
                next_token = 0
            }
            
            // Append token
            current_ids.push(next_token)
            total_generated = total_generated + 1
            
            // Check stopping conditions
            if next_token == cfg.eos_token_id && total_generated >= cfg.min_new_tokens {
                done = true
            }
            
            if total_generated >= cfg.max_new_tokens {
                if cfg.force_eos && current_ids[len(current_ids)-1] != cfg.eos_token_id {
                    current_ids.push(cfg.eos_token_id)
                }
                done = true
            }

            step = step + 1
        }
        
        if len(current_ids) > 0 {
            all_sequences.push(current_ids[0])
        }
        if cfg.return_scores {
            all_scores.push(0.0)
        }

        seq_idx = seq_idx + 1
    }
    
    // Build result
    []float result_scores = all_scores
    if !cfg.return_scores {
        result_scores = []float{cap: 0}
    }

    generation_result {
        sequences: all_sequences,
        scores: result_scores,
        texts: [],  // Will be filled by tokenizer if available
        finished: check_all_finished(all_sequences, cfg.eos_token_id),
        avg_score: 0.0,
    }
}
