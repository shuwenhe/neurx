package neurx.infer.sampling

// ============================================================================
// Complete Sampling Strategies for Text Generation
// Supports: Greedy, Top-K, Top-P (Nucleus), Beam Search, Temperature,
//           Repetition Penalty, Length Penalty, etc.
// ============================================================================

// ---- Sampling Configuration ----
struct sampling_config {
    // Decoding strategy
    string strategy              // "greedy", "top_k", "top_p", "beam_search", "contrastive"
    
    // Temperature & randomness
    float temperature            // Softmax temperature (1.0 = default, <1 = sharper, >1 = flatter)
    int top_k                    // Number of tokens to consider (0 = disabled)
    float top_p                  // Cumulative probability threshold (0.0 = disabled)
    
    // Beam search specific
    int num_beams                // Number of beams for beam search
    float length_penalty         // Favor longer/shorter sequences (>1 favors longer)
    bool early_stopping          // Stop when all beams finish
    
    // Quality controls
    float repetition_penalty     // Penalize repeated tokens (>1 penalizes more)
    int no_repeat_ngram_size     // Prevent n-gram repetitions (0 = disabled)
    float min_length_penalty     // Penalize sequences shorter than min_length
    int min_length               // Minimum generation length
    int max_length               // Maximum generation length (hard limit)
    
    // Advanced
    float epsilon_cutoff         // Don't consider tokens below this probability
    float eta_cutoff             // Add noise for tokens above this probability
    bool do_sample               // If false, use greedy regardless of other settings
    uint64 seed                  // Random seed for reproducibility
}

// ---- Generation State ----
struct generation_state {
    []int input_ids              // Input token IDs (prompt + generated so far)
    [][]float scores             // Logits at each step [step][vocab_size]
    [][]float probabilities      // Probabilities at each step [step][vocab_size]
    []int generated_ids          // Only the newly generated tokens
    int current_step             // Current generation step
    bool is_finished             // Has EOS been generated?
    
    // For beam search
    []beam_state beams           // Active beams
}

// ---- Beam State ----
struct beam_state {
    []int token_ids              // Full sequence for this beam
    float score                  // Cumulative log-probability
    bool is_finished             // Has this beam finished?
}

// ========================================================================
// DEFAULT CONFIGURATION
// Sensible defaults for common use cases
// ========================================================================

func default_sampling_config() sampling_config {
    sampling_config {
        strategy: "top_p",
        temperature: 1.0,
        top_k: 50,
        top_p: 0.9,
        num_beams: 5,
        length_penalty: 1.0,
        early_stopping: true,
        repetition_penalty: 1.0,
        no_repeat_ngram_size: 0,
        min_length_penalty: 0.0,
        min_length: 0,
        max_length: 512,
        epsilon_cutoff: 0.0,
        eta_cutoff: 0.0,
        do_sample: true,
        seed: 42,
    }
}

func greedy_config() sampling_config {
    sampling_config {
        strategy: "greedy",
        temperature: 1.0,
        top_k: 0,
        top_p: 0.0,
        num_beams: 1,
        do_sample: false,
        max_length: 512,
    }
}

func creative_config() sampling_config {
    sampling_config {
        strategy: "top_p",
        temperature: 0.9,
        top_k: 40,
        top_p: 0.92,
        repetition_penalty: 1.15,
        max_length: 1024,
        do_sample: true,
    }
}
