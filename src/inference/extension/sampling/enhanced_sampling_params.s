package sampling

type sampling_type int32

const (
	sampling_greedy     sampling_type = 0
	sampling_random     sampling_type = 1
	sampling_beam       sampling_type = 2
	sampling_diverse    sampling_type = 3
	sampling_contrastive sampling_type = 4
)

type penalty_type int32

const (
	penalty_none       penalty_type = 0
	penalty_frequency  penalty_type = 1
	penalty_presence   penalty_type = 2
	penalty_repetition penalty_type = 3
)

struct sampling_params {
	method sampling_type
	n int32
	temperature float32
	top_k int32
	top_p float32
	min_p float32
	top_n_tokens int32
	seed int32
	presence_penalty float32
	frequency_penalty float32
	repetition_penalty float32
	length_penalty float32
	diversity_penalty float32
	do_sample bool
	use_logits_processor bool
	ignore_eos bool
	skip_special_tokens bool
	max_tokens int32
	min_tokens int32
	logprobs int32
	prompt_logprobs int32
	include_stop_sequences bool
	stop_token_ids int32[]
	bad_token_ids int32[]
	forced_token_ids int32[]

	beam_width int32
	num_beam_groups int32
	diversity_penalty_in_beam float32
	early_stopping_cond bool
	num_return_sequences int32

	contrastive_alpha float32
	contrastive_k int32
	contrastive_degenerate_to_greedy bool

	ngram_size int32
	ngram_penalty float32

	length_norm float32
	no_repeat_ngram_size int32

	encoder_no_repeat_ngram_size int32

	remove_invalid_values bool
}

func create_sampling_params() sampling_params* {
	return *sampling_params{
		method: sampling_greedy,
		n: 1,
		temperature: 1.0,
		top_k: 0,
		top_p: 1.0,
		min_p: 0.0,
		top_n_tokens: 0,
		seed: 42,
		presence_penalty: 0.0,
		frequency_penalty: 0.0,
		repetition_penalty: 1.0,
		length_penalty: 1.0,
		diversity_penalty: 0.0,
		do_sample: true,
		use_logits_processor: true,
		ignore_eos: false,
		skip_special_tokens: false,
		max_tokens: 512,
		min_tokens: 0,
		logprobs: 0,
		prompt_logprobs: 0,
		include_stop_sequences: false,
		stop_token_ids: make(int32[]),
		bad_token_ids: make(int32[]),
		forced_token_ids: make(int32[]),
		beam_width: 1,
		num_beam_groups: 1,
		diversity_penalty_in_beam: 0.0,
		early_stopping_cond: false,
		num_return_sequences: 1,
		contrastive_alpha: 0.5,
		contrastive_k: 4,
		contrastive_degenerate_to_greedy: false,
		ngram_size: 0,
		ngram_penalty: 1.0,
		length_norm: 1.0,
		no_repeat_ngram_size: 0,
		encoder_no_repeat_ngram_size: 0,
		remove_invalid_values: true,
	}
}

func (p* sampling_params) set_temperature(t float32) {
	if t < 0.0 {
		t = 0.0
	}
	if t > 10.0 {
		t = 10.0
	}
	p.temperature = t
}

func (p* sampling_params) set_top_k(k int32) {
	if k < 0 {
		k = 0
	}
	p.top_k = k
}

func (p* sampling_params) set_top_p(p_val float32) {
	if p_val < 0.0 {
		p_val = 0.0
	}
	if p_val > 1.0 {
		p_val = 1.0
	}
	p.top_p = p_val
}

func (p* sampling_params) set_min_p(min_val float32) {
	if min_val < 0.0 {
		min_val = 0.0
	}
	if min_val > 1.0 {
		min_val = 1.0
	}
	p.min_p = min_val
}

func (p* sampling_params) set_frequency_penalty(pen float32) {
	if pen < -2.0 {
		pen = -2.0
	}
	if pen > 2.0 {
		pen = 2.0
	}
	p.frequency_penalty = pen
}

func (p* sampling_params) set_presence_penalty(pen float32) {
	if pen < -2.0 {
		pen = -2.0
	}
	if pen > 2.0 {
		pen = 2.0
	}
	p.presence_penalty = pen
}

func (p* sampling_params) set_repetition_penalty(pen float32) {
	if pen < 0.0 {
		pen = 1.0
	}
	if pen > 10.0 {
		pen = 10.0
	}
	p.repetition_penalty = pen
}

