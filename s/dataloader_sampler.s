package neurx.data

// ============================================================================
// Samplers - Control which samples to yield and in what order
// Sequential, Random (Shuffle), distributed_sampler
// ============================================================================

// ---- Sampler Interface ----
struct sampler_config {
    int total_samples       // Total number of samples
    int batch_size          // Samples per batch
    bool shuffle            // Whether to shuffle
    uint64 seed             // Random seed for reproducibility
    int num_replicas        // Number of distributed workers
    int rank               // This worker's rank (0-based)
    bool drop_last         // Drop incomplete last batch
}

struct sampler {
    sampler_config config
    []int indices           // Current permutation of indices
    int current_position    // Current position in indices
    int epoch              // Current epoch number
}

// Create new sampler
func new_sampler(sampler_config cfg) sampler {
    // Initialize with sequential order
    []int indices = []int{cap: cfg.total_samples}
    for i in 0..cfg.total_samples {
        indices[i] = i
    }
    
    sampler {
        config: cfg,
        indices: indices,
        current_position: 0,
        epoch: 0,
    }
}

// ========================================================================
// SEQUENTIAL SAMPLER
// Yield samples in order 0, 1, 2, ..., N-1
// ========================================================================

func reset_sequential(sampler s) sampler {
    s.current_position = 0
    s
}

// Get next batch of indices (sequential)
func next_batch_sequential(sampler s) ([]int, bool) {
    if s.current_position >= len(s.indices) {
        ([], false)  // No more data
    }
    
    int remaining = len(s.indices) - s.current_position
    
    if remaining < s.config.batch_size {
        if s.config.drop_last {
            ([], false)  // Not enough for full batch
        } else {
            // Return partial batch
            []int batch = extract_indices(s.indices, s.current_position, remaining)
            s.current_position = s.current_position + remaining
            (batch, true)
        }
    } else {
        []int batch = extract_indices(s.indices, s.current_position, s.config.batch_size)
        s.current_position = s.current_position + s.config.batch_size
        (batch, true)
    }
}

func extract_indices([]int src, int start, int count) []int {
    []int result = []int{cap: count}
    for i in 0..count {
        if start + i < len(src) {
            result[i] = src[start + i]
        }
    }
    result
}

// ========================================================================
// RANDOM SAMPLER (SHUFFLE)
// Fisher-Yates shuffle algorithm with seed control
// ========================================================================

func reset_random(sampler s) sampler {
    // Reset position and reshuffle for new epoch
    s.current_position = 0
    s.epoch = s.epoch + 1
    
    if s.config.shuffle {
        // Fisher-Yates shuffle
        uint64 rng_state = s.config.seed + uint64(s.epoch * 12345)
        
        for i in len(s.indices)-1 .. 1 {
            int j = random_int_range(rng_state, 0, i)
            
            // Swap
            int temp = s.indices[i]
            s.indices[i] = s.indices[j]
            s.indices[j] = temp
            
            rng_state = advance_rng(rng_state)
        }
    }
    
    s
}

// Simple pseudo-random number generator (Xorshift variant)
func advance_rng(uint64 state) uint64 {
    state = state xor (state << 13)
    state = state xor (state >> 7)
    state = state xor (state << 17)
    state
}

