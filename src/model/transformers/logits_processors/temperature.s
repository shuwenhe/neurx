package neurx.transformers_utils.logits_processors.temperature

use neurx.transformers_utils.logits_processors.processor_utils

struct temperature_processor {
    float temperature
    bool preserve_extremes
}

func create_temperature_processor(float temperature) temperature_processor {
    temp := temperature

    if temp < 0.01 {
        temp = 0.01
    }
    if temp > 10.0 {
        temp = 10.0
    }

    temperature_processor {
        temperature: temp,
        preserve_extremes: false,
    }
}

func apply_temperature(
    logits: float[],
    temperature_processor processor
) float[] {
    float[] scaled_logits

    for logit in logits {
        scaled := logit / processor.temperature
        scaled_logits.append(scaled)
    }

    scaled_logits
}

func apply_temperature_minmax(
    logits: float[],
    float temperature
) float[] {

    float min_logit = logits[0]
    float max_logit = logits[0]

    for i = 1; i < len(logits); i = i + 1 {
        if logits[i] < min_logit {
            min_logit = logits[i]
        }
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
    }

    float range = max_logit - min_logit

    float[] normalized
    if range > 0.0 {
        for logit in logits {
            float norm = (logit - min_logit) / range * 2.0 - 1.0
            normalized.append(norm)
        }
    } else {
        for _ in logits {
            normalized.append(0.0)
        }
    }

    float[] scaled
    for norm_logit in normalized {
        scaled.append(norm_logit / temperature)
    }

    scaled
}

func apply_temperature_batch(
    logits_batch: float[][],
    temperature_processor processor
) float[][] {
    float[][] scaled_batch

    for batch_logits in logits_batch {
        scaled := apply_temperature(batch_logits, processor)
        scaled_batch.append(scaled)
    }

    scaled_batch
}

func sample_with_temperature(
    logits: float[],
    temperature_processor processor
) int {

    float[] scaled = apply_temperature(logits, processor)

    float[] probs = processor_utils.softmax(scaled)

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

func adaptive_temperature_by_entropy(
    logits: float[],
    base_temperature: float,
    float target_entropy
) float {
    float[] probs = processor_utils.softmax(logits)

    float entropy = 0.0
    for prob in probs {
        if prob > 0.0 {
            entropy = entropy - prob * log(prob)
        }
    }

    float max_entropy = log(float(len(logits)))
    float normalized_entropy = entropy / max_entropy

    float adaptive_temp = base_temperature

    if normalized_entropy < target_entropy {

        adaptive_temp = base_temperature * 1.2
    } else if normalized_entropy > target_entropy {

        adaptive_temp = base_temperature * 0.8
    }

    if adaptive_temp < 0.01 {
        adaptive_temp = 0.01
    }
    if adaptive_temp > 10.0 {
        adaptive_temp = 10.0
    }

    adaptive_temp
}

func measure_distribution_diversity(
    logits: float[],
    float temperature
) float {

    float[] scaled_logits
    for logit in logits {
        scaled_logits.append(logit / temperature)
    }

    float[] probs = processor_utils.softmax(scaled_logits)

    float entropy = 0.0
    for prob in probs {
        if prob > 0.0 {
            entropy = entropy - prob * log(prob)
        }
    }

    float max_entropy = log(float(len(logits)))
    entropy / max_entropy
}

func apply_temperature_top_k(
    logits: float[],
    temperature: float,
    int k
) float[] {
    int vocab_size = len(logits)

    float[] scaled_logits
    for logit in logits {
        scaled_logits.append(logit / temperature)
    }

    float[] probs = processor_utils.softmax(scaled_logits)

    int[] sorted_indices
    for i = 0; i < vocab_size; i = i + 1 {
        sorted_indices.append(i)
    }

    for i = 0; i < k && i < vocab_size - 1; i = i + 1 {
        for j = i + 1; j < vocab_size; j = j + 1 {
            if probs[sorted_indices[j]] > probs[sorted_indices[i]] {
                int temp_idx = sorted_indices[i]
                sorted_indices[i] = sorted_indices[j]
                sorted_indices[j] = temp_idx
            }
        }
    }

    bool[] mask
    for i = 0; i < vocab_size; i = i + 1 {
        bool in_top_k = false

        for j = 0; j < k && j < len(sorted_indices); j = j + 1 {
            if sorted_indices[j] == i {
                in_top_k = true
                break
            }
        }

        mask.append(in_top_k)
    }

    processor_utils.apply_token_mask(scaled_logits, mask)
}

struct temperature_stats {
    float temperature
    float entropy_before
    float entropy_after
    float[] prob_top_5
}

func analyze_temperature_effect(
    logits: float[],
    float temperature
) temperature_stats {

    float[] original_probs = processor_utils.softmax(logits)
    float entropy_before = 0.0
    for prob in original_probs {
        if prob > 0.0 {
            entropy_before = entropy_before - prob * log(prob)
        }
    }

    float[] scaled_logits
    for logit in logits {
        scaled_logits.append(logit / temperature)
    }

    float[] scaled_probs = processor_utils.softmax(scaled_logits)
    float entropy_after = 0.0
    for prob in scaled_probs {
        if prob > 0.0 {
            entropy_after = entropy_after - prob * log(prob)
        }
    }

    float[] top_5_probs
    for i = 0; i < 5 && i < len(scaled_probs); i = i + 1 {
        float max_prob = 0.0
        for prob in scaled_probs {
            if prob > max_prob {
                max_prob = prob
            }
        }
        top_5_probs.append(max_prob)
    }

    temperature_stats {
        temperature: temperature,
        entropy_before: entropy_before,
        entropy_after: entropy_after,
        prob_top_5: top_5_probs,
    }
}

func temperature_stats_to_string(temperature_stats stats) string {
    string s = ""
    s = s + "Temperature Effect Analysis\n"
    s = s + "───────────────────────────────\n"
    s = s + "Temperature: " + float_to_string(stats.temperature) + "\n"
    s = s + "Entropy before: " + float_to_string(stats.entropy_before) + "\n"
    s = s + "Entropy after: " + float_to_string(stats.entropy_after) + "\n"
    s = s + "Entropy change: " + float_to_string(stats.entropy_after - stats.entropy_before) + "\n"
    s
}