func (p* sampling_params) set_length_penalty(pen float32) {
	if pen < 0.0 {
		pen = 1.0
	}
	if pen > 10.0 {
		pen = 10.0
	}
	p.length_penalty = pen
}

func (p* sampling_params) set_diversity_penalty(pen float32) {
	if pen < 0.0 {
		pen = 0.0
	}
	if pen > 1.0 {
		pen = 1.0
	}
	p.diversity_penalty = pen
}

func (p* sampling_params) set_beam_search(width int32, num_groups int32, div_pen float32) {
	if width < 1 {
		width = 1
	}
	if width > 32 {
		width = 32
	}
	p.beam_width = width
	p.method = sampling_beam

	if num_groups > 1 {
		p.num_beam_groups = num_groups
	}

	if div_pen >= 0.0 {
		p.diversity_penalty_in_beam = div_pen
	}
}

func (p* sampling_params) set_contrastive_search(alpha float32, k int32, degenerate bool) {
	if alpha < 0.0 {
		alpha = 0.0
	}
	if alpha > 1.0 {
		alpha = 1.0
	}
	p.contrastive_alpha = alpha

	if k < 1 {
		k = 4
	}
	if k > 100 {
		k = 100
	}
	p.contrastive_k = k

	p.contrastive_degenerate_to_greedy = degenerate
	p.method = sampling_contrastive
}

func (p* sampling_params) add_stop_token(token_id int32) {
	if len(p.stop_token_ids) < 10 {
		p.stop_token_ids = append(p.stop_token_ids, token_id)
	}
}

func (p* sampling_params) add_bad_token(token_id int32) {
	if len(p.bad_token_ids) < 100 {
		p.bad_token_ids = append(p.bad_token_ids, token_id)
	}
}

func (p* sampling_params) validate() bool {
	if p.temperature < 0.0 {
		return false
	}

	if p.top_p < 0.0 || p.top_p > 1.0 {
		return false
	}

	if p.top_k < 0 {
		return false
	}

	if p.min_p < 0.0 || p.min_p > 1.0 {
		return false
	}

	if p.presence_penalty < -2.0 || p.presence_penalty > 2.0 {
		return false
	}

	if p.frequency_penalty < -2.0 || p.frequency_penalty > 2.0 {
		return false
	}

	if p.repetition_penalty < 0.0 {
		return false
	}

	if p.beam_width < 1 {
		return false
	}

	if p.max_tokens < 0 {
		return false
	}

	if p.min_tokens < 0 || p.min_tokens > p.max_tokens {
		return false
	}

	return true
}

func (p* sampling_params) to_dict() map[string]interface{} {
	result := make(map[string]interface{})

	result["method"] = int32(p.method)
	result["n"] = p.n
	result["temperature"] = p.temperature
	result["top_k"] = p.top_k
	result["top_p"] = p.top_p
	result["min_p"] = p.min_p
	result["presence_penalty"] = p.presence_penalty
	result["frequency_penalty"] = p.frequency_penalty
	result["repetition_penalty"] = p.repetition_penalty
	result["length_penalty"] = p.length_penalty
	result["beam_width"] = p.beam_width
	result["max_tokens"] = p.max_tokens
	result["min_tokens"] = p.min_tokens
	result["seed"] = p.seed

	return result
}

func (p* sampling_params) clone() sampling_params* {
	new_params := create_sampling_params()

	new_params.method = p.method
	new_params.n = p.n
	new_params.temperature = p.temperature
	new_params.top_k = p.top_k
	new_params.top_p = p.top_p
	new_params.min_p = p.min_p
	new_params.seed = p.seed
	new_params.presence_penalty = p.presence_penalty
	new_params.frequency_penalty = p.frequency_penalty
	new_params.repetition_penalty = p.repetition_penalty
	new_params.length_penalty = p.length_penalty
	new_params.diversity_penalty = p.diversity_penalty
	new_params.do_sample = p.do_sample
	new_params.max_tokens = p.max_tokens
	new_params.min_tokens = p.min_tokens
	new_params.beam_width = p.beam_width
	new_params.num_beam_groups = p.num_beam_groups
	new_params.diversity_penalty_in_beam = p.diversity_penalty_in_beam
	new_params.contrastive_alpha = p.contrastive_alpha
	new_params.contrastive_k = p.contrastive_k

	return new_params
}
