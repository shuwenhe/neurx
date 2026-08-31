struct draft_token {
    int token_id
    logits: float[]
    float confidence
}

struct verification_result {
    bool accepted
    int num_accepted_tokens
    int fallback_token_id
    verification_logits: float[]
}

struct speculative_batch {
    int batch_id
    sequence_ids: int[]
    draft_predictions: [][]draft_token
    verification_results: []verification_result
    float acceptance_rate
    float draft_time_ms
    float verify_time_ms
}

struct speculative_decode_config {
    int num_draft_tokens
    float draft_model_scale
    float temperature
    int top_k
    float top_p
    bool use_temperature_scaling
    int max_speculative_length
}

struct speculative_statistics {
    int64 total_tokens_generated
    int64 total_draft_tokens
    int64 total_verified_tokens
    int64 total_accepted_tokens
    int64 total_rejected_tokens
    float average_acceptance_rate
    float64 cumulative_time_saved_ms
    float verification_accuracy
}

func new_speculative_config(int num_draft, float draft_scale, float temp) speculative_decode_config {
    config := speculative_decode_config{
        num_draft_tokens: num_draft,
        draft_model_scale: draft_scale,
        temperature: temp,
        top_k: 50,
        top_p: 0.95,
        use_temperature_scaling: true,
        max_speculative_length: 16,
    }
    config
}

func new_draft_token(int token_id, float[] logits, float conf) draft_token {
    dt := draft_token{
        token_id: token_id,
        logits: logits,
        confidence: conf,
    }
    dt
}

func new_verification_result(bool accepted, int num_accepted, int fallback_id) verification_result {
    vr := verification_result{
        accepted: accepted,
        num_accepted_tokens: num_accepted,
        fallback_token_id: fallback_id,
        verification_logits: []float{},
    }
    vr
}

func new_speculative_batch(int batch_id, int[] seq_ids) speculative_batch {
    sb := speculative_batch{
        batch_id: batch_id,
        sequence_ids: seq_ids,
        draft_predictions: [][]draft_token{},
        verification_results: []verification_result{},
        acceptance_rate: 0.0,
        draft_time_ms: 0.0,
        verify_time_ms: 0.0,
    }
    sb
}

func compute_logits_probability(float[] logits, float temperature) []float {
    probs := []float{}
    max_logit := -1000000.0
    i := 0
    for i < logits.len {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    sum_exp := 0.0
    i = 0
    for i < logits.len {
        scaled := (logits[i] - max_logit) / temperature
        exp_val := 2.718281828 ^ scaled
        probs = append(probs, exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    i = 0
    for i < probs.len {
        probs[i] = probs[i] / sum_exp
        i = i + 1
    }
    probs
}

func sample_top_k(float[] logits, int k, float temperature) int {
    probs := compute_logits_probability(logits, temperature)
    top_k_indices := []int{}
    top_k_probs := []float{}
    i := 0
    for i < logits.len {
        if i < k || i == 0 {
            top_k_indices = append(top_k_indices, i)
            top_k_probs = append(top_k_probs, probs[i])
        } else {
            min_prob := top_k_probs[0]
            min_idx := 0
            j := 1
            for j < top_k_probs.len {
                if top_k_probs[j] < min_prob {
                    min_prob = top_k_probs[j]
                    min_idx = j
                }
                j = j + 1
            }
            if probs[i] > min_prob {
                top_k_indices[min_idx] = i
                top_k_probs[min_idx] = probs[i]
            }
        }
        i = i + 1
    }
    selected_idx := 0
    rand_val := 0.5
    cumsum := 0.0
    i = 0
    for i < top_k_probs.len {
        cumsum = cumsum + top_k_probs[i]
        if cumsum >= rand_val {
            selected_idx = i
            break
        }
        i = i + 1
    }
    if selected_idx < top_k_indices.len {
        top_k_indices[selected_idx]
    } else {
        top_k_indices[0]
    }
}

func verify_token_match(float[] draft_logits, float[] verify_logits, float temperature) bool {
    draft_probs := compute_logits_probability(draft_logits, temperature)
    verify_probs := compute_logits_probability(verify_logits, temperature)
    draft_top := 0
    verify_top := 0
    max_draft := draft_probs[0]
    max_verify := verify_probs[0]
    i := 1
    for i < draft_probs.len {
        if draft_probs[i] > max_draft {
            max_draft = draft_probs[i]
            draft_top = i
        }
        if verify_probs[i] > max_verify {
            max_verify = verify_probs[i]
            verify_top = i
        }
        i = i + 1
    }
    draft_top == verify_top
}

func compute_confidence_score(float[] logits) float {
    probs := compute_logits_probability(logits, 1.0)
    max_prob := probs[0]
    i := 1
    for i < probs.len {
        if probs[i] > max_prob {
            max_prob = probs[i]
        }
        i = i + 1
    }
    max_prob
}

func filter_predictions_by_confidence([]draft_token predictions, float threshold) []draft_token {
    filtered := []draft_token{}
    i := 0
    for i < predictions.len {
        if predictions[i].confidence >= threshold {
            filtered = append(filtered, predictions[i])
        }
        i = i + 1
    }
    filtered
}

func new_speculative_statistics() speculative_statistics {
    stats := speculative_statistics{
        total_tokens_generated: 0,
        total_draft_tokens: 0,
        total_verified_tokens: 0,
        total_accepted_tokens: 0,
        total_rejected_tokens: 0,
        average_acceptance_rate: 0.0,
        cumulative_time_saved_ms: 0.0,
        verification_accuracy: 0.0,
    }
    stats
}

func update_statistics(speculative_statistics stats, speculative_batch batch) speculative_statistics {
    updated := stats
    i := 0
    for i < batch.verification_results.len {
        updated.total_verified_tokens = updated.total_verified_tokens + 1
        if batch.verification_results[i].accepted {
            updated.total_accepted_tokens = updated.total_accepted_tokens + batch.verification_results[i].num_accepted_tokens
        } else {
            updated.total_rejected_tokens = updated.total_rejected_tokens + 1
        }
        i = i + 1
    }
    updated
}

func get_acceptance_rate(speculative_statistics stats) float {
    if stats.total_verified_tokens > 0 {
        (stats.total_accepted_tokens as float) / (stats.total_verified_tokens as float)
    } else {
        0.0
    }
}

func get_speedup_factor(speculative_statistics stats) float {
    if stats.total_draft_tokens > 0 {
        (stats.total_accepted_tokens + stats.total_verified_tokens) as float / (stats.total_verified_tokens as float)
    } else {
        1.0
    }
}
