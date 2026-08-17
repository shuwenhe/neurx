package neurx.inference.speculative_v2

struct speculative_config {
    string draft_model_path
    int num_speculative_tokens
    float acceptance_threshold
    bool enable_early_exit
    int max_draft_attempts
}

struct draft_model_state {
    int hidden_size
    int vocab_size
    int num_layers
    []float weights
}

struct target_model_state {
    int hidden_size
    int vocab_size
    int num_layers
    []float weights
}

struct speculation_result {
    []int accepted_tokens
    []int rejected_tokens
    int acceptance_rate
    int draft_time_ms
    int verify_time_ms
}

struct speculative_decoder_state {
    speculative_config config
    draft_model_state draft_model
    target_model_state target_model
    int total_draft_tokens
    int total_accepted_tokens
    float cumulative_acceptance_rate
}

func new_speculative_decoder(
    speculative_config config,
    target_model_state target_model) speculative_decoder_state {
    draft_model_state draft_model = draft_model_state {
        hidden_size: target_model.hidden_size / 2,
        vocab_size: target_model.vocab_size,
        num_layers: target_model.num_layers / 2,
        weights: []float{cap: 1000000},
    }
    speculative_decoder_state {
        config: config,
        draft_model: draft_model,
        target_model: target_model,
        total_draft_tokens: 0,
        total_accepted_tokens: 0,
        cumulative_acceptance_rate: 0.0,
    }
}

struct decode_result {
    speculative_decoder_state state
    []int generated_tokens
}

func speculative_decode(
    speculative_decoder_state state,
    []int prompt_tokens,
    int max_new_tokens) decode_result {
    []int all_generated = []int{cap: max_new_tokens}
    []int current_context = []int{cap: len(prompt_tokens)}
    int i = 0
    while i < len(prompt_tokens) {
        current_context.push(prompt_tokens[i])
        i = i + 1
    }
    int generated_count = 0
    while generated_count < max_new_tokens {
        int draft_start_time = get_time_ms()
        []int draft_tokens = draft_model_generate(
            state.draft_model,
            current_context,
            state.config.num_speculative_tokens
        )
        int draft_end_time = get_time_ms()
        int verify_start_time = get_time_ms()
        speculation_result result = verify_draft_tokens(
            state.target_model,
            current_context,
            draft_tokens,
            state.config.acceptance_threshold
        )
        int verify_end_time = get_time_ms()
        result.draft_time_ms = draft_end_time - draft_start_time
        result.verify_time_ms = verify_end_time - verify_start_time
        state.total_draft_tokens = state.total_draft_tokens + len(draft_tokens)
        state.total_accepted_tokens = state.total_accepted_tokens + len(result.accepted_tokens)
        int j = 0
        while j < len(result.accepted_tokens) && generated_count < max_new_tokens {
            all_generated.push(result.accepted_tokens[j])
            current_context.push(result.accepted_tokens[j])
            generated_count = generated_count + 1
            j = j + 1
        }
        if len(result.accepted_tokens) == 0 {
            int fallback_token = target_model_generate_single(
                state.target_model,
                current_context
            )
            all_generated.push(fallback_token)
            current_context.push(fallback_token)
            generated_count = generated_count + 1
        }
        if state.config.enable_early_exit && len(result.accepted_tokens) < 2 {
            break
        }
    }
    if state.total_draft_tokens > 0 {
        state.cumulative_acceptance_rate = float(state.total_accepted_tokens) / float(state.total_draft_tokens)
    }
    return decode_result{state: state, generated_tokens: all_generated}
}

func draft_model_generate(
    draft_model_state model,
    []int context,
    int num_tokens) []int {
    []int draft_tokens = []int{cap: num_tokens}
    []int current_ctx = []int{cap: len(context)}
    int i = 0
    while i < len(context) {
        current_ctx.push(context[i])
        i = i + 1
    }
    int gen_count = 0
    while gen_count < num_tokens {
        []float logits = draft_model_forward(model, current_ctx)
        int next_token = sample_token(logits, 1.0, 0.9, 50)
        draft_tokens.push(next_token)
        current_ctx.push(next_token)
        gen_count = gen_count + 1
    }
    return draft_tokens
}

