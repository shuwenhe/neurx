package v1

type decode_mode string

const (
    mode_auto_regressive    decode_mode = "auto_regressive"
    mode_prefill_only       decode_mode = "prefill_only"
    mode_decode_only        decode_mode = "decode_only"
)

struct generation_context {
    decode_mode mode

    int32 num_tokens_generated
    int32 max_new_tokens

    bool enable_streaming
    bool enable_prefix_caching

    float32 generation_time
    int32 tokens_per_second
}

struct v1_core {
    sampler* sampler_instance
    kv_cache_interface* kv_cache

    generation_context* gen_ctx

    vec[int32] token_buffer

    int32 batch_size
}

func create_v1_core(sampler* sampler_inst, kv_cache_interface* cache) v1_core* {
    return &v1_core{
        sampler_instance: sampler_inst,
        kv_cache: cache,
        gen_ctx: *generation_context{
            mode: mode_auto_regressive,
            num_tokens_generated: 0,
            max_new_tokens: 512,
            enable_streaming: false,
            enable_prefix_caching: true,
            generation_time: 0.0,
            tokens_per_second: 0,
        },
        token_buffer: make(vec[int32]),
        batch_size: 32,
    }
}

func (v1_core* core) prefill(vec[int32] input_ids, vec[float32] logits) bool {
    if len(input_ids) == 0 {
        return false
    }

    core.gen_ctx.mode = mode_prefill_only

    keys := make(vec[float32])
    values := make(vec[float32])

    for i := 0; i < len(logits); i = i + 1 {
        keys = append(keys, logits[i])
        values = append(values, logits[i])
    }

    success := core.kv_cache.put_kv(1, keys, values)
    return success
}

func (v1_core* core) decode(vec[float32] logits, sampling_params* params) int32 {
    core.gen_ctx.mode = mode_decode_only

    if core.gen_ctx.num_tokens_generated >= core.gen_ctx.max_new_tokens {
        return -1
    }

    token := core.sampler_instance.sample_with_params(logits, params)

    core.token_buffer = append(core.token_buffer, token)
    core.gen_ctx.num_tokens_generated = core.gen_ctx.num_tokens_generated + 1

    return token
}

func (v1_core* core) batch_prefill(vec[vec[int32]] batch_input_ids, vec[vec[float32]] batch_logits) bool {
    if len(batch_input_ids) == 0 {
        return false
    }

    for i := 0; i < len(batch_input_ids); i = i + 1 {
        core.prefill(batch_input_ids[i], batch_logits[i])
    }

    return true
}

func (v1_core* core) batch_decode(vec[vec[float32]] batch_logits, sampling_params* params) vec[int32] {
    results := make(vec[int32])

    for i := 0; i < len(batch_logits); i = i + 1 {
        token := core.decode(batch_logits[i], params)
        results = append(results, token)
    }

    return results
}

func (v1_core* core) get_generated_tokens() vec[int32] {
    return core.token_buffer
}

func (v1_core* core) reset_generation() {
    core.token_buffer = make(vec[int32])
    core.gen_ctx.num_tokens_generated = 0
}

func (v1_core* core) set_max_new_tokens(int32 max_tokens) {
    core.gen_ctx.max_new_tokens = max_tokens
}

func (v1_core* core) enable_streaming(bool enabled) {
    core.gen_ctx.enable_streaming = enabled
}

func (v1_core* core) get_generation_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["tokens_generated"] = core.gen_ctx.num_tokens_generated
    stats["max_tokens"] = core.gen_ctx.max_new_tokens
    stats["mode"] = core.gen_ctx.mode
    stats["streaming_enabled"] = core.gen_ctx.enable_streaming
    return stats
}
