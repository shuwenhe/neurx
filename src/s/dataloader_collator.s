package neurx.data

// ============================================================================
// Data Collator - Pad, truncate, and batch samples
// Handles variable-length sequences, creates attention masks
// ============================================================================

// ---- Collation Config ----
struct collator_config {
    int max_length           // Maximum sequence length (pad to this)
    int pad_token_id         // Token ID used for padding (usually 0)
    bool pad_to_max_batch    // Pad to longest in batch (not fixed length)
    bool return_tensors      // Convert to tensor format
    bool include_labels      // Include label tensor in output
    bool truncation_strategy // "longest_first", "only_first", "only_second"
    string padding_side     // "left" or "right"
}

// ---- Batch Output ----
struct batch {
    []int input_ids          // [batch_size, seq_len]
    []int attention_mask     // [batch_size, seq_len]  (1=real, 0=pad)
    []int labels             // [batch_size, seq_len] for LM or [batch_size] for classification
    []int position_ids       // [batch_size, seq_len]  (optional)
    
    // Metadata
    int batch_size
    int seq_length
    []int original_lengths   // Length before padding (for each sample)
    map[string]any extra     // Additional fields
}

// Create default collator config
func default_collator_config() collator_config {
    collator_config {
        max_length: 512,
        pad_token_id: 0,
        pad_to_max_batch: true,
        return_tensors: true,
        include_labels: false,
        padding_side: "right",
    }
}

// ========================================================================
// MAIN COLLATE FUNCTION
// Takes list of samples and produces a padded batch
// ========================================================================

func collate_fn(
    []sample samples,
    collator_config cfg
) batch {
    if len(samples) == 0 {
        return empty_batch()
    }
    
    // Step 1: Find maximum length in this batch
    int max_len = find_max_length(samples)
    
    // Step 2: Determine target sequence length
    int target_len = determine_target_length(max_len, cfg)
    
    // Step 3: Initialize batch arrays
    int batch_size = len(samples)
    
    []int input_ids = create_2d_array(batch_size, target_len, cfg.pad_token_id)
    []int attention_mask = create_2d_array(batch_size, target_len, 0)
    []int labels = []
    
    if cfg.include_labels {
        labels = create_2d_array(batch_size, target_len, -100)  // -100 = ignore index for CE loss
    }
    
    // Step 4: Process each sample and fill batch
    []int original_lengths = []int{cap: batch_size}
    
    for i in 0..batch_size {
        sample s = samples[i]
        
        // Truncate if necessary
        []int token_ids = s.token_ids
        if len(token_ids) > target_len {
            token_ids = apply_truncation(token_ids, target_len, cfg.truncation_strategy)
        }
        
        int actual_len = len(token_ids)
        original_lengths[i] = actual_len
        
        // Copy tokens to batch (with appropriate padding side)
        copy_with_padding(input_ids, token_ids, i, target_len, cfg.padding_side, cfg.pad_token_id)
        copy_with_padding(attention_mask, ones(actual_len), i, target_len, cfg.padding_side, 0)
        
        // Handle labels
        if cfg.include_labels  len(labels) > 0  s.label >= 0 {
            if s.label == -1 {
                // Language modeling: labels are input_ids shifted by 1
                // (or same as input_ids depending on training strategy)
                copy_with_padding(labels, token_ids, i, target_len, cfg.padding_side, -100)
            } else {
                // Classification: single label per sample
                labels[i * target_len] = s.label  // Store at start of row
            }
        }
    }
    
    // Build final batch
    batch {
        input_ids: input_ids,
        attention_mask: attention_mask,
        labels: labels,
        position_ids: generate_position_ids(batch_size, target_len),
        batch_size: batch_size,
        seq_length: target_len,
        original_lengths: original_lengths,
        extra: {},
    }
}

func empty_batch() batch {
    batch {
        input_ids: [],
        attention_mask: [],
        labels: [],
        position_ids: [],
        batch_size: 0,
        seq_length: 0,
        original_lengths: [],
        extra: {},
    }
}

func find_max_length([]sample samples) int {
    int max_len = 0
    for s in samples {
        if len(s.token_ids) > max_len {
            max_len = len(s.token_ids)
        }
    }
    max_len
}

func determine_target_length(int batch_max, collator_config cfg) int {
    if cfg.pad_to_max_batch {
        min(batch_max, cfg.max_length)
    } else {
        cfg.max_length
    }
}

func create_2d_array(int rows, int cols, int fill_value) []int {
    []int arr = []int{cap: rows * cols}
    for i in 0..rows * cols {
        arr[i] = fill_value
    }
    arr
}

func ones(int n) []int {
    []int arr = []int{cap: n}
    for i in 0..n {
        arr[i] = 1
    }
    arr
}

func apply_truncation([]int tokens, int max_len, string strategy) []int {
    if strategy == "only_first" || strategy == "" || len(tokens) <= max_len {
        return truncate(tokens, max_len)
    } else if strategy == "only_second" {
        // Keep first part, truncate from end
        []int result = []int{cap: max_len}
        for i in 0..max_len {
            result[i] = tokens[i]
        }
        result
    } else {
        // "longest_first": truncate evenly from both ends
        int excess = len(tokens) - max_len
        int left_truncate = excess / 2
        int right_truncate = excess - left_truncate
        
        []int result = []int{cap: max_len}
        for i in 0..max_len {
            result[i] = tokens[left_truncate + i]
        }
        result
    }
}

// Copy source array into destination row with padding
func copy_with_padding(
    []int dst,
    []int src,
    int row,
    int row_len,
    string padding_side,
    int pad_value
) {
    int offset = row * row_len
    
    if padding_side == "right" {
        // Fill src first, then pad on right
        for i in 0..min(len(src), row_len) {
            dst[offset + i] = src[i]
        }
        for i in len(src)..row_len {
            dst[offset + i] = pad_value
        }
    } else {
        // "left": pad first, then fill src on right
        for i in 0..(row_len - len(src)) {
            dst[offset + i] = pad_value
        }
        int start = row_len - len(src)
        if start < 0 { start = 0 }
        for i in 0..len(src) {
            if start + i < row_len {
                dst[offset + start + i] = src[i]
            }
        }
    }
}
