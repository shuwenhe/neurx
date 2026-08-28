package neurx.inference.speculative.registry
func speculative_none() int { 0 }

func speculative_ngram() int { 1 }

func speculative_suffix() int { 2 }

func speculative_draft_model() int { 3 }

func speculative_eagle() int { 4 }

func speculative_mtp() int { 5 }

func speculative_medusa() int { 6 }

func speculative_dflash() int { 7 }

struct speculative_backend_config {
    int backend
    int num_speculative_tokens
    int min_speculative_tokens
    int max_speculative_tokens
    int ngram_min
    int ngram_max
    string draft_model
    bool dynamic_tokens
    bool enabled
}

struct speculative_backend_state {
    speculative_backend_config config
    int proposed_tokens
    int accepted_tokens
    int rejected_tokens
    int current_speculative_tokens
    int consecutive_full_accepts
    int consecutive_rejections
    bool initialized
    string error_message
}

struct speculative_verification_result {
    speculative_backend_state state
    int[] output_tokens
    int accepted_count
    bool used_fallback
}

func speculative_backend_name(int backend) string {
    if backend == speculative_ngram() { return "ngram" }
    if backend == speculative_suffix() { return "suffix" }
    if backend == speculative_draft_model() { return "draft_model" }
    if backend == speculative_eagle() { return "eagle" }
    if backend == speculative_mtp() { return "mtp" }
    if backend == speculative_medusa() { return "medusa" }
    if backend == speculative_dflash() { return "dflash" }
    "none"
}

func speculative_backend_requires_model(int backend) bool {
    backend == speculative_draft_model() || backend == speculative_eagle() || backend == speculative_mtp() || backend == speculative_medusa() || backend == speculative_dflash()
}

func speculative_config_valid(speculative_backend_config config) bool {
    if !config.enabled || config.backend == speculative_none() {
        return true
    }
    if config.backend < speculative_ngram() || config.backend > speculative_dflash() {
        return false
    }
    if config.num_speculative_tokens <= 0 || config.min_speculative_tokens <= 0 || config.max_speculative_tokens < config.min_speculative_tokens {
        return false
    }
    if config.num_speculative_tokens < config.min_speculative_tokens || config.num_speculative_tokens > config.max_speculative_tokens {
        return false
    }
    if config.backend == speculative_ngram() && (config.ngram_min <= 0 || config.ngram_max < config.ngram_min) {
        return false
    }
    if speculative_backend_requires_model(config.backend) && config.draft_model == "" {
        return false
    }
    true
}

func init_speculative_backend(speculative_backend_config config) speculative_backend_state {
    bool initialized = speculative_config_valid(config)
    string error_message = ""
    if !initialized { error_message = "invalid speculative decoding configuration" }
    speculative_backend_state {
        config: config,
        proposed_tokens: 0,
        accepted_tokens: 0,
        rejected_tokens: 0,
        current_speculative_tokens: config.num_speculative_tokens,
        consecutive_full_accepts: 0,
        consecutive_rejections: 0,
        initialized: initialized,
        error_message: error_message,
    }
}

func speculative_copy_prefix(int[] values, int count) int[] {
    int output_count = count
    if output_count < 0 { output_count = 0 }
    if output_count > len(values) { output_count = len(values) }
    int[] output = int[]{cap: output_count}
    int i = 0
    for i < output_count {
        output[i] = values[i]
        i = i + 1
    }
    output
}

func speculative_adapt_width(speculative_backend_state state, int proposed, int accepted) int {
    int width = state.current_speculative_tokens
    if !state.config.dynamic_tokens { return width }
    if proposed > 0 && accepted == proposed {
        width = width + 1
    } else if accepted * 2 < proposed {
        width = width - 1
    }
    if width < state.config.min_speculative_tokens { width = state.config.min_speculative_tokens }
    if width > state.config.max_speculative_tokens { width = state.config.max_speculative_tokens }
    width
}

func verify_speculative_tokens(speculative_backend_state state, int[] proposed, int[] target, int fallback_token) speculative_verification_result {
    if !state.initialized || !state.config.enabled {
        return speculative_verification_result {
            state: state,
            output_tokens: int[]{fallback_token},
            accepted_count: 0,
            used_fallback: true,
        }
    }
    int limit = len(proposed)
    if len(target) < limit { limit = len(target) }
    if state.current_speculative_tokens < limit { limit = state.current_speculative_tokens }
    int accepted = 0
    for accepted < limit && proposed[accepted] == target[accepted] {
        accepted = accepted + 1
    }
    int output_count = accepted + 1
    int[] output = int[]{cap: output_count}
    int i = 0
    for i < accepted {
        output[i] = proposed[i]
        i = i + 1
    }
    if accepted < len(target) {
        output[accepted] = target[accepted]
    } else {
        output[accepted] = fallback_token
    }
    int full_accepts = 0
    int rejections = 0
    if accepted == limit && limit > 0 { full_accepts = state.consecutive_full_accepts + 1 }
    if accepted < limit { rejections = state.consecutive_rejections + 1 }
    speculative_backend_state updated = speculative_backend_state {
        config: state.config,
        proposed_tokens: state.proposed_tokens + limit,
        accepted_tokens: state.accepted_tokens + accepted,
        rejected_tokens: state.rejected_tokens + limit - accepted,
        current_speculative_tokens: speculative_adapt_width(state, limit, accepted),
        consecutive_full_accepts: full_accepts,
        consecutive_rejections: rejections,
        initialized: state.initialized,
        error_message: state.error_message,
    }
    speculative_verification_result {
        state: updated,
        output_tokens: output,
        accepted_count: accepted,
        used_fallback: accepted == 0,
    }
}

func speculative_acceptance_percent(speculative_backend_state state) int {
    if state.proposed_tokens == 0 { return 0 }
    state.accepted_tokens * 100 / state.proposed_tokens
}
