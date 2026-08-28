package sampling
import "math"
struct beam_hypothesis {
	sequences int32[]
	score float32
	length int32
}

struct beam_search_state {
	beam_width int32
	max_length int32
	length_penalty float32
	early_stopping bool
	num_beams int32
	current_beams beam_hypothesis[]
	final_beams beam_hypothesis[]
	batch_size int32
	eos_token_id int32
	pad_token_id int32
	step int32
}

func create_beam_search_state(int32 beam_width, int32 max_length, float32 length_penalty, bool early_stopping) beam_search_state* {
	return *beam_search_state{
		beam_width: beam_width,
		max_length: max_length,
		length_penalty: length_penalty,
		early_stopping: early_stopping,
		num_beams: beam_width,
		current_beams: make(beam_hypothesis[]),
		final_beams: make(beam_hypothesis[]),
		batch_size: 1,
		eos_token_id: 2,
		pad_token_id: 0,
		step: 0,
	}
}

func (b* beam_search_state) init_beams(int32[] initial_tokens) {
	b.current_beams = make(beam_hypothesis[])
	for i := 0; i < int32(b.beam_width); i = i + 1 {
		beam := beam_hypothesis{
			sequences: make(int32[]),
			score: 0.0,
			length: 1,
		}
		if i < len(initial_tokens) {
			beam.sequences = append(beam.sequences, initial_tokens[i])
		}
		b.current_beams = append(b.current_beams, beam)
	}
	b.step = 1
}

func (b* beam_search_state) expand_beams(float32[] logits) beam_hypothesis[] {
	candidates := make(beam_hypothesis[])
	for beam_idx := 0; beam_idx < len(b.current_beams); beam_idx = beam_idx + 1 {
		beam := b.current_beams[beam_idx]
		for token_idx := 0; token_idx < len(logits); token_idx = token_idx + 1 {
			next_score := beam.score + logits[token_idx]
			new_sequences := make(int32[])
			for j := 0; j < len(beam.sequences); j = j + 1 {
				new_sequences = append(new_sequences, beam.sequences[j])
			}
			new_sequences = append(new_sequences, int32(token_idx))
			new_beam := beam_hypothesis{
				sequences: new_sequences,
				score: next_score,
				length: beam.length + 1,
			}
			candidates = append(candidates, new_beam)
		}
	}
	return candidates
}

func (b* beam_search_state) select_top_beams(beam_hypothesis[] candidates) beam_hypothesis[] {
	if len(candidates) <= 0 {
		return make(beam_hypothesis[])
	}
	sorted := make(beam_hypothesis[])
	for i := 0; i < len(candidates); i = i + 1 {
		sorted = append(sorted, candidates[i])
	}
	for i := 0; i < len(sorted); i = i + 1 {
		max_idx := i
		for j := i + 1; j < len(sorted); j = j + 1 {
			normalized_score_j := sorted[j].score / math.pow(float32(sorted[j].length), b.length_penalty)
			normalized_score_max := sorted[max_idx].score / math.pow(float32(sorted[max_idx].length), b.length_penalty)
			if normalized_score_j > normalized_score_max {
				max_idx = j
			}
		}
		temp := sorted[i]
		sorted[i] = sorted[max_idx]
		sorted[max_idx] = temp
	}
	result := make(beam_hypothesis[])
	for i := 0; i < len(sorted) && i < int32(b.beam_width); i = i + 1 {
		result = append(result, sorted[i])
	}
	return result
}

func (b* beam_search_state) step_beam_search(float32[] logits) bool {
	if b.step >= b.max_length {
		return false
	}
	candidates := b.expand_beams(logits)
	new_beams := b.select_top_beams(candidates)
	b.current_beams = new_beams
	b.step = b.step + 1
	return true
}

func (b* beam_search_state) finalize() int32[][]] {
	result := make(int32[][]])
	sorted := make(beam_hypothesis[])
	for i := 0; i < len(b.current_beams); i = i + 1 {
		sorted = append(sorted, b.current_beams[i])
	}
	for i := 0; i < len(sorted); i = i + 1 {
		max_idx := i
		for j := i + 1; j < len(sorted); j = j + 1 {
			normalized_score_j := sorted[j].score / math.pow(float32(sorted[j].length), b.length_penalty)
			normalized_score_max := sorted[max_idx].score / math.pow(float32(sorted[max_idx].length), b.length_penalty)
			if normalized_score_j > normalized_score_max {
				max_idx = j
			}
		}
		temp := sorted[i]
		sorted[i] = sorted[max_idx]
		sorted[max_idx] = temp
	}
	for i := 0; i < len(sorted); i = i + 1 {
		result = append(result, sorted[i].sequences)
	}
	return result
}

func (b* beam_search_state) is_finished() bool {
	if b.step >= b.max_length {
		return true
	}
	finished_count := 0
	for i := 0; i < len(b.current_beams); i = i + 1 {
		if len(b.current_beams[i].sequences) > 0 {
			last_token := b.current_beams[i].sequences[len(b.current_beams[i].sequences) - 1]
			if last_token == b.eos_token_id {
				finished_count = finished_count + 1
			}
		}
	}
	if finished_count >= b.beam_width {
		return true
	}
	return false
}

struct diverse_beam_search_state {
	base_state* beam_search_state
	num_groups int32
	diversity_penalty float32
	group_beams beam_hypothesis[[]]
}

func create_diverse_beam_search_state(int32 beam_width, int32 num_groups, float32 diversity_penalty) diverse_beam_search_state* {
	if num_groups <= 0 {
		num_groups = 1
	}
	group_width := beam_width / num_groups
	return *diverse_beam_search_state{
		base_state: create_beam_search_state(group_width, 512, 1.0, false),
		num_groups: num_groups,
		diversity_penalty: diversity_penalty,
		group_beams: make(beam_hypothesis[[]]),
	}
}

func (d* diverse_beam_search_state) step(float32[] logits) bool {
	for group_idx := 0; group_idx < int32(d.num_groups); group_idx = group_idx + 1 {
		adjusted_logits := make(float32[])
		for token_idx := 0; token_idx < len(logits); token_idx = token_idx + 1 {
			val := logits[token_idx]
			diversity_cost := 0.0
			for prev_group := 0; prev_group < group_idx; prev_group = prev_group + 1 {
				if prev_group < len(d.group_beams) && len(d.group_beams[prev_group]) > 0 {
					top_beam := d.group_beams[prev_group][0]
					if len(top_beam.sequences) > 0 {
						for j := 0; j < len(top_beam.sequences); j = j + 1 {
							if top_beam.sequences[j] == int32(token_idx) {
								diversity_cost = diversity_cost + d.diversity_penalty
							}
						}
					}
				}
			}
			adjusted_logits = append(adjusted_logits, val - diversity_cost)
		}
	}
	return true
}

func calculate_beam_search_probs(float32[] logits) float32[] {
	max_logit := logits[0]
	for i := 1; i < len(logits); i = i + 1 {
		if logits[i] > max_logit {
			max_logit = logits[i]
		}
	}
	probs := make(float32[])
	sum := 0.0
	for i := 0; i < len(logits); i = i + 1 {
		exp_val := math.exp(logits[i] - max_logit)
		sum = sum + exp_val
		probs = append(probs, exp_val)
	}
	for i := 0; i < len(probs); i = i + 1 {
		probs[i] = probs[i] / sum
	}
	return probs
}
