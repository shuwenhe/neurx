package sampling

type sampler_type int32

const (
	sampler_type_greedy      sampler_type = 0
	sampler_type_random      sampler_type = 1
	sampler_type_top_k       sampler_type = 2
	sampler_type_top_p       sampler_type = 3
	sampler_type_beam        sampler_type = 4
	sampler_type_contrastive sampler_type = 5
	sampler_type_diverse     sampler_type = 6
	sampler_type_custom      sampler_type = 7
)

interface sampler {
	sample(vec[float32] logits) int32
	batch_sample(vec[vec[float32]] batch_logits) vec[int32]
	apply_penalties(vec[float32] logits, vec[int32] generated_tokens) vec[float32]
	get_type() sampler_type
	validate() bool
}

struct greedy_sampler {
	seed int32
}

func create_greedy_sampler(int32 seed) greedy_sampler* {
	return *greedy_sampler{
		seed: seed,
	}
}

func (g* greedy_sampler) sample(vec[float32] logits) int32 {
	if len(logits) == 0 {
		return 0
	}

	max_idx := 0
	max_val := logits[0]

	for i := 1; i < len(logits); i = i + 1 {
		if logits[i] > max_val {
			max_val = logits[i]
			max_idx = i
		}
	}

	return int32(max_idx)
}

func (g* greedy_sampler) batch_sample(vec[vec[float32]] batch_logits) vec[int32] {
	results := make(vec[int32])

	for i := 0; i < len(batch_logits); i = i + 1 {
		token := g.sample(batch_logits[i])
		results = append(results, token)
	}

	return results
}

func (g* greedy_sampler) apply_penalties(vec[float32] logits, vec[int32] generated_tokens) vec[float32] {
	return logits
}

func (g* greedy_sampler) get_type() sampler_type {
	return sampler_type_greedy
}

func (g* greedy_sampler) validate() bool {
	return true
}

struct top_k_sampler {
	k int32
	seed int32
	temperature float32
}

func create_top_k_sampler(int32 k, float32 temperature, int32 seed) top_k_sampler* {
	if k < 0 {
		k = 0
	}
	if temperature < 0.0 {
		temperature = 1.0
	}

	return *top_k_sampler{
		k: k,
		seed: seed,
		temperature: temperature,
	}
}

func (t* top_k_sampler) sample(vec[float32] logits) int32 {
	if len(logits) == 0 {
		return 0
	}

	k := t.k
	if k <= 0 || k >= int32(len(logits)) {
		max_idx := 0
		max_val := logits[0]
		for i := 1; i < len(logits); i = i + 1 {
			if logits[i] > max_val {
				max_val = logits[i]
				max_idx = i
			}
		}
		return int32(max_idx)
	}

	top_indices := make(vec[int32])
	top_values := make(vec[float32])

	for i := 0; i < len(logits); i = i + 1 {
		val := logits[i]

		inserted := false
		for j := 0; j < len(top_values); j = j + 1 {
			if val > top_values[j] {
				top_values = append(make(vec[float32]), top_values[:j]...)
				top_values = append(top_values, val)
				top_values = append(top_values, top_values[j+1:]...)

				top_indices = append(make(vec[int32]), top_indices[:j]...)
				top_indices = append(top_indices, int32(i))
				top_indices = append(top_indices, top_indices[j+1:]...)

				inserted = true
				break
			}
		}

		if !inserted && len(top_indices) < int32(k) {
			top_values = append(top_values, val)
			top_indices = append(top_indices, int32(i))
		}

		if len(top_indices) > int32(k) {
			top_indices = top_indices[:k]
			top_values = top_values[:k]
		}
	}

	if len(top_indices) > 0 {
		return top_indices[0]
	}

	return 0
}

func (t* top_k_sampler) batch_sample(vec[vec[float32]] batch_logits) vec[int32] {
	results := make(vec[int32])

	for i := 0; i < len(batch_logits); i = i + 1 {
		token := t.sample(batch_logits[i])
		results = append(results, token)
	}

	return results
}

func (t* top_k_sampler) apply_penalties(vec[float32] logits, vec[int32] generated_tokens) vec[float32] {
	return logits
}

func (t* top_k_sampler) get_type() sampler_type {
	return sampler_type_top_k
}

