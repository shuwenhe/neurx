package neurx.transformers_utils.logits_processors.top_k

use neurx.transformers_utils.logits_processors.processor_utils

struct top_k_processor {
    int k
    float min_tokens_to_keep
    bool filter_value
}

func create_top_k_processor(k: int) top_k_processor {
    top_k_processor {
        k: k,
        min_tokens_to_keep: 1.0,
        filter_value: -1000000.0,
    }
}

func apply_top_k(
    logits: []float,
    processor: top_k_processor
) []float {
    int vocab_size = logits.len()
    int k_actual = processor.k

    if k_actual > vocab_size {
        k_actual = vocab_size
    }

    (top_indices, top_scores) := processor_utils.get_top_k_tokens(logits, k_actual)

    []bool mask
    for i = 0; i < vocab_size; i = i + 1 {
        mask.append(false)
    }

    for idx in top_indices {
        if idx >= 0 && idx < vocab_size {
            mask[idx] = true
        }
    }

    processor_utils.apply_token_mask(logits, mask)
}

func apply_top_k_batch(
    logits_batch: [][]float,
    processor: top_k_processor
) [][]float {
    [][]float filtered_batch

    for batch_logits in logits_batch {
        filtered := apply_top_k(batch_logits, processor)
        filtered_batch.append(filtered)
    }

    filtered_batch
}

func apply_adaptive_top_k(
    logits: []float,
    base_k: int,
    entropy_threshold: float
) []float {

    []float probs = processor_utils.softmax(logits)

    float entropy = 0.0
    for prob in probs {
        if prob > 0.0 {
            entropy = entropy - prob * log(prob)
        }
    }

    int adaptive_k = base_k
    if entropy > entropy_threshold {
        adaptive_k = base_k + 10
    }

    processor := create_top_k_processor(adaptive_k)
    apply_top_k(logits, processor)
}

func apply_top_k_with_threshold(
    logits: []float,
    k: int,
    min_prob: float
) []float {
    int vocab_size = logits.len()

    []float probs = processor_utils.softmax(logits)

    []bool mask
    []int sorted_indices

    for i = 0; i < vocab_size; i = i + 1 {
        sorted_indices.append(i)
    }

    for i = 0; i < k && i < sorted_indices.len(); i = i + 1 {
        for j = i + 1; j < sorted_indices.len(); j = j + 1 {
            idx_i := sorted_indices[i]
            idx_j := sorted_indices[j]

            if probs[idx_j] > probs[idx_i] {
                sorted_indices[i] = idx_j
                sorted_indices[j] = idx_i
            }
        }
    }

    for i = 0; i < vocab_size; i = i + 1 {
        bool in_top_k = false
        for j = 0; j < k && j < sorted_indices.len(); j = j + 1 {
            if sorted_indices[j] == i {
                in_top_k = true
                break
            }
        }

        bool passes_threshold = probs[i] >= min_prob
        mask.append(in_top_k && passes_threshold)
    }

    processor_utils.apply_token_mask(logits, mask)
}

func sample_from_top_k(
    logits: []float,
    processor: top_k_processor,
    temperature: float
) int {

    []float scaled_logits
    for logit in logits {
        scaled_logits.append(logit / temperature)
    }

    []float filtered = apply_top_k(scaled_logits, processor)

    []float probs = processor_utils.softmax(filtered)

    int best_token = 0
    float best_prob = probs[0]

    for i = 1; i < probs.len(); i = i + 1 {
        if probs[i] > best_prob {
            best_prob = probs[i]
            best_token = i
        }
    }

    best_token
}

struct top_k_stats {
    int vocab_size
    int k
    float fraction_kept
    []float top_k_probs
    float cumulative_prob
}

func analyze_top_k_filtering(
    logits: []float,
    k: int
) top_k_stats {
    []float probs = processor_utils.softmax(logits)

    (top_indices, top_scores) := processor_utils.get_top_k_tokens(logits, k)

    float cum_prob = 0.0
    []float top_k_probs

    for idx in top_indices {
        if idx >= 0 && idx < probs.len() {
            top_k_probs.append(probs[idx])
            cum_prob = cum_prob + probs[idx]
        }
    }

    top_k_stats {
        vocab_size: logits.len(),
        k: k,
        fraction_kept: float(k) / float(logits.len()),
        top_k_probs: top_k_probs,
        cumulative_prob: cum_prob,
    }
}

func top_k_stats_to_string(stats: top_k_stats) string {
    string s = ""
    s = s + "Top-K Filtering Statistics\n"
    s = s + "─────────────────────────────\n"
    s = s + "Vocab size: " + int_to_string(stats.vocab_size) + "\n"
    s = s + "K value: " + int_to_string(stats.k) + "\n"
    s = s + "Fraction kept: " + float_to_string(stats.fraction_kept * 100.0) + "%\n"
    s = s + "Cumulative prob: " + float_to_string(stats.cumulative_prob * 100.0) + "%\n"
    s
}
