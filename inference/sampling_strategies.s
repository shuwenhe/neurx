package neurx.inference.sampling_strategies
struct sampling_config {
    string strategy
    float temperature
    int top_k
    float top_p
    float typical_p
    int contrastive_top_k
    float penalty_alpha
    float repetition_penalty
    float presence_penalty
    float frequency_penalty
    bool greedy
    int num_beams
    float length_penalty
    bool early_stopping
    int no_repeat_ngram_size
    int min_length
    int max_length
    bool do_sample
    uint64 seed
}
struct beam_state {
    []int token_ids
    float score
    bool is_finished
}
struct generation_state {
    []int input_ids
    []int generated_ids
    int current_step
    bool is_finished
    []beam_state beams
}
func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    return out
}
func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    return out
}
func make_one_hot(int idx, int size) []float {
    []float out = []float{cap: size}
    int i = 0
    while i < size {
        out[i] = 0.0
        i = i + 1
    }
    if idx >= 0 && idx < size {
        out[idx] = 1.0
    }
    return out
}
func advance_rng(uint64 state) uint64 {
    state = state xor (state << 13)
    state = state xor (state >> 7)
    state = state xor (state << 17)
    return state
}
func random_float_01(uint64 rng) float {
    float(advance_rng(rng)) / 18446744073709551615.0
}
func exp_approx(float x) float {
    if x < -18.0 {
        return 0.0
    }
    if x > 18.0 {
        x = 18.0
    }
    float term = 1.0
    float sum = 1.0
    int i = 1
    while i < 10 {
        term = term * x / i
        sum = sum + term
        i = i + 1
    }
    sum
}
func log_approx(float x) float {
    float v = x
    if v <= 0.0 {
        v = 0.000000000001
    }
    float y = (v - 1.0) / (v + 1.0)
    float y2 = y * y
    float y3 = y2 * y
    float y5 = y3 * y2
    float y7 = y5 * y2
    2.0 * (y + (y3 / 3.0) + (y5 / 5.0) + (y7 / 7.0))
}
func abs_float(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    x
}
func softmax([]float logits) []float {
    int n = len(logits)
    if n == 0 {
        return []
    }
    float max_val = logits[0]
    int i = 1
    while i < n {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    []float probs = []float{cap: n}
    float sum_exp = 0.0
    i = 0
    while i < n {
        float val = exp_approx(logits[i] - max_val)
        probs[i] = val
        sum_exp = sum_exp + val
        i = i + 1
    }
    if sum_exp <= 0.0 {
        float uniform = 1.0 / n
        i = 0
        while i < n {
            probs[i] = uniform
            i = i + 1
        }
        return probs
    }
    i = 0
    while i < n {
        probs[i] = probs[i] / sum_exp
        i = i + 1
    }
    probs
}
func normalize([]float arr) []float {
    int n = len(arr)
    if n == 0 {
        return []
    }
    float sum = 0.0
    int i = 0
    while i < n {
        sum = sum + arr[i]
        i = i + 1
    }
    []float out = []float{cap: n}
    if sum <= 0.0 {
        float uniform = 1.0 / n
        i = 0
        while i < n {
            out[i] = uniform
            i = i + 1
        }
        return out
    }
    i = 0
    while i < n {
        out[i] = arr[i] / sum
        i = i + 1
    }
    out
}
func argmax([]float arr) int {
    int n = len(arr)
    if n == 0 {
        return -1
    }
    int best_idx = 0
    float best_val = arr[0]
    int i = 1
    while i < n {
        if arr[i] > best_val {
            best_idx = i
            best_val = arr[i]
        }
        i = i + 1
    }
    best_idx
}
func argsort_descending([]float arr) []int {
    int n = len(arr)
    []int indices = []int{cap: n}
    int i = 0
    while i < n {
        indices[i] = i
        i = i + 1
    }
    i = 0
    while i < n {
        int best = i
        int j = i + 1
        while j < n {
            if arr[indices[j]] > arr[indices[best]] {
                best = j
            }
            j = j + 1
        }
        if best != i {
            int tmp = indices[i]
            indices[i] = indices[best]
            indices[best] = tmp
        }
        i = i + 1
    }
    indices
}
func argsort_ascending([]float arr) []int {
    int n = len(arr)
    []int indices = []int{cap: n}
    int i = 0
    while i < n {
        indices[i] = i
        i = i + 1
    }
    i = 0
    while i < n {
        int best = i
        int j = i + 1
        while j < n {
            if arr[indices[j]] < arr[indices[best]] {
                best = j
            }
            j = j + 1
        }
        if best != i {
            int tmp = indices[i]
            indices[i] = indices[best]
            indices[best] = tmp
        }
        i = i + 1
    }
    indices
}
func new_sampling_config() sampling_config {
    sampling_config {
        strategy: "top_p",
        temperature: 1.0,
        top_k: 50,
        top_p: 0.9,
        typical_p: 1.0,
        contrastive_top_k: 4,
        penalty_alpha: 0.6,
        repetition_penalty: 1.0,
        presence_penalty: 0.0,
        frequency_penalty: 0.0,
        greedy: false,
        num_beams: 1,
        length_penalty: 1.0,
        early_stopping: true,
        no_repeat_ngram_size: 0,
        min_length: 0,
        max_length: 512,
        do_sample: true,
        seed: 42,
    }
}
func greedy_config() sampling_config {
    sampling_config {
        strategy: "greedy",
        temperature: 1.0,
        top_k: 0,
        top_p: 0.0,
        typical_p: 1.0,
        contrastive_top_k: 1,
        penalty_alpha: 0.0,
        repetition_penalty: 1.0,
        presence_penalty: 0.0,
        frequency_penalty: 0.0,
        greedy: true,
        num_beams: 1,
        length_penalty: 1.0,
        early_stopping: true,
        no_repeat_ngram_size: 0,
        min_length: 0,
        max_length: 512,
        do_sample: false,
        seed: 42,
    }
}
func creative_config() sampling_config {
    sampling_config {
        strategy: "top_p",
        temperature: 0.9,
        top_k: 40,
        top_p: 0.92,
        typical_p: 1.0,
        contrastive_top_k: 4,
        penalty_alpha: 0.6,
        repetition_penalty: 1.15,
        presence_penalty: 0.0,
        frequency_penalty: 0.0,
        greedy: false,
        num_beams: 1,
        length_penalty: 1.0,
        early_stopping: true,
        no_repeat_ngram_size: 0,
        min_length: 0,
        max_length: 1024,
        do_sample: true,
        seed: 42,
    }
}
func apply_temperature([]float logits, float temperature) []float {
    int n = len(logits)
    if n == 0 {
        return []
    }
    if temperature <= 0.0 {
        return make_one_hot(argmax(logits), n)
    }
    if temperature == 1.0 {
        return copy_float(logits)
    }
    []float out = []float{cap: n}
    float inv = 1.0 / temperature
    int i = 0
    while i < n {
        out[i] = logits[i] * inv
        i = i + 1
    }
    out
}
func apply_repetition_penalty([]float logits, []int past_tokens, float penalty) []float {
    int n = len(logits)
    if penalty == 1.0 || n == 0 || len(past_tokens) == 0 {
        return copy_float(logits)
    }
    []float out = copy_float(logits)
    int i = 0
    while i < len(past_tokens) {
        int token = past_tokens[i]
        if token >= 0 && token < n {
            if out[token] > 0.0 {
                out[token] = out[token] / penalty
            } else {
                out[token] = out[token] * penalty
            }
        }
        i = i + 1
    }
    out
}
func apply_presence_frequency_penalties(
    []float logits,
    []int past_tokens,
    float presence_penalty,
    float frequency_penalty
) []float {
    int n = len(logits)
    if n == 0 || (presence_penalty == 0.0 && frequency_penalty == 0.0) || len(past_tokens) == 0 {
        return copy_float(logits)
    }
    []float out = copy_float(logits)
    []int counts = []int{cap: n}
    int i = 0
    while i < n {
        counts[i] = 0
        i = i + 1
    }
    i = 0
    while i < len(past_tokens) {
        int token = past_tokens[i]
        if token >= 0 && token < n {
            counts[token] = counts[token] + 1
        }
        i = i + 1
    }
    i = 0
    while i < n {
        if counts[i] > 0 {
            if presence_penalty != 0.0 {
                out[i] = out[i] - presence_penalty
            }
            if frequency_penalty != 0.0 {
                out[i] = out[i] - float(counts[i]) * frequency_penalty
            }
        }
        i = i + 1
    }
    out
}
func get_blocked_tokens([]int past_tokens, int ngram_size, int vocab_size) []int {
    if ngram_size <= 1 || len(past_tokens) < ngram_size - 1 {
        return []
    }
    int prefix_len = ngram_size - 1
    int recent_start = len(past_tokens) - prefix_len
    []int blocked = []int{cap: vocab_size}
    int i = 0
    while i < vocab_size {
        blocked[i] = 0
        i = i + 1
    }
    int pos = 0
    int stop = len(past_tokens) - ngram_size
    while pos <= stop {
        bool match = true
        int j = 0
        while j < prefix_len {
            if past_tokens[pos + j] != past_tokens[recent_start + j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            int blocked_token = past_tokens[pos + prefix_len]
            if blocked_token >= 0 && blocked_token < vocab_size {
                blocked[blocked_token] = 1
            }
        }
        pos = pos + 1
    }
    []int out = []int{cap: vocab_size}
    i = 0
    while i < vocab_size {
        if blocked[i] == 1 {
            out.push(i)
        }
        i = i + 1
    }
    out
}
func apply_ngram_blocking([]float logits, []int past_tokens, int ngram_size) []float {
    int n = len(logits)
    if n == 0 || ngram_size <= 1 {
        return copy_float(logits)
    }
    []int blocked = get_blocked_tokens(past_tokens, ngram_size, n)
    if len(blocked) == 0 {
        return copy_float(logits)
    }
    []float out = copy_float(logits)
    int i = 0
    while i < len(blocked) {
        int token = blocked[i]
        if token >= 0 && token < n {
            out[token] = -10000000000.0
        }
        i = i + 1
    }
    out
}
func apply_top_k([]float logits, int k) []float {
    int n = len(logits)
    if n == 0 || k <= 0 || k >= n {
        return copy_float(logits)
    }
    []float probs = softmax(logits)
    []int sorted = argsort_descending(probs)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = -10000000000.0
        i = i + 1
    }
    i = 0
    while i < k {
        int token = sorted[i]
        out[token] = logits[token]
        i = i + 1
    }
    out
}
func apply_top_p([]float logits, float p) []float {
    int n = len(logits)
    if n == 0 || p <= 0.0 || p >= 1.0 {
        return copy_float(logits)
    }
    []float probs = softmax(logits)
    []int sorted = argsort_descending(probs)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = -10000000000.0
        i = i + 1
    }
    float cumsum = 0.0
    i = 0
    while i < n {
        int token = sorted[i]
        cumsum = cumsum + probs[token]
        out[token] = logits[token]
        if i > 0 && cumsum >= p {
            break
        }
        i = i + 1
    }
    out
}
func apply_typical_p([]float logits, float p) []float {
    int n = len(logits)
    if n == 0 || p <= 0.0 || p >= 1.0 {
        return copy_float(logits)
    }
    []float probs = softmax(logits)
    float entropy = 0.0
    int i = 0
    while i < n {
        if probs[i] > 0.0 {
            entropy = entropy - probs[i] * log_approx(probs[i])
        }
        i = i + 1
    }
    []float deviations = []float{cap: n}
    i = 0
    while i < n {
        deviations[i] = abs_float((0.0 - log_approx(probs[i])) - entropy)
        i = i + 1
    }
    []int sorted = argsort_ascending(deviations)
    []float out = []float{cap: n}
    i = 0
    while i < n {
        out[i] = -10000000000.0
        i = i + 1
    }
    float cumsum = 0.0
    i = 0
    while i < n {
        int token = sorted[i]
        cumsum = cumsum + probs[token]
        out[token] = logits[token]
        if i > 0 && cumsum >= p {
            break
        }
        i = i + 1
    }
    out
}
func contrastive_candidate_penalty(int token, []int past_tokens) float {
    if len(past_tokens) == 0 {
        return 0.0
    }
    float penalty = 0.0
    int i = 0
    while i < len(past_tokens) {
        if past_tokens[i] == token {
            penalty = penalty + 1.0
            if i == len(past_tokens) - 1 {
                penalty = penalty + 1.0
            }
        }
        i = i + 1
    }
    penalty
}
func contrastive_search_token([]float logits, []int past_tokens, sampling_config config) int {
    int n = len(logits)
    if n == 0 {
        return -1
    }
    []float processed = process_logits(logits, past_tokens, config)
    []int ranked = argsort_descending(processed)
    int k = config.contrastive_top_k
    if k <= 0 {
        k = 4
    }
    if k > len(ranked) {
        k = len(ranked)
    }
    int best_token = ranked[0]
    float best_score = processed[best_token]
    int i = 0
    while i < k {
        int token = ranked[i]
        float penalty = contrastive_candidate_penalty(token, past_tokens)
        float score = (1.0 - config.penalty_alpha) * processed[token] - config.penalty_alpha * penalty
        if i == 0 || score > best_score {
            best_token = token
            best_score = score
        }
        i = i + 1
    }
    best_token
}
func process_logits([]float logits, []int past_tokens, sampling_config config) []float {
    []float out = copy_float(logits)
    if config.no_repeat_ngram_size > 1 {
        out = apply_ngram_blocking(out, past_tokens, config.no_repeat_ngram_size)
    }
    if config.presence_penalty != 0.0 || config.frequency_penalty != 0.0 {
        out = apply_presence_frequency_penalties(
            out,
            past_tokens,
            config.presence_penalty,
            config.frequency_penalty
        )
    }
    if config.repetition_penalty != 1.0 {
        out = apply_repetition_penalty(out, past_tokens, config.repetition_penalty)
    }
    out = apply_temperature(out, config.temperature)
    if config.top_k > 0 {
        out = apply_top_k(out, config.top_k)
    }
    if config.top_p > 0.0 && config.top_p < 1.0 {
        out = apply_top_p(out, config.top_p)
    }
    if config.typical_p > 0.0 && config.typical_p < 1.0 {
        out = apply_typical_p(out, config.typical_p)
    }
    out
}
func sample_from_distribution([]float probs, uint64 rng_state) (int, uint64) {
    int n = len(probs)
    if n == 0 {
        return (-1, advance_rng(rng_state))
    }
    float r = random_float_01(rng_state)
    float cumsum = 0.0
    int i = 0
    while i < n {
        cumsum = cumsum + probs[i]
        if r < cumsum {
            return (i, advance_rng(rng_state))
        }
        i = i + 1
    }
    (n - 1, advance_rng(rng_state))
}
func sample_from_distribution_index([]float probs, uint64 rng_state) int {
    int n = len(probs)
    if n == 0 {
        return -1
    }
    float r = random_float_01(rng_state)
    float cumsum = 0.0
    int i = 0
    while i < n {
        cumsum = cumsum + probs[i]
        if r < cumsum {
            return i
        }
        i = i + 1
    }
    n - 1
}
func sample_from_softmax([]float logits, float temperature, uint64 rng_state) (int, uint64) {
    []float scaled = apply_temperature(logits, temperature)
    []float probs = softmax(scaled)
    sample_from_distribution(probs, rng_state)
}
func sample_from_softmax_index([]float logits, float temperature, uint64 rng_state) int {
    []float scaled = apply_temperature(logits, temperature)
    []float probs = softmax(scaled)
    sample_from_distribution_index(probs, rng_state)
}
func greedy_sample([]float logits) int {
    argmax(logits)
}
func sample_next_token(
    []float logits,
    []int past_tokens,
    sampling_config config,
    uint64 rng_state
) (int, uint64) {
    if config.greedy || !config.do_sample || config.strategy == "greedy" || config.temperature <= 0.0 {
        return (greedy_sample(logits), advance_rng(rng_state))
    }
    if config.strategy == "contrastive" {
        return (contrastive_search_token(logits, past_tokens, config), advance_rng(rng_state))
    }
    []float processed = process_logits(logits, past_tokens, config)
    []float probs = softmax(processed)
    sample_from_distribution(probs, rng_state)
}
func sample_next_token_index(
    []float logits,
    []int past_tokens,
    sampling_config config,
    uint64 rng_state
) int {
    if config.greedy || !config.do_sample || config.strategy == "greedy" || config.temperature <= 0.0 {
        return greedy_sample(logits)
    }
    if config.strategy == "contrastive" {
        return contrastive_search_token(logits, past_tokens, config)
    }
    []float processed = process_logits(logits, past_tokens, config)
    []float probs = softmax(processed)
    sample_from_distribution_index(probs, rng_state)
}
func sample_token(
    []float logits,
    []int past_tokens,
    sampling_config config,
    uint64 rng_state
) int {
    return sample_next_token_index(logits, past_tokens, config, rng_state)
}
func select_top_beams([]beam_state candidates, int k) []beam_state {
    int n = len(candidates)
    if n == 0 {
        return []
    }
    if k <= 0 || n <= k {
        return candidates
    }
    int i = 0
    while i < k {
        int best = i
        int j = i + 1
        while j < n {
            if candidates[j].score > candidates[best].score {
                best = j
            }
            j = j + 1
        }
        if best != i {
            beam_state tmp = candidates[i]
            candidates[i] = candidates[best]
            candidates[best] = tmp
        }
        i = i + 1
    }
    []beam_state out = []beam_state{cap: k}
    i = 0
    while i < k {
        out.push(candidates[i])
        i = i + 1
    }
    out
}
func best_beam([]beam_state beams) beam_state {
    if len(beams) == 0 {
        return beam_state {
            token_ids: [],
            score: -10000000000.0,
            is_finished: true,
        }
    }
    int best = 0
    float best_score = beams[0].score
    int i = 1
    while i < len(beams) {
        if beams[i].score > best_score {
            best = i
            best_score = beams[i].score
        }
        i = i + 1
    }
    beams[best]
}
func beam_search_decode(
    [][]float all_logits,
    sampling_config config,
    int eos_token_id
) []int {
    int num_beams = config.num_beams
    if num_beams <= 1 {
        []int greedy = []
        int step = 0
        int max_steps = len(all_logits)
        if config.max_length > 0 && config.max_length < max_steps {
            max_steps = config.max_length
        }
        while step < max_steps {
            []float logits = copy_float(all_logits[step])
            logits = process_logits(logits, greedy, config)
            int token = greedy_sample(logits)
            if token == eos_token_id && len(greedy) >= config.min_length {
                break
            }
            greedy.push(token)
            step = step + 1
        }
        return greedy
    }
    []beam_state beams = []beam_state{cap: num_beams}
    beams.push(beam_state {
        token_ids: [],
        score: 0.0,
        is_finished: false,
    })
    []beam_state finished = []beam_state{cap: num_beams}
    int step = 0
    int max_steps = len(all_logits)
    if config.max_length > 0 && config.max_length < max_steps {
        max_steps = config.max_length
    }
    while step < max_steps {
        if len(beams) == 0 {
            break
        }
        []beam_state candidates = []beam_state{cap: num_beams * len(beams)}
        int b = 0
        while b < len(beams) {
            beam_state beam = beams[b]
            if beam.is_finished {
                candidates.push(beam)
            } else {
                []float logits = copy_float(all_logits[step])
                logits = process_logits(logits, beam.token_ids, config)
                []int ranked = argsort_descending(logits)
                int expand = num_beams
                if expand > len(ranked) {
                    expand = len(ranked)
                }
                int i = 0
                while i < expand {
                    int token = ranked[i]
                    []int new_tokens = copy_int(beam.token_ids)
                    new_tokens.push(token)
                    bool is_finished = token == eos_token_id && len(new_tokens) >= config.min_length
                    candidates.push(beam_state {
                        token_ids: new_tokens,
                        score: beam.score + logits[token],
                        is_finished: is_finished,
                    })
                    i = i + 1
                }
            }
            b = b + 1
        }
        if len(candidates) == 0 {
            break
        }
        []beam_state selected = select_top_beams(candidates, num_beams)
        beams = []beam_state{cap: num_beams}
        int i = 0
        while i < len(selected) {
            if selected[i].is_finished {
                finished.push(selected[i])
            } else if len(beams) < num_beams {
                beams.push(selected[i])
            }
            i = i + 1
        }
        if config.early_stopping && len(finished) >= num_beams {
            break
        }
        step = step + 1
    }
    int i = 0
    while i < len(beams) {
        finished.push(beams[i])
        i = i + 1
    }
    if len(finished) == 0 {
        return []
    }
    best_beam(finished).token_ids
}
func beam_search_decode_two_steps(
    []float first_logits,
    []float second_logits,
    sampling_config config,
    int eos_token_id
) []int {
    [][]float all_logits = [][]float{cap: 2}
    all_logits.push(first_logits)
    all_logits.push(second_logits)
    beam_search_decode(all_logits, config, eos_token_id)
}
