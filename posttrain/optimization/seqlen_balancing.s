package neurx.posttrain.optimization.seqlen_balancing
use neurx.tensor
struct seqlen_balance_config {
    int target_num_batches
    bool sort_descending
    float balance_tolerance
}

struct batch_assignment {
    [][]int sample_indices
    []int batch_sizes
    []int total_tokens_per_batch
    float balance_score
}

func default_seqlen_balance_config() seqlen_balance_config {
    seqlen_balance_config {
        target_num_batches: 8,
        sort_descending: true,
        balance_tolerance: 0.1,
    }
}

func largest_differencing_method(
    []int sequence_lengths,
    int num_batches
) batch_assignment {
    [][]int batches = make([][]int, num_batches)
    []int batch_totals = make([]int, num_batches)
    []int sorted_indices = argsort_descending(sequence_lengths)
    for int i = 0; i < len(sorted_indices); i = i + 1 {
        int sample_idx = sorted_indices[i]
        int seq_len = sequence_lengths[sample_idx]
        int min_batch_idx = find_min_batch(batch_totals)
        batches[min_batch_idx] = append(batches[min_batch_idx], sample_idx)
        batch_totals[min_batch_idx] = batch_totals[min_batch_idx] + seq_len
    }
    []int batch_sizes = make([]int, num_batches)
    for int i = 0; i < num_batches; i = i + 1 {
        batch_sizes[i] = len(batches[i])
    }
    float balance = compute_balance_score(batch_totals)
    batch_assignment {
        sample_indices: batches,
        batch_sizes: batch_sizes,
        total_tokens_per_batch: batch_totals,
        balance_score: balance,
    }
}

func argsort_descending([]int values) []int {
    []int indices = make([]int, len(values))
    for int i = 0; i < len(values); i = i + 1 {
        indices[i] = i
    }
    for int i = 0; i < len(values) - 1; i = i + 1 {
        for int j = i + 1; j < len(values); j = j + 1 {
            if values[indices[i]] < values[indices[j]] {
                int temp = indices[i]
                indices[i] = indices[j]
                indices[j] = temp
            }
        }
    }
    return indices
}

func find_min_batch([]int batch_totals) int {
    int min_idx = 0
    int min_val = batch_totals[0]
    for int i = 1; i < len(batch_totals); i = i + 1 {
        if batch_totals[i] < min_val {
            min_val = batch_totals[i]
            min_idx = i
        }
    }
    return min_idx
}

func compute_balance_score([]int batch_totals) float {
    if len(batch_totals) == 0 {
        return 0.0
    }
    int total = 0
    for int i = 0; i < len(batch_totals); i = i + 1 {
        total = total + batch_totals[i]
    }
    float mean = float(total) / float(len(batch_totals))
    float variance = 0.0
    for int i = 0; i < len(batch_totals); i = i + 1 {
        float diff = float(batch_totals[i]) - mean
        variance = variance + diff * diff
    }
    variance = variance / float(len(batch_totals))
    if mean < 1.0 {
        return 0.0
    }
    return sqrt_approx(variance) / mean
}

func greedy_bin_packing(
    []int sequence_lengths,
    int max_tokens_per_batch
) batch_assignment {
    [][]int batches = make([][]int, 0)
    []int batch_totals = make([]int, 0)
    []int sorted_indices = argsort_descending(sequence_lengths)
    for int i = 0; i < len(sorted_indices); i = i + 1 {
        int sample_idx = sorted_indices[i]
        int seq_len = sequence_lengths[sample_idx]
        bool placed = false
        for int b = 0; b < len(batches); b = b + 1 {
            if batch_totals[b] + seq_len <= max_tokens_per_batch {
                batches[b] = append(batches[b], sample_idx)
                batch_totals[b] = batch_totals[b] + seq_len
                placed = true
                break
            }
        }
        if !placed {
            []int new_batch = make([]int, 0)
            new_batch = append(new_batch, sample_idx)
            batches = append(batches, new_batch)
            batch_totals = append(batch_totals, seq_len)
        }
    }
    []int batch_sizes = make([]int, len(batches))
    for int i = 0; i < len(batches); i = i + 1 {
        batch_sizes[i] = len(batches[i])
    }
    float balance = compute_balance_score(batch_totals)
    batch_assignment {
        sample_indices: batches,
        batch_sizes: batch_sizes,
        total_tokens_per_batch: batch_totals,
        balance_score: balance,
    }
}

func balance_sequences(
    []int sequence_lengths,
    seqlen_balance_config config
) batch_assignment {
    return largest_differencing_method(sequence_lengths, config.target_num_batches)
}

func compute_padding_savings(
    batch_assignment assignment,
    []int sequence_lengths
) float {
    int total_tokens_with_padding = 0
    int total_actual_tokens = 0
    for int b = 0; b < len(assignment.sample_indices); b = b + 1 {
        []int batch_samples = assignment.sample_indices[b]
        int max_len_in_batch = 0
        for int i = 0; i < len(batch_samples); i = i + 1 {
            int sample_idx = batch_samples[i]
            int seq_len = sequence_lengths[sample_idx]
            total_actual_tokens = total_actual_tokens + seq_len
            if seq_len > max_len_in_batch {
                max_len_in_batch = seq_len
            }
        }
        total_tokens_with_padding = total_tokens_with_padding + max_len_in_batch * len(batch_samples)
    }
    if total_tokens_with_padding == 0 {
        return 0.0
    }
    int padding_tokens = total_tokens_with_padding - total_actual_tokens
    return float(padding_tokens) / float(total_tokens_with_padding)
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    for int i = 0; i < 10; i = i + 1 {
        guess = (guess + x / guess) / 2.0
    }
    return guess
}

