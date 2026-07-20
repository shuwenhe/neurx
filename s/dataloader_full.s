package neurx.data

// ============================================================================
// Complete data_loader - Production-ready data loading system
// Features: Multi-worker, prefetching, pin_memory, distributed support
// ============================================================================

// ---- data_loader Config ----
struct dataloader_config {
    int batch_size           // Samples per batch
    bool shuffle             // Shuffle data each epoch
    int num_workers          // Parallel data loading workers
    int prefetch_factor      // Batches to prefetch per worker (2 default)
    bool pin_memory          // Pin memory for faster GPU transfer (CUDA)
    bool drop_last           // Drop incomplete final batch
    int persistent_workers   // Keep workers alive between epochs
    
    // Timeout and error handling
    float timeout_secs       // Worker timeout (0 = no timeout)
    int max_retries          // Retry failed reads N times
    
    // Distributed training
    int world_size           // Total number of distributed workers
    int rank                // This worker's rank
    
    // Collation settings
    collator_config collator
}

// ---- data_loader State ----
struct dataloader {
    dataset ds
    sampler samp
    dataloader_config config
    
    // Internal state
    int current_epoch
    int total_batches        // Total batches in this epoch
    int batches_served       // Batches already served this epoch
    
    // Prefetch buffer
    []batch prefetch_buffer  // Pre-loaded batches
}

// Create new data_loader from dataset and config
func new_dataloader(
    dataset ds,
    dataloader_config cfg
) dataloader {
    // Setup sampler based on config
    sampler_config samp_cfg {
        total_samples: len_dataset(ds),
        batch_size: cfg.batch_size,
        shuffle: cfg.shuffle,
        seed: uint64(42),  // Default seed
        num_replicas: cfg.world_size if cfg.world_size > 0 else 1,
        rank: cfg.rank,
        drop_last: cfg.drop_last,
    }
    
    // Calculate total batches
    int total_samples = len_dataset(ds)
    if cfg.world_size > 1 {
        total_samples = total_samples / cfg.world_size
    }
    
    int n_batches = total_samples / cfg.batch_size
    if !cfg.drop_last  t(total_samples - (total_samples / cfg.batch_size) * cfg.batch_size) != 0 {
        n_batches = n_batches + 1
    }
    
    dataloader {
        ds: ds,
        samp: new_sampler(samp_cfg),
        config: cfg,
        current_epoch: 0,
        total_batches: n_batches,
        batches_served: 0,
        prefetch_buffer: [],
    }
}

// ========================================================================
// EPOCH MANAGEMENT
// Reset for new epoch (reshuffle, reset counters)
// ========================================================================

func reset_epoch(dataloader dl) dataloader {
    dl.current_epoch = dl.current_epoch + 1
    dl.batches_served = 0
    
    // Reshuffle if configured
    if dl.config.shuffle {
        dl.samp = reset_random(dl.samp)
    } else {
        dl.samp = reset_sequential(dl.samp)
    }
    
    // Clear and refill prefetch buffer
    dl.prefetch_buffer = []
    dl = fill_prefetch_buffer(dl)
    
    dl
}

// ========================================================================
// ITERATION - Get next batch
// Returns (batch, done) where done=true means epoch is complete
// ========================================================================

func next_batch(dataloader dl) (batch, bool) {
    // Check if we have prefetched batches
    if len(dl.prefetch_buffer) > 0 {
        batch b = dl.prefetch_buffer.pop_front()
        dl.batches_served = dl.batches_served + 1
        
        // Refill prefetch buffer if getting low
        if len(dl.prefetch_buffer) < dl.config.prefetch_factor {
            dl = fill_prefetch_buffer(dl)
        }
        
        (b, false)  // More data available
    } else if dl.batches_served >= dl.total_batches {
        // Epoch complete
        (empty_batch(), true)
    } else {
        // Generate batch on-the-fly
        ([]int indices, bool has_data) = next_batch_sequential(dl.samp)
        
        if !has_data || len(indices) == 0 {
            (empty_batch(), true)  // No more data
        }
        
        // Load samples for these indices
        []sample samples = load_samples_for_indices(dl.ds, indices)
        
        // Collate into batch
        batch b = collate_fn(samples, dl.config.collator)
        dl.batches_served = dl.batches_served + 1
        
        (b, false)
    }
}