func (t* top_k_sampler) validate() bool {
	if t.k < 0 {
		return false
	}
	if t.temperature < 0.0 {
		return false
	}
	return true
}

struct top_p_sampler {
	p float32
	seed int32
	temperature float32
}

func create_top_p_sampler(float32 p_val, float32 temperature, int32 seed) top_p_sampler* {
	if p_val < 0.0 {
		p_val = 0.0
	}
	if p_val > 1.0 {
		p_val = 1.0
	}
	if temperature < 0.0 {
		temperature = 1.0
	}

	return *top_p_sampler{
		p: p_val,
		seed: seed,
		temperature: temperature,
	}
}

func (t* top_p_sampler) sample(vec[float32] logits) int32 {
	if len(logits) == 0 {
		return 0
	}

	if t.p <= 0.0 || t.p >= 1.0 {
		max_idx := 0
		max_val := logits[0]
		for i := 1; i < len(logits); i = i + 1 {
			if logits[i] > max_val {
				max_val = logits[i]
				max_idx = i
			}
		}
		return int32(max_idx)
	}

	probs := make(vec[float32])
	sum := 0.0

	for i := 0; i < len(logits); i = i + 1 {
		probs = append(probs, logits[i])
		sum = sum + logits[i]
	}

	if sum > 0.0 {
		for i := 0; i < len(probs); i = i + 1 {
			probs[i] = probs[i] / sum
		}
	}

	sorted_indices := make(vec[int32])
	sorted_probs := make(vec[float32])

	for i := 0; i < len(probs); i = i + 1 {
		sorted_indices = append(sorted_indices, int32(i))
		sorted_probs = append(sorted_probs, probs[i])
	}

	for i := 0; i < len(sorted_probs); i = i + 1 {
		max_idx := i
		for j := i + 1; j < len(sorted_probs); j = j + 1 {
			if sorted_probs[j] > sorted_probs[max_idx] {
				max_idx = j
			}
		}

		temp_prob := sorted_probs[i]
		sorted_probs[i] = sorted_probs[max_idx]
		sorted_probs[max_idx] = temp_prob

		temp_idx := sorted_indices[i]
		sorted_indices[i] = sorted_indices[max_idx]
		sorted_indices[max_idx] = temp_idx
	}

	cumsum := 0.0
	for i := 0; i < len(sorted_probs); i = i + 1 {
		cumsum = cumsum + sorted_probs[i]
		if cumsum >= t.p {
			return sorted_indices[i]
		}
	}

	if len(sorted_indices) > 0 {
		return sorted_indices[len(sorted_indices) - 1]
	}

	return 0
}

func (t* top_p_sampler) batch_sample(vec[vec[float32]] batch_logits) vec[int32] {
	results := make(vec[int32])

	for i := 0; i < len(batch_logits); i = i + 1 {
		token := t.sample(batch_logits[i])
		results = append(results, token)
	}

	return results
}

func (t* top_p_sampler) apply_penalties(vec[float32] logits, vec[int32] generated_tokens) vec[float32] {
	return logits
}

func (t* top_p_sampler) get_type() sampler_type {
	return sampler_type_top_p
}

func (t* top_p_sampler) validate() bool {
	if t.p < 0.0 || t.p > 1.0 {
		return false
	}
	if t.temperature < 0.0 {
		return false
	}
	return true
}

struct sampler_factory {
	samplers map[sampler_type]interface{}
}

func create_sampler_factory() sampler_factory* {
	return *sampler_factory{
		samplers: make(map[sampler_type]interface{}),
	}
}

func (f* sampler_factory) register_sampler(sampler_type stype, interface{} sampler) {
	if f.samplers != nil {
		f.samplers[stype] = sampler
	}
}

func (f* sampler_factory) get_sampler(sampler_type stype) interface{} {
	if f.samplers == nil {
		return nil
	}

	sampler, exists := f.samplers[stype]
	if exists {
		return sampler
	}

	return nil
}

func (f* sampler_factory) create_default_samplers() {
	f.register_sampler(sampler_type_greedy, create_greedy_sampler(42))
	f.register_sampler(sampler_type_top_k, create_top_k_sampler(40, 1.0, 42))
	f.register_sampler(sampler_type_top_p, create_top_p_sampler(0.95, 1.0, 42))
}
