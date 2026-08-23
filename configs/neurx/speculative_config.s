package config

type spec_decode_method string

const (
    spec_medusa        spec_decode_method = "medusa"
    spec_eagle         spec_decode_method = "eagle"
    spec_lookahead     spec_decode_method = "lookahead"
    spec_mlp           spec_decode_method = "mlp"
)

struct speculative_config {
    bool enable_speculative_decoding
    spec_decode_method method

    string speculator_model_path
    bool use_builtin_speculator

    int32 num_spec_tokens
    int32 max_spec_tokens
    int32 min_spec_tokens

    float32 spec_topk
    float32 spec_temperature
    float32 acceptance_rate_threshold

    bool enable_adaptive_spec_tokens
    float32 spec_token_adjustment_factor

    bool enable_multi_candidate_verification
    int32 num_candidates

    bool enable_dry_run
    int32 dry_run_samples

    bool enable_rejection_sampling
    float32 rejection_threshold

    map[string]interface{} extra_config
}

func create_default_speculative_config() speculative_config {
    return speculative_config{
        enable_speculative_decoding: false,
        method: spec_medusa,
        speculator_model_path: "",
        use_builtin_speculator: true,
        num_spec_tokens: 5,
        max_spec_tokens: 10,
        min_spec_tokens: 1,
        spec_topk: 50.0,
        spec_temperature: 1.0,
        acceptance_rate_threshold: 0.8,
        enable_adaptive_spec_tokens: true,
        spec_token_adjustment_factor: 1.1,
        enable_multi_candidate_verification: false,
        num_candidates: 3,
        enable_dry_run: false,
        dry_run_samples: 100,
        enable_rejection_sampling: true,
        rejection_threshold: 0.5,
        extra_config: make(map[string]interface{}),
    }
}

func (speculative_config* cfg) validate() bool {
    if cfg.num_spec_tokens <= 0 {
        return false
    }
    if cfg.max_spec_tokens < cfg.num_spec_tokens {
        return false
    }
    if cfg.spec_temperature <= 0.0 {
        return false
    }
    return true
}

func (speculative_config* cfg) is_enabled() bool {
    return cfg.enable_speculative_decoding
}

func (speculative_config* cfg) enable_medusa() {
    cfg.method = spec_medusa
    cfg.enable_speculative_decoding = true
}

func (speculative_config* cfg) enable_eagle() {
    cfg.method = spec_eagle
    cfg.enable_speculative_decoding = true
}

func (speculative_config* cfg) enable_lookahead() {
    cfg.method = spec_lookahead
    cfg.enable_speculative_decoding = true
    cfg.num_spec_tokens = 8
    cfg.max_spec_tokens = 16
}

func (speculative_config* cfg) get_expected_speedup() float32 {
    return float32(cfg.num_spec_tokens) * 1.5
}