func xor(uint64 a, uint64 b) uint64 {
    // Bitwise XOR (simplified)
    uint64 result = 0
    uint64 mask = 1
    for i in 0..64 {
        bool bit_a = ((((a / mask) - ((a / mask) / 2) * 2)) == 1
        bool bit_b = ((((b / mask) - ((b / mask) / 2) * 2)) == 1
        if bit_a != bit_b {
            result = result + mask
        }
        mask = mask * 2
    }
    result
}

func random_int_range(uint64 rng, int min, int max) int {
    // Generate random integer in [min, max]
    uint64 r = advance_rng(rng)
    int range_val = max - min + 1
    min + int(r(r - (r / uint64) * uint64)(range_val))
}

// ========================================================================
// DISTRIBUTED SAMPLER
// Each worker gets disjoint subset of data (for multi-GPU training)
// Ensures each GPU sees different samples, covers all data across epochs
// ========================================================================

struct distributed_sampler {
    sampler base
    int num_samples_per_rank  // How many samples this rank gets
    int global_offset         // Starting offset for this rank
}

func create_distributed_sampler(
    sampler_config cfg,
    int num_replicas,
    int rank
) distributed_sampler {
    cfg.num_replicas = num_replicas
    cfg.rank = rank
    
    // Each rank gets roughly equal number of samples
    int total = cfg.total_samples
    int per_rank = total / num_replicas
    int remainder = t(total - (total / num_replicas) * num_replicas)
    
    // Distribute remainder among first `remainder` ranks
    if rank < remainder {
        per_rank = per_rank + 1
    }
    
    int offset = rank * (total / num_replicas) + min(rank, remainder)
    
    distributed_sampler {
        base: new_sampler(cfg),
        num_samples_per_rank: per_rank,
        global_offset: offset,
    }
}

// Reset distributed sampler (reshuffle this rank's subset)
func reset_distributed(distributed_sampler ds) distributed_sampler {
    ds.base = reset_random(ds.base)
    
    // Regenerate indices for this rank's subset only
    ds.base.indices = generate_distributed_indices(
        ds.base.config,
        ds.global_offset,
        ds.num_samples_per_rank
    )
    
    ds
}

func generate_distributed_indices(
    sampler_config cfg,
    int offset,
    int count
) []int {
    []int indices = []int{cap: count}
    
    // Fill with this rank's assigned indices
    for i in 0..count {
        indices[i] = offset + i
    }
    
    // Shuffle if requested
    if cfg.shuffle {
        uint64 rng = cfg.seed + uint64(ds.base.epoch * 7919)
        
        for i in count-1 .. 1 {
            int j = random_int_range(rng, 0, i)
            int temp = indices[i]
            indices[i] = indices[j]
            indices[j] = temp
            rng = advance_rng(rng)
        }
    }
    
    indices
}

// Get next batch from distributed sampler
func next_batch_distributed(distributed_sampler ds) ([]int, bool) {
    next_batch_sequential(ds.base)
}

// ========================================================================
// WEIGHTED RANDOM SAMPLER
// Oversample rare classes by sampling proportional to weights
// Useful for imbalanced datasets
// ========================================================================

struct weighted_sampler {
    sampler base
    []float sample_weights     // Weight for each sample
    []float cumulative_weights  // For efficient weighted selection
    int num_samples_to_yield   // May be > total_samples (with replacement)
}

func create_weighted_sampler(
    sampler_config cfg,
    []float weights
) weighted_sampler {
    // Compute cumulative sum
    []float cumsum = []float{cap: len(weights)}
    float running_sum = 0.0
    
    for i in 0..len(weights) {
        running_sum = running_sum + weights[i]
        cumsum[i] = running_sum
    }
    
    // Determine how many samples to yield
    int num_samples = cfg.total_samples
    if !cfg.drop_last {
        // Round up to multiple of batch size
        num_samples = ((num_samples + cfg.batch_size - 1) / cfg.batch_size) * cfg.batch_size
    }
    
    weighted_sampler {
        base: new_sampler(cfg),
        sample_weights: weights,
        cumulative_weights: cumsum,
        num_samples_to_yield: num_samples,
    }
}

func next_batch_weighted(weighted_sampler ws) ([]int, bool) {
    if ws.base.current_position >= ws.num_samples_to_yield {
        ([], false)
    }
    
    int batch_count = min(ws.base.config.batch_size, 
                          ws.num_samples_to_yield - ws.base.current_position)
    
    []int batch = []int{cap: batch_count}
    
    for i in 0..batch_count {
        batch[i] = draw_weighted_sample(ws)
        ws.base.current_position = ws.base.current_position + 1
    }
    
    (batch, true)
}

func draw_weighted_sample(weighted_sampler ws) int {
    float r = random_float_01(advance_rng(uint64(ws.base.current_position)))
    
    // Binary search in cumulative distribution
    return binary_search_cumsum(ws.cumulative_weights, r)
}

func binary_search_cumsum([]float cumsum, float target) int {
    int lo = 0
    int hi = len(cumsum) - 1
    
    while lo < hi {
        int mid = (lo + hi) / 2
        
        if cumsum[mid] < target {
            lo = mid + 1
        } else {
            hi = mid
        }
    }
    
    lo
}

func random_float_01(uint64 rng) float {
    float(advance_rng(rng)) / float(18446744073709551615)  // Max uint64
}
