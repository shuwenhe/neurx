package sampling
import "math"
struct token_frequency {
	token_id int32
	frequency int32
}

func apply_frequency_penalty(float32[] logits, map[int32]int32 token_freq, float32 penalty) []float32 {
	adjusted := make(float32[])
	for i := 0; i < len(logits); i = i + 1 {
		token_id := int32(i)
		freq := 0
		if token_freq != nil {
			val, exists := token_freq[token_id]
			if exists {
				freq = val
			}
		}
		adjusted_logit := logits[i] - float32(freq) * penalty
		adjusted = append(adjusted, adjusted_logit)
	}
	return adjusted
}

func apply_presence_penalty(float32[] logits, map[int32]int32 token_freq, float32 penalty) []float32 {
	adjusted := make(float32[])
	for i := 0; i < len(logits); i = i + 1 {
		token_id := int32(i)
		has_appeared := false
		if token_freq != nil {
			val, exists := token_freq[token_id]
			if exists && val > 0 {
				has_appeared = true
			}
		}
		adjusted_logit := logits[i]
		if has_appeared {
			adjusted_logit = adjusted_logit - penalty
		}
		adjusted = append(adjusted, adjusted_logit)
	}
	return adjusted
}

func apply_repetition_penalty(float32[] logits, map[int32]int32 token_freq, float32 penalty) []float32 {
	adjusted := make(float32[])
	for i := 0; i < len(logits); i = i + 1 {
		token_id := int32(i)
		freq := 0
		if token_freq != nil {
			val, exists := token_freq[token_id]
			if exists {
				freq = val
			}
		}
		adjusted_logit := logits[i]
		if freq > 0 && penalty != 1.0 {
			if penalty > 1.0 {
				adjusted_logit = adjusted_logit / penalty
			} else if penalty < 1.0 && adjusted_logit < 0.0 {
				adjusted_logit = adjusted_logit * penalty
			} else if penalty < 1.0 {
				adjusted_logit = adjusted_logit / penalty
			}
		}
		adjusted = append(adjusted, adjusted_logit)
	}
	return adjusted
}

func apply_length_penalty(float32[] logits, int32 generated_length, float32 penalty) []float32 {
	adjusted := make(float32[])
	if penalty <= 0.0 {
		return logits
	}
	length_factor := 1.0
	if generated_length > 0 {
		length_factor = math.pow(float32(generated_length), penalty)
	}
	for i := 0; i < len(logits); i = i + 1 {
		adjusted_logit := logits[i] / length_factor
		adjusted = append(adjusted, adjusted_logit)
	}
	return adjusted
}

func apply_ngram_penalty(float32[] logits, int32[] generated_tokens, int32 ngram_size, float32 penalty) []float32 {
	if ngram_size <= 0 || penalty <= 0.0 {
		return logits
	}
	adjusted := make(float32[])
	for i := 0; i < len(logits); i = i + 1 {
		token_id := int32(i)
		would_repeat_ngram := false
		if len(generated_tokens) >= int32(ngram_size - 1) {
			start_idx := len(generated_tokens) - int32(ngram_size - 1)
			ngram_matches := true
			for j := int32(0); j < ngram_size - 1; j = j + 1 {
				if start_idx + j < 0 || start_idx + j >= int32(len(generated_tokens)) {
					ngram_matches = false
					break
				}
				if generated_tokens[start_idx + j] != token_id {
					ngram_matches = false
					break
				}
			}
			if ngram_matches {
				would_repeat_ngram = true
			}
		}
		adjusted_logit := logits[i]
		if would_repeat_ngram {
			adjusted_logit = adjusted_logit - penalty
		}
		adjusted = append(adjusted, adjusted_logit)
	}
	return adjusted
}

func apply_bad_token_mask(float32[] logits, int32[] bad_token_ids) []float32 {
	if len(bad_token_ids) == 0 {
		return logits
	}
	adjusted := make(float32[])
	for i := 0; i < len(logits); i = i + 1 {
		token_id := int32(i)
		is_bad := false
		for j := 0; j < len(bad_token_ids); j = j + 1 {
			if bad_token_ids[j] == token_id {
				is_bad = true
				break
			}
		}
		val := logits[i]
		if is_bad {
			val = -1e9
		}
		adjusted = append(adjusted, val)
	}
	return adjusted
}

