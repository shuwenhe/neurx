package neurx.inference.sampling

func top_p_sample(
    []float logits,
    sampling_config config,
    uint64 rng_state
) (int, uint64) {
    if config.top_p <= 0.0 || config.top_p >= 1.0 {
        if config.do_sample {
            return sample_from_softmax(logits, config.temperature, rng_state)
        } else {
            return (argmax(logits), rng_state)
        }
    }
    []float scaled_logits = apply_temperature(logits, config.temperature)
    []float probs = softmax(scaled_logits)
    []int sorted_indices = argsort_descending(probs)
    float cumsum = 0.0
    int cutoff_idx = len(sorted_indices) - 1
    for i in 0..len(sorted_indices) {
        int idx = sorted_indices[i]
        float prob = probs[idx]
        cumsum = cumsum + prob
        if i == 0 || cumsum < config.top_p {
            cutoff_idx = i
        } else {
            break
        }
    }
    []int filtered_indices = []
    []float filtered_probs = []
    for i in 0..cutoff_idx + 1 {
        if i < len(sorted_indices) {
            filtered_indices = append(filtered_indices, sorted_indices[i])
            filtered_probs = append(filtered_probs, probs[sorted_indices[i]])
        }
    }
    if len(filtered_indices) == 0 {
        return sorted_indices[0], advance_rng(rng_state)
    }
    []float normalized = normalize(filtered_probs)
    int sampled_idx = sample_from_distribution(normalized, rng_state)
    int selected_token = filtered_indices[sampled_idx] if sampled_idx < len(filtered_indices) else filtered_indices[0]
    (selected_token, advance_rng(rng_state))
}

func beam_search_decode(
    [][]float all_logits,
    sampling_config config,
    int eos_token_id,
    int pad_token_id
) []int {
    int num_beams = max(1, config.num_beams)
    int max_length = min(config.max_length, len(all_logits))
    []beam_state beams = []
    beams.push(beam_state {
        token_ids: [],
        score: 0.0,
        is_finished: false,
    })
    []beam_state finished_beams = []
    for step in 0..max_length {
        if len(beams) == 0 {
            break
        }
        []beam_state candidates = []
        for b in 0..len(beams) {
            beam beam = beams[b]
            if beam.is_finished {
                finished_beams = append(finished_beams, beam)
                continue
            }
            []float logits = all_logits[step]
            float length_penalty_factor = compute_length_penalty(
                len(beam.token_ids),
                config.length_penalty
            )
            []float log_probs = log_softmax(logits)
            for t in 0..len(log_probs) {
                float new_score = beam.score + log_probs[t] * length_penalty_factor
                []int new_tokens = copy_int_array(beam.token_ids)
                new_tokens = append(new_tokens, t)
                bool is_eos = (t == eos_token_id)
                             (len(new_tokens) >= config.min_length)
                candidates.push(beam_state {
                    token_ids: new_tokens,
                    score: new_score,
                    is_finished: is_eos,
                })
            }
        }
        if len(candidates) > num_beams {
            candidates = select_top_k_beams(candidates, num_beams)
        }
        beams = []
        for c in 0..len(candidates) {
            if candidates[c].is_finished {
                finished_beams = append(finished_beams, candidates[c])
            } else if len(beams) < num_beams {
                beams = append(beams, candidates[c])
            }
        }
        if config.early_stopping  len(finished_beams) >= num_beams {
            break
        }
    }
    for b in 0..len(beams) {
        finished_beams = append(finished_beams, beams[b])
    }
    if len(finished_beams) > 0 {
        beam best = find_best_beam(finished_beams)
        return best.token_ids
    }
    []
}