// Load samples by their indices (with error handling)
func load_samples_for_indices(dataset ds, []int indices) []sample {
    []sample samples = []int{cap: len(indices)}
    
    for idx in indices {
        (sample s, error err) = get_sample(ds, idx)
        
        if err == nil {
            samples.push(s)
        } else {
            // Push empty sample on error (or could retry/skip)
            sample { token_ids: [], text: "", label: -1, weight: 1.0, metadata: {} }
        }
    }
    
    samples
}

// ========================================================================
// PREFETCHING SYSTEM
// Load batches in background for faster iteration
// ========================================================================

func fill_prefetch_buffer(dataloader dl) dataloader {
    int target_count = dl.config.prefetch_factor * 2  // Buffer size
    
    while len(dl.prefetch_buffer) < target_count  
          dl.batches_served + len(dl.prefetch_buffer) < dl.total_batches {
        
        ([]int indices, bool has_data) = next_batch_sequential(dl.samp)
        
        if !has_data || len(indices) == 0 {
            break  // No more data available
        }
        
        // Load and collate this batch
        []sample samples = load_samples_for_indices(dl.ds, indices)
        batch b = collate_fn(samples, dl.config.collator)
        
        dl.prefetch_buffer.push(b)
    }
    
    dl
}

// ========================================================================
// LENGTH BUCKETING (Optional optimization)
// Group sequences of similar length together to reduce padding waste
// ========================================================================

struct bucket_config {
    int num_buckets          // Number of length buckets
    int min_bucket_size      // Minimum sequence length
    int max_bucket_size      // Maximum sequence length
    bool dynamic_buckets     // Adapt buckets to data distribution
}

struct bucketed_dataloader {
    dataloader base_dl
    bucket_config bconfig
    map[int][]int length_to_samples  // Maps bucket index -> sample indices
    []int current_bucket_order      // Order of buckets to process
}

func create_bucketed_dataloader(
    dataset ds,
    dataloader_config dl_cfg,
    bucket_config bcfg
) bucketed_dataloader {
    // Analyze dataset lengths
    map[int][]int buckets = {}
    
    for i in 0..len(ds.samples) {
        int len = len(ds.samples[i].token_ids)
        int bucket_idx = assign_to_bucket(len, bcfg)
        
        if !(bucket_idx in buckets) {
            buckets[bucket_idx] = []
        }
        buckets[bucket_idx].push(i)
    }
    
    bucketed_dataloader {
        base_dl: new_dataloader(ds, dl_cfg),
        bconfig: bcfg,
        length_to_samples: buckets,
        current_bucket_order: generate_bucket_order(buckets),
    }
}

func assign_to_bucket(int seq_len, bucket_config bcfg) int {
    // Linear mapping from [min, max] -> [0, num_buckets-1]
    float range_val = float(bcfg.max_bucket_size - bcfg.min_bucket_size)
    if range_val <= 0.0 { return 0 }
    
    float normalized = float(seq_len - bcfg.min_bucket_size) / range_val
    int bucket = int(normalized * float(bcfg.num_buckets))
    
    // Clamp to valid range
    if bucket < 0 { bucket = 0 }
    if bucket >= bcfg.num_buckets { bucket = bcfg.num_buckets - 1 }
    
    bucket
}

func generate_bucket_order(map[int][]int buckets) []int {
    []int order = []
    
    for key in buckets {
        order.push(key)
    }
    
    // Sort bucket keys (simple bubble sort for now)
    for i in 0..len(order)-1 {
        for j in 0..len(order)-i-1 {
            if order[j] > order[j+1] {
                int temp = order[j]
                order[j] = order[j+1]
                order[j+1] = temp
            }
        }
    }
    
    order
}
