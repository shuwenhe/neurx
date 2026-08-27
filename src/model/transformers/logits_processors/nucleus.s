package neurx.transformers_utils.logits_processors.nucleus

use neurx.transformers_utils.logits_processors.processor_utils

struct nucleus_processor {
    float p
    int min_tokens_to_keep
    float epsilon
}

func create_nucleus_processor(float p) nucleus_processor {
    nucleus_processor {
        p: p,
        min_tokens_to_keep: 1,
        epsilon: 1e-7,
    }
}

func apply_nucleus(
    logits: float[],
    nucleus_processor processor
) float[] {
    int vocab_size = len(logits)

    float[] probs = processor_utils.softmax(logits)

    int[] sorted_indices
    for i = 0; i < vocab_size; i = i + 1 {
        sorted_indices.append(i)
    }

    for i = 0; i < vocab_size - 1; i = i + 1 {
        for j = i + 1; j < vocab_size; j = j + 1 {
            idx_i := sorted_indices[i]
            idx_j := sorted_indices[j]

            if probs[idx_j] > probs[idx_i] {
                sorted_indices[i] = idx_j
                sorted_indices[j] = idx_i
            }
        }
    }

    float cumsum = 0.0
    int num_tokens_to_keep = processor.min_tokens_to_keep

    for i = 0; i < vocab_size; i = i + 1 {
        idx := sorted_indices[i]
        cumsum = cumsum + probs[idx]

        if cumsum >= processor.p {
            num_tokens_to_keep = i + 1
            break
        }
    }

    bool[] mask
    for i = 0; i < vocab_size; i = i + 1 {
        bool keep = false

        for j = 0; j < num_tokens_to_keep; j = j + 1 {
            if sorted_indices[j] == i {
                keep = true
                break
            }
        }

        mask.append(keep)
    }

    processor_utils.apply_token_mask(logits, mask)
}

func apply_adaptive_nucleus(
    logits: float[],
    base_p: float,
    float temperature
) float[] {

    float adaptive_p = base_p

    if temperature < 0.5 {
        adaptive_p = base_p * 0.7
    } else if temperature > 1.5 {
        adaptive_p = base_p * 1.2
    }

    if adaptive_p > 1.0 {
        adaptive_p = 1.0
    }
    if adaptive_p < 0.0 {
        adaptive_p = 0.0
    }

    processor := create_nucleus_processor(adaptive_p)
    apply_nucleus(logits, processor)
}

func apply_nucleus_batch(
    logits_batch: float[][],
    nucleus_processor processor
) float[][] {
    float[][] filtered_batch

    for batch_logits in logits_batch {
        filtered := apply_nucleus(batch_logits, processor)
        filtered_batch.append(filtered)
    }

    filtered_batch
}

func sample_from_nucleus(
    logits: float[],
    processor: nucleus_processor,
    float temperature
) int {

    float[] scaled_logits
    for logit in logits {
        scaled_logits.append(logit / temperature)
    }

    float[] filtered = apply_nucleus(scaled_logits, processor)

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

func apply_top_k_nucleus(
    logits: float[],
    k: int,
    float p
) float[] {
    int vocab_size = len(logits)

    float[] probs = processor_utils.softmax(logits)

    int[] sorted_indices
    for i = 0; i < vocab_size; i = i + 1 {
        sorted_indices.append(i)
    }

    for i = 0; i < vocab_size - 1; i = i + 1 {
        for j = i + 1; j < vocab_size; j = j + 1 {
            idx_i := sorted_indices[i]
            idx_j := sorted_indices[j]

            if probs[idx_j] > probs[idx_i] {
                sorted_indices[i] = idx_j
                sorted_indices[j] = idx_i
            }
        }
    }

    int num_to_keep = k
    if num_to_keep > vocab_size {
        num_to_keep = vocab_size
    }

    float cumsum = 0.0
    for i = 0; i < num_to_keep; i = i + 1 {
        idx := sorted_indices[i]
        cumsum = cumsum + probs[idx]

        if cumsum >= p {
            num_to_keep = i + 1
            break
        }
    }

    bool[] mask
    for i = 0; i < vocab_size; i = i + 1 {
        bool keep = false

        for j = 0; j < num_to_keep; j = j + 1 {
            if sorted_indices[j] == i {
                keep = true
                break
            }
        }

        mask.append(keep)
    }

    processor_utils.apply_token_mask(logits, mask)
}

struct nucleus_stats {
    int vocab_size
    float p
    int num_tokens_kept
    float fraction_kept
    float cumulative_prob
    float[] kept_token_probs
}

func analyze_nucleus_filtering(
    logits: float[],
    float p
) nucleus_stats {
    float[] probs = processor_utils.softmax(logits)
    int vocab_size = len(logits)

    int[] sorted_indices
    for i = 0; i < vocab_size; i = i + 1 {
        sorted_indices.append(i)
    }

    for i = 0; i < vocab_size - 1; i = i + 1 {
        for j = i + 1; j < vocab_size; j = j + 1 {
            if probs[sorted_indices[j]] > probs[sorted_indices[i]] {
                int temp = sorted_indices[i]
                sorted_indices[i] = sorted_indices[j]
                sorted_indices[j] = temp
            }
        }
    }

    float cumsum = 0.0
    int num_kept = 0
    float[] kept_probs

    for i = 0; i < vocab_size; i = i + 1 {
        idx := sorted_indices[i]
        cumsum = cumsum + probs[idx]
        kept_probs.append(probs[idx])
        num_kept = num_kept + 1

        if cumsum >= p {
            break
        }
    }

    nucleus_stats {
        vocab_size: vocab_size,
        p: p,
        num_tokens_kept: num_kept,
        fraction_kept: float(num_kept) / float(vocab_size),
        cumulative_prob: cumsum,
        kept_token_probs: kept_probs,
    }
}

func nucleus_stats_to_string(nucleus_stats stats) string {
    string s = ""
    s = s + "Nucleus (Top-P) Filtering Statistics\n"
    s = s + "────────────────────────────────────\n"
    s = s + "Vocab size: " + int_to_string(stats.vocab_size) + "\n"
    s = s + "P value: " + float_to_string(stats.p) + "\n"
    s = s + "Tokens kept: " + int_to_string(stats.num_tokens_kept) + "\n"
    s = s + "Fraction kept: " + float_to_string(stats.fraction_kept * 100.0) + "%\n"
    s = s + "Cumulative prob: " + float_to_string(stats.cumulative_prob * 100.0) + "%\n"
    s
}