func verify_draft_tokens(
    target_model_state model,
    []int context,
    []int draft_tokens,
    float acceptance_threshold) speculation_result {
    []int extended_context = []int{cap: len(context) + len(draft_tokens)}
    int i = 0
    while i < len(context) {
        extended_context.push(context[i])
        i = i + 1
    }
    []float all_logits = target_model_forward_sequence(model, extended_context, draft_tokens)
    []int accepted = []int{cap: len(draft_tokens)}
    []int rejected = []int{cap: len(draft_tokens)}
    int draft_idx = 0
    while draft_idx < len(draft_tokens) {
        int draft_token = draft_tokens[draft_idx]
        int logit_offset = draft_idx * model.vocab_size
        float draft_prob = softmax_prob(all_logits, logit_offset, draft_token, model.vocab_size)
        if draft_prob >= acceptance_threshold {
            accepted.push(draft_token)
        } else {
            rejected.push(draft_token)
            break
        }
        draft_idx = draft_idx + 1
    }
    int acceptance_rate = 0
    if len(draft_tokens) > 0 {
        acceptance_rate = (len(accepted) * 100) / len(draft_tokens)
    }
    speculation_result {
        accepted_tokens: accepted,
        rejected_tokens: rejected,
        acceptance_rate: acceptance_rate,
        draft_time_ms: 0,
        verify_time_ms: 0,
    }
}

func draft_model_forward(
    draft_model_state model,
    []int tokens) []float {
    []float logits = []float{cap: model.vocab_size}
    int i = 0
    while i < model.vocab_size {
        float logit_val = float(i) * 0.01
        logits.push(logit_val)
        i = i + 1
    }
    return logits
}

func target_model_forward_sequence(
    target_model_state model,
    []int context,
    []int draft_tokens) []float {
    int total_positions = len(draft_tokens)
    []float all_logits = []float{cap: total_positions * model.vocab_size}
    int pos = 0
    while pos < total_positions {
        int i = 0
        while i < model.vocab_size {
            float logit_val = float(i) * 0.01
            all_logits.push(logit_val)
            i = i + 1
        }
        pos = pos + 1
    }
    return all_logits
}

func target_model_generate_single(
    target_model_state model,
    []int context) int {
    []float logits = []float{cap: model.vocab_size}
    int i = 0
    while i < model.vocab_size {
        logits.push(float(i) * 0.01)
        i = i + 1
    }
    return sample_token(logits, 1.0, 0.9, 50)
}

func softmax_prob(
    []float logits,
    int offset,
    int token_id,
    int vocab_size) float {
    float max_logit = logits[offset]
    int i = offset + 1
    while i < offset + vocab_size {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = offset
    while i < offset + vocab_size {
        sum_exp = sum_exp + exp_approx(logits[i] - max_logit)
        i = i + 1
    }
    float token_prob = exp_approx(logits[offset + token_id] - max_logit) / sum_exp
    return token_prob
}

func sample_token(
    []float logits,
    float temperature,
    float top_p,
    int top_k) int {
    int vocab_size = len(logits)
    float max_logit = logits[0]
    int i = 1
    while i < vocab_size {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    int sampled_token = 0
    float max_score = logits[0]
    i = 1
    while i < vocab_size {
        if logits[i] > max_score {
            max_score = logits[i]
            sampled_token = i
        }
        i = i + 1
    }
    return sampled_token
}

func exp_approx(float x) float {
    if x < -10.0 {
        return 0.0
    }
    if x > 10.0 {
        return 22026.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    return result
}

func get_time_ms() int {
    return 0
}

func speculative_decoder_get_stats(
    speculative_decoder_state state) speculative_stats {
    float speedup = 1.0
    if state.total_draft_tokens > 0 {
        speedup = 1.0 + (float(state.total_accepted_tokens) / float(state.total_draft_tokens)) *
                       (float(state.config.num_speculative_tokens) - 1.0)
    }
    speculative_stats {
        total_draft_tokens: state.total_draft_tokens,
        total_accepted_tokens: state.total_accepted_tokens,
        acceptance_rate: state.cumulative_acceptance_rate,
        speedup_factor: speedup,
    }
}

struct speculative_stats {
    int total_draft_tokens
    int total_accepted_tokens
    float acceptance_rate
    float speedup_factor
}
