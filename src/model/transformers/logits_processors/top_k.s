package neurx.transformers_utils.logits_processors.top_k

use neurx.transformers_utils.logits_processors.processor_utils

struct top_k_processor {
    int k
    float min_tokens_to_keep
    bool filter_value
}

func create_top_k_processor(int k) top_k_processor {
    top_k_processor {
        k: k,
        min_tokens_to_keep: 1.0,
        filter_value: -1000000.0,
    }
}

func apply_top_k(
    logits: float[],
    top_k_processor processor
) float[] {
    int vocab_size = len(logits)
    int k_actual = processor.k

    if k_actual > vocab_size {
        k_actual = vocab_size
    }

    (top_indices, top_scores) := processor_utils.get_top_k_tokens(logits, k_actual)

    bool[] mask
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
    logits_batch: float[][],
    top_k_processor processor
) float[][] {
    float[][] filtered_batch

    for batch_logits in logits_batch {
        filtered := apply_top_k(batch_logits, processor)
        filtered_batch.append(filtered)
    }

    filtered_batch
}

func apply_adaptive_top_k(
    logits: float[],
    base_k: int,
    float entropy_threshold
) float[] {

    float[] probs = processor_utils.softmax(logits)

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
    logits: float[],
    k: int,
    float min_prob
) float[] {
    int vocab_size = len(logits)

    float[] probs = processor_utils.softmax(logits)

    bool[] mask
    int[] sorted_indices

    for i = 0; i < vocab_size; i = i + 1 {
        sorted_indices.append(i)
    }

    for i = 0; i < k && i < len(sorted_indices); i = i + 1 {
        for j = i + 1; j < len(sorted_indices); j = j + 1 {
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
        for j = 0; j < k && j < len(sorted_indices); j = j + 1 {
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
    logits: float[],
    processor: top_k_processor,
    float temperature
) int {

    float[] scaled_logits
    for logit in logits {
        scaled_logits.append(logit / temperature)
    }

    float[] filtered = apply_top_k(scaled_logits, processor)

    float[] probs = processor_utils.softmax(filtered)

    int best_token = 0
    float best_prob = probs[0]

    for i = 1; i < len(probs); i = i + 1 {
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
    float[] top_k_probs
    float cumulative_prob
}

func analyze_top_k_filtering(
    logits: float[],
    int k
) top_k_stats {
    float[] probs = processor_utils.softmax(logits)

    (top_indices, top_scores) := processor_utils.get_top_k_tokens(logits, k)

    float cum_prob = 0.0
    float[] top_k_probs

    for idx in top_indices {
        if idx >= 0 && idx < len(probs) {
            top_k_probs.append(probs[idx])
            cum_prob = cum_prob + probs[idx]
        }
    }

    top_k_stats {
        vocab_size: len(logits),
        k: k,
        fraction_kept: float(k) / float(len(logits)),
        top_k_probs: top_k_probs,
        cumulative_prob: cum_prob,
    }
}

func top_k_stats_to_string(top_k_stats stats) string {
    string s = ""
    s = s + "Top-K Filtering Statistics\n"
    s = s + "─────────────────────────────\n"
    s = s + "Vocab size: " + int_to_string(stats.vocab_size) + "\n"
    s = s + "K value: " + int_to_string(stats.k) + "\n"
    s = s + "Fraction kept: " + float_to_string(stats.fraction_kept * 100.0) + "%\n"
    s = s + "Cumulative prob: " + float_to_string(stats.cumulative_prob * 100.0) + "%\n"
    s
}