func apply_forced_token_boost(float32[] logits, int32[] forced_token_ids, float32 boost) []float32 {
	if len(forced_token_ids) == 0 {
		return logits
	}
	adjusted := make(float32[])
	for i := 0; i < len(logits); i = i + 1 {
		token_id := int32(i)
		is_forced := false
		for j := 0; j < len(forced_token_ids); j = j + 1 {
			if forced_token_ids[j] == token_id {
				is_forced = true
				break
			}
		}
		val := logits[i]
		if is_forced {
			val = val + boost
		}
		adjusted = append(adjusted, val)
	}
	return adjusted
}

func compute_token_frequency(int32[] tokens) map[int32]int32 {
	freq_map := make(map[int32]int32)
	for i := 0; i < len(tokens); i = i + 1 {
		token_id := tokens[i]
		count, exists := freq_map[token_id]
		if exists {
			freq_map[token_id] = count + 1
		} else {
			freq_map[token_id] = 1
		}
	}
	return freq_map
}

func apply_all_penalties(float32[] logits, int32[] generated_tokens, penalty_config* penalty_params) []float32 {
	adjusted := logits
	if penalty_config == nil {
		return adjusted
	}
	token_freq := compute_token_frequency(generated_tokens)
	if penalty_config.frequency_penalty != 0.0 {
		adjusted = apply_frequency_penalty(adjusted, token_freq, penalty_config.frequency_penalty)
	}
	if penalty_config.presence_penalty != 0.0 {
		adjusted = apply_presence_penalty(adjusted, token_freq, penalty_config.presence_penalty)
	}
	if penalty_config.repetition_penalty != 1.0 {
		adjusted = apply_repetition_penalty(adjusted, token_freq, penalty_config.repetition_penalty)
	}
	if penalty_config.length_penalty != 1.0 {
		adjusted = apply_length_penalty(adjusted, int32(len(generated_tokens)), penalty_config.length_penalty)
	}
	if penalty_config.ngram_size > 0 && penalty_config.ngram_penalty > 0.0 {
		adjusted = apply_ngram_penalty(adjusted, generated_tokens, penalty_config.ngram_size, penalty_config.ngram_penalty)
	}
	if len(penalty_config.bad_tokens) > 0 {
		adjusted = apply_bad_token_mask(adjusted, penalty_config.bad_tokens)
	}
	if len(penalty_config.forced_tokens) > 0 {
		adjusted = apply_forced_token_boost(adjusted, penalty_config.forced_tokens, penalty_config.forced_boost)
	}
	return adjusted
}

struct penalty_params {
	frequency_penalty float32
	presence_penalty float32
	repetition_penalty float32
	length_penalty float32
	ngram_size int32
	ngram_penalty float32
	bad_tokens int32[]
	forced_tokens int32[]
	forced_boost float32
}

func create_penalty_params() penalty_params* {
	return *penalty_params{
		frequency_penalty: 0.0,
		presence_penalty: 0.0,
		repetition_penalty: 1.0,
		length_penalty: 1.0,
		ngram_size: 0,
		ngram_penalty: 0.0,
		bad_tokens: make(int32[]),
		forced_tokens: make(int32[]),
		forced_boost: 10.0,
	}
}

func (p* penalty_params) set_frequency_penalty(pen float32) {
	if pen < -2.0 {
		pen = -2.0
	}
	if pen > 2.0 {
		pen = 2.0
	}
	p.frequency_penalty = pen
}

func (p* penalty_params) set_presence_penalty(pen float32) {
	if pen < -2.0 {
		pen = -2.0
	}
	if pen > 2.0 {
		pen = 2.0
	}
	p.presence_penalty = pen
}

func (p* penalty_params) set_repetition_penalty(pen float32) {
	if pen < 0.0 {
		pen = 1.0
	}
	p.repetition_penalty = pen
}

func (p* penalty_params) add_bad_token(token_id int32) {
	if len(p.bad_tokens) < 100 {
		p.bad_tokens = append(p.bad_tokens, token_id)
	}
}

func (p* penalty_params) add_forced_token(token_id int32) {
	if len(p.forced_tokens) < 50 {
		p.forced_tokens = append(p.forced_tokens, token_id)
	}
}
