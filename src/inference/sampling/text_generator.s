package neurx.inference
use neurx.inference.sampling_strategies
struct generator_config {
    sampling_config sampling
    int eos_token_id
    int pad_token_id
    bool force_eos
    int min_new_tokens
    int max_new_tokens
    bool return_scores
    bool return_full_text
    int num_return_sequences
    int top_logprobs_count
}

func default_generator_config() generator_config {
    generator_config {
        sampling: neurx.inference.sampling_strategies.new_sampling_config(),
        eos_token_id: 2,
        pad_token_id: 0,
        force_eos: true,
        min_new_tokens: 1,
        max_new_tokens: 256,
        return_scores: false,
        return_full_text: true,
        num_return_sequences: 1,
        top_logprobs_count: 5,
    }
}

struct top_logprob_candidate {
    int token_id
    float logprob
}

struct generation_result {
    []int[] sequences
    []float scores
    []float[] token_logprobs
    [][][]top_logprob_candidate top_logprobs
    []string texts
    bool finished
    float avg_score
}

func min(int a, int b) int {
    if a < b {
        return a
    }
    b
}

func max(int a, int b) int {
    if a > b {
        return a
    }
    b
}

func copy_ids([]int data) []int {
    int n = len(data)
    []int out = make([]int, n)
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func extract_generated_part([]int full_ids, int prompt_length) []int {
    int n = len(full_ids) - prompt_length
    if n <= 0 {
        return []
    }
    []int out = make([]int, n)
    int i = 0
    for i < n {
        out[i] = full_ids[prompt_length + i]
        i = i + 1
    }
    out
}

func has_eos([]int seq, int eos_id) bool {
    int i = 0
    for i < len(seq) {
        if seq[i] == eos_id {
            return true
        }
        i = i + 1
    }
    false
}

func check_all_finished([]int[] sequences, int eos_id) bool {
    if len(sequences) == 0 {
        return false
    }
    int i = 0
    for i < len(sequences) {
        if !has_eos(sequences[i], eos_id) {
            return false
        }
        i = i + 1
    }
    true
}

func append_sequence_score([]float scores, float score) []float {
    scores = append(scores, score)
    scores
}

func append_token_logprob_sequence([]float[] all_logprobs, []float seq_logprobs) []float[] {
    all_logprobs = append(all_logprobs, seq_logprobs)
    all_logprobs
}

func append_top_logprob_sequence([][][]top_logprob_candidate all_top_logprobs, [][]top_logprob_candidate seq_top_logprobs) [][][]top_logprob_candidate {
    all_top_logprobs = append(all_top_logprobs, seq_top_logprobs)
    all_top_logprobs
}

func compute_avg_score([]float scores) float {
    if len(scores) == 0 {
        return 0.0
    }
    float total = 0.0
    int i = 0
    for i < len(scores) {
        total = total + scores[i]
        i = i + 1
    }
    total / float(len(scores))
}

func generator_vocab_size([]int prompt_ids, generator_config cfg) int {
    int vocab = max(cfg.eos_token_id + 4, 16)
    int i = 0
    for i < len(prompt_ids) {
        if prompt_ids[i] + 4 > vocab {
            vocab = prompt_ids[i] + 4
        }
        i = i + 1
    }
    vocab
}

func stub_next_logits(
    []int current_ids,
    generator_config cfg,
    int step,
    int max_steps,
    int vocab_size
) []float {
    if vocab_size <= 0 {
        vocab_size = 16
    }
    []float logits = make([]float, vocab_size)
    int signature = (len(current_ids) + 1) * 97 + step * 31 + max_steps * 11
    int i = 0
    for i < len(current_ids) {
        signature = signature + current_ids[i] * (i + 1)
        i = i + 1
    }
    int slot = signature - (signature / vocab_size) * vocab_size
    if slot < 0 {
        slot = 0 - slot
    }
    int preferred = slot
    int secondary = (preferred + 7 + cfg.top_k) - (((preferred + 7 + cfg.top_k) / vocab_size) * vocab_size)
    int tertiary = (preferred + 13 + step) - (((preferred + 13 + step) / vocab_size) * vocab_size)
    i = 0
    for i < vocab_size {
        logits[i] = -8.0 + float((i + signature) - (((i + signature) / 9) * 9)) * 0.15
        i = i + 1
    }
    logits[preferred] = 12.0 + float(step)
    logits[secondary] = 6.0 + float(len(current_ids))
    logits[tertiary] = 3.0 + float(cfg.top_k) * 0.05
    i = 0
    for i < len(current_ids) {
        int token = current_ids[i]
        int penalized = token - ((token / vocab_size) * vocab_size)
        if penalized < 0 {
            penalized = 0 - penalized
        }
        logits[penalized] = logits[penalized] - 0.5
        i = i + 1
    }
    if step + 1 >= max_steps {
        logits[cfg.eos_token_id] = 15.0
    } else if step + 2 >= max_steps {
        logits[cfg.eos_token_id] = 7.5
    } else if cfg.min_new_tokens > step {
        logits[cfg.eos_token_id] = -15.0
    } else if cfg.min_new_tokens == step {
        logits[cfg.eos_token_id] = -2.0
    }
    logits
}

func take_generation_output([]int prompt_ids, []int generated_ids, bool return_full_text) []int {
    if return_full_text {
        []int full = copy_ids(prompt_ids)
        int i = 0
        for i < len(generated_ids) {
            full = append(full, generated_ids[i])
            i = i + 1
        }
        return full
    }
    copy_ids(generated_ids)
}

func log_softmax([]float logits) []float {
    int n = len(logits)
    if n == 0 {
        return []
    }
    float max_val = logits[0]
    int i = 1
    for i < n {
        if logits[i] > max_val {
            max_val = logits[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < n {
        sum_exp = sum_exp + neurx.inference.sampling_strategies.exp_approx(logits[i] - max_val)
        i = i + 1
    }
    float log_sum_exp = neurx.inference.sampling_strategies.log_approx(sum_exp) + max_val
    []float out = make([]float, n)
    i = 0
    for i < n {
        out[i] = logits[i] - log_sum_exp
        i = i + 1
    }
    out
}

func collect_top_logprobs([]float log_probs, int top_n) []top_logprob_candidate {
    int n = len(log_probs)
    if n == 0 || top_n <= 0 {
        return []
    }
    []int ranked = neurx.inference.sampling_strategies.argsort_descending(log_probs)
    if top_n > n {
        top_n = n
    }
    []top_logprob_candidate out = make([]top_logprob_candidate, top_n)
    int i = 0
    for i < top_n {
        int token_id = ranked[i]
        out.push(top_logprob_candidate {
            token_id: token_id,
            logprob: log_probs[token_id],
        })
        i = i + 1
    }
    out
}

func generate_one_sequence(
    []int prompt_ids,
    generator_config cfg,
    uint64 rng
) ([]int, float, []float, [][]top_logprob_candidate, bool, uint64) {
    int max_steps = min(cfg.max_new_tokens, cfg.sampling.max_length)
    int vocab_size = generator_vocab_size(prompt_ids, cfg)
    []int current_ids = copy_ids(prompt_ids)
    float sequence_score = 0.0
    bool finished = false
    int generated = 0
    if cfg.sampling.strategy == "beam_search" && cfg.sampling.num_beams > 1 {
        []float[] all_logits = floatmake([][], max_steps)
        int step = 0
        for step < max_steps {
            all_logits = append(all_logits, stub_next_logits(current_ids, cfg, step, max_steps, vocab_size))
            step = step + 1
        }
        []int beam_tokens = neurx.inference.sampling_strategies.beam_search_decode(
            all_logits,
            cfg.sampling,
            cfg.eos_token_id
        )
        int i = 0
        for i < len(beam_tokens) {
            current_ids = append(current_ids, beam_tokens[i])
            if beam_tokens[i] == cfg.eos_token_id && i + 1 >= cfg.min_new_tokens {
                finished = true
                break
            }
            i = i + 1
        }
        generated = len(current_ids) - len(prompt_ids)
        if cfg.force_eos && !finished && generated >= max_steps {
            current_ids = append(current_ids, cfg.eos_token_id)
            finished = true
        }
        return (
            take_generation_output(prompt_ids, extract_generated_part(current_ids, len(prompt_ids)), cfg.return_full_text),
            sequence_score,
            [],
            [],
            finished,
            rng
        )
    }
    int step = 0
    []float step_logprobs = make([]float, max_steps)
    [][]top_logprob_candidate step_top_logprobs = []make([]top_logprob_candidate, max_steps)
    for step < max_steps {
        []float raw_logits = stub_next_logits(current_ids, cfg, step, max_steps, vocab_size)
        []int gen_part = extract_generated_part(current_ids, len(prompt_ids))
        []float processed = neurx.inference.sampling_strategies.process_logits(raw_logits, gen_part, cfg.sampling)
        []float log_probs = log_softmax(processed)
        []top_logprob_candidate top_logprobs = collect_top_logprobs(log_probs, cfg.top_logprobs_count)
        int next_token = neurx.inference.sampling_strategies.sample_next_token_index(
            raw_logits,
            gen_part,
            cfg.sampling,
            rng
        )
        rng = neurx.inference.sampling_strategies.advance_rng(rng)
        if next_token < 0 {
            next_token = cfg.eos_token_id
        }
        if next_token < len(processed) {
            sequence_score = sequence_score + processed[next_token]
            step_logprobs = append(step_logprobs, log_probs[next_token])
        }
        step_top_logprobs = append(step_top_logprobs, top_logprobs)
        current_ids = append(current_ids, next_token)
        generated = generated + 1
        if next_token == cfg.eos_token_id && generated >= cfg.min_new_tokens {
            finished = true
            break
        }
        step = step + 1
    }
    if cfg.force_eos && !finished && generated >= max_steps {
        current_ids = append(current_ids, cfg.eos_token_id)
        finished = true
    }
    (
        take_generation_output(prompt_ids, extract_generated_part(current_ids, len(prompt_ids)), cfg.return_full_text),
        sequence_score,
        step_logprobs,
        step_top_logprobs,
        finished,
        rng
    )
}

func generate_one_sequence_with_forward(
    []int prompt_ids,
    func forward_fn,
    generator_config cfg,
    uint64 rng
) ([]int, float, []float, [][]top_logprob_candidate, bool, uint64) {
    int max_steps = min(cfg.max_new_tokens, cfg.sampling.max_length)
    []int current_ids = copy_ids(prompt_ids)
    float sequence_score = 0.0
    bool finished = false
    int generated = 0
    if cfg.sampling.strategy == "beam_search" && cfg.sampling.num_beams > 1 {
        []float[] all_logits = floatmake([][], max_steps)
        int step = 0
        for step < max_steps {
            []float step_logits = forward_fn(current_ids)
            all_logits = append(all_logits, step_logits)
            current_ids = append(current_ids, 0)
            step = step + 1
        }
        current_ids = copy_ids(prompt_ids)
        []int beam_tokens = neurx.inference.sampling_strategies.beam_search_decode(
            all_logits,
            cfg.sampling,
            cfg.eos_token_id
        )
        int i = 0
        for i < len(beam_tokens) {
            current_ids = append(current_ids, beam_tokens[i])
            if beam_tokens[i] == cfg.eos_token_id && i + 1 >= cfg.min_new_tokens {
                finished = true
                break
            }
            i = i + 1
        }
        generated = len(current_ids) - len(prompt_ids)
        if cfg.force_eos && !finished && generated >= max_steps {
            current_ids = append(current_ids, cfg.eos_token_id)
            finished = true
        }
        return (
            take_generation_output(prompt_ids, extract_generated_part(current_ids, len(prompt_ids)), cfg.return_full_text),
            sequence_score,
            [],
            [],
            finished,
            rng
        )
    }
    int step = 0
    []float step_logprobs = make([]float, max_steps)
    [][]top_logprob_candidate step_top_logprobs = []make([]top_logprob_candidate, max_steps)
    for step < max_steps {
        []float raw_logits = forward_fn(current_ids)
        []int gen_part = extract_generated_part(current_ids, len(prompt_ids))
        []float processed = neurx.inference.sampling_strategies.process_logits(raw_logits, gen_part, cfg.sampling)
        []float log_probs = log_softmax(processed)
        []top_logprob_candidate top_logprobs = collect_top_logprobs(log_probs, cfg.top_logprobs_count)
        int next_token = neurx.inference.sampling_strategies.sample_next_token_index(
            raw_logits,
            gen_part,
            cfg.sampling,
            rng
        )
        rng = neurx.inference.sampling_strategies.advance_rng(rng)
        if next_token < 0 {
            next_token = cfg.eos_token_id
        }
        if next_token < len(processed) {
            sequence_score = sequence_score + processed[next_token]
            step_logprobs = append(step_logprobs, log_probs[next_token])
        }
        step_top_logprobs = append(step_top_logprobs, top_logprobs)
        current_ids = append(current_ids, next_token)
        generated = generated + 1
        if next_token == cfg.eos_token_id && generated >= cfg.min_new_tokens {
            finished = true
            break
        }
        step = step + 1
    }
    if cfg.force_eos && !finished && generated >= max_steps {
        current_ids = append(current_ids, cfg.eos_token_id)
        finished = true
    }
    (
        take_generation_output(prompt_ids, extract_generated_part(current_ids, len(prompt_ids)), cfg.return_full_text),
        sequence_score,
        step_logprobs,
        step_top_logprobs,
        finished,
        rng
    )
}

func generate(
    []int prompt_ids,
    generator_config cfg
) generation_result {
    int count = max(1, cfg.num_return_sequences)
    []int[] all_sequences = intmake([][], count)
    []float all_scores = make([]float, count)
    []float[] all_token_logprobs = floatmake([][], count)
    [][][]top_logprob_candidate all_top_logprobs = [][]make([]top_logprob_candidate, count)
    uint64 rng = cfg.sampling.seed
    bool all_finished = true
    int i = 0
    for i < count {
        ([]int seq, float score, []float token_logprobs, [][]top_logprob_candidate top_logprobs, bool finished, uint64 next_rng) = generate_one_sequence(prompt_ids, cfg, rng)
        all_sequences = append(all_sequences, seq)
        if cfg.return_scores {
            all_scores = append_sequence_score(all_scores, score)
        }
        all_token_logprobs = append_token_logprob_sequence(all_token_logprobs, token_logprobs)
        all_top_logprobs = append_top_logprob_sequence(all_top_logprobs, top_logprobs)
        if !finished {
            all_finished = false
        }
        rng = next_rng
        i = i + 1
    }
    []float result_scores = all_scores
    if !cfg.return_scores {
        result_scores = []
    }
    generation_result {
        sequences: all_sequences,
        scores: result_scores,
        token_logprobs: all_token_logprobs,
        top_logprobs: all_top_logprobs,
        texts: [],
        finished: all_finished && check_all_finished(all_sequences, cfg.eos_token_id),
        avg_score: compute_avg_score(all_scores),
    }
}

func generate_with_forward(
    []int prompt_ids,
    func forward_fn,
    generator_config cfg
) generation_result {
    int count = max(1, cfg.num_return_sequences)
    []int[] all_sequences = intmake([][], count)
    []float all_scores = make([]float, count)
    []float[] all_token_logprobs = floatmake([][], count)
    [][][]top_logprob_candidate all_top_logprobs = [][]make([]top_logprob_candidate, count)
    uint64 rng = cfg.sampling.seed
    bool all_finished = true
    int i = 0
    for i < count {
        ([]int seq, float score, []float token_logprobs, [][]top_logprob_candidate top_logprobs, bool finished, uint64 next_rng) = generate_one_sequence_with_forward(
            prompt_ids,
            forward_fn,
            cfg,
            rng
        )
        all_sequences = append(all_sequences, seq)
        if cfg.return_scores {
            all_scores = append_sequence_score(all_scores, score)
        }
        all_token_logprobs = append_token_logprob_sequence(all_token_logprobs, token_logprobs)
        all_top_logprobs = append_top_logprob_sequence(all_top_logprobs, top_logprobs)
        if !finished {
            all_finished = false
        }
        rng = next_rng
        i = i + 1
    }
    []float result_scores = all_scores
    if !cfg.return_scores {
        result_scores = []
    }
    generation_result {
        sequences: all_sequences,
        scores: result_scores,
        token_logprobs: all_token_logprobs,
        top_logprobs: all_top_logprobs,
        texts: [],
        finished: all_finished && check_all_finished(all_sequences, cfg.eos_token_id),
        avg_score: compute_avg_score(all_scores),
    }
}

func generate(
    []int prompt_ids,
    func forward_fn,
    generator_config cfg
) generation_result {
    generate_with_forward(prompt_ids, forward_fn, cfg)
}
