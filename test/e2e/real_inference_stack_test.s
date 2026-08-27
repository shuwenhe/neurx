package neurx.tests.real_inference_stack_test
use neurx.inference.real_transformer_layer.{
    transformer_layer_config,
    transformer_layer_weights,
    default_layer_config,
    make_identity_weights,
    transformer_layer_forward,
    rms_norm,
    matmul_vec,
    apply_rope,
    silu,
    moe_route,
    moe_routing_result,
    sqrt_approx,
}
use neurx.tokenizer.real_bpe_tokenizer.{
    real_bpe_tokenizer,
    new_real_bpe_tokenizer,
    encode,
    decode,
}
use neurx.inference.engine.generation_engine_adapter.{
    generation_engine,
    new_generation_engine,
    generate,
    generate_stream,
    decode_ids,
}
use neurx.attention.paged_attention_core.{
    paged_kv_cache,
    paged_attention_config,
    slot_mapping,
    new_paged_kv_cache,
    reserve_tokens,
}

func approx(float a, float b, float tol) bool {
    float d = a - b
    if d < 0.0 { d = 0.0 - d }
    d < tol
}

func expect(bool cond, string name) int {
    if cond {
        println("PASS " + name)
        return 0
    }
    println("FAIL " + name)
    1
}

func test_rms_norm_unit_vector() int {
    int n = 8
    float[] x = make(float[], n)
    float[] w = make(float[], n)
    int i = 0
    for i < n {
        x[i] = 1.0
        w[i] = 1.0
        i = i + 1
    }
    float[] out = rms_norm(x, w, n, 1.0e-6)
    int fail = 0
    fail = fail + expect(approx(out[0], 1.0, 1.0e-3), "rms_norm of ones vector is ~1")
    fail = fail + expect(approx(out[3], 1.0, 1.0e-3), "rms_norm element 3 ~1")
    fail
}

func test_matmul_identity() int {
    int in_dim = 4
    int out_dim = 4
    float[] x = make(float[], in_dim)
    x[0] = 2.0
    x[1] = 3.0
    float[] w = make(float[], out_dim * in_dim)
    int i = 0
    for i < out_dim && i < in_dim {
        w[i * in_dim + i] = 1.0
        i = i + 1
    }
    float[] out = matmul_vec(x, w, in_dim, out_dim)
    int fail = 0
    fail = fail + expect(approx(out[0], 2.0, 1.0e-6), "matmul identity out[0]=2")
    fail = fail + expect(approx(out[1], 3.0, 1.0e-6), "matmul identity out[1]=3")
    fail
}

func test_rope_rotation() int {
    int num_heads = 1
    int head_size = 4
    float[] q = make(float[], num_heads * head_size)
    q[0] = 1.0
    q[1] = 0.0
    q[2] = 1.0
    q[3] = 0.0
    float[] out = apply_rope(q, num_heads, head_size, 1, 10000.0)
    int fail = 0
    fail = fail + expect(approx(out[0], 1.0, 0.1), "rope at position 1 keeps magnitude for dim 0")
    fail = fail + expect(len(out) == len(q), "rope output length matches input")
    fail
}

func test_silu_zero_and_one() int {
    int fail = 0
    fail = fail + expect(approx(silu(0.0), 0.0, 1.0e-6), "silu(0)=0")
    fail = fail + expect(silu(10.0) > 9.0, "silu(10) ~ 10")
    fail = fail + expect(silu(-10.0) > -0.01 && silu(-10.0) < 0.0, "silu(-10) ~ 0 negative")
    fail
}

func test_moe_route_top_k() int {
    int hidden = 4
    int num_experts = 4
    int top_k = 2
    float[] hidden_vec = make(float[], hidden)
    hidden_0[] = 1.0
    hidden_1[] = 2.0
    float[] gate_w = make(float[], num_experts * hidden)
    gate_w[1 * hidden + 0] = 1.0
    gate_w[1 * hidden + 1] = 1.0
    gate_w[3 * hidden + 0] = 0.5
    gate_w[3 * hidden + 1] = 0.5
    moe_routing_result route = moe_route(hidden_vec, gate_w, hidden, num_experts, top_k)
    int fail = 0
    fail = fail + expect(route.num_selected == top_k, "moe selected exactly top_k experts")
    fail = fail + expect(route.selected_experts[0] == 1, "moe top expert is 1")
    fail = fail + expect(approx(route.weights[0] + route.weights[1], 1.0, 1.0e-4), "moe weights sum to 1")
    fail
}

func test_transformer_layer_forward_runs() int {
    transformer_layer_config cfg = default_layer_config()
    transformer_layer_weights w = make_identity_weights(cfg)
    paged_kv_cache cache = new_paged_kv_cache(paged_attention_config{block_size: cfg.block_size, num_kv_heads: cfg.num_kv_heads, head_size: cfg.head_size, max_blocks: cfg.max_blocks, scale: 1.0})
    cache = reserve_tokens(cache, 4)
    []slot_mapping slots = cache.token_to_slot
    float[] hidden = make(float[], cfg.hidden_size)
    hidden[0] = 1.0
    (float[] out, paged_kv_cache c) = transformer_layer_forward(hidden, w, cfg, cache, slots, 0)
    int fail = 0
    fail = fail + expect(len(out) == cfg.hidden_size, "layer forward output length matches hidden_size")
    fail = fail + expect(approx(out[0], 1.0, 0.5), "layer forward output[0] near input due to identity weights + residual")
    fail
}

func test_tokenizer_encode_decode_roundtrip() int {
    real_bpe_tokenizer tok = new_real_bpe_tokenizer()
    int[] ids = encode(tok, "hello world")
    string decoded = decode(tok, ids)
    int fail = 0
    fail = fail + expect(len(ids) > 0, "encode returns non-empty ids")
    fail = fail + expect(ids[0] == tok.bos_id, "first id is bos")
    fail = fail + expect(string_contains(decoded, "hello"), "decoded contains hello")
    fail = fail + expect(string_contains(decoded, "world"), "decoded contains world")
    fail
}

func test_tokenizer_byte_fallback() int {
    real_bpe_tokenizer tok = new_real_bpe_tokenizer()
    int[] ids = encode(tok, "#@")
    string decoded = decode(tok, ids)
    int fail = 0
    fail = fail + expect(len(ids) > 0, "byte fallback encode returns ids")
    fail = fail + expect(string_contains(decoded, "#"), "decoded contains # via byte fallback")
    fail = fail + expect(string_contains(decoded, "@"), "decoded contains @ via byte fallback")
    fail
}

func test_generation_engine_end_to_end() int {
    generation_engine engine = new_generation_engine(2)
    generation_result result = generate(engine, "hello", 4)
    int fail = 0
    fail = fail + expect(result.num_generated > 0, "engine generates at least one token")
    fail = fail + expect(len(result.token_ids) == result.num_generated, "token_ids length matches num_generated")
    fail = fail + expect(len(result.token_strings) == result.num_generated, "token_strings length matches num_generated")
    int[] all_ids = encode(engine.tokenizer, "hello")
    int i = 0
    for i < result.num_generated {
        all_ids = append(all_ids, result.token_ids[i])
        i = i + 1
    }
    string full = decode_ids(engine, all_ids)
    fail = fail + expect(string_contains(full, "hello"), "end-to-end decode contains prompt")
    fail
}

func test_generation_engine_callback_state() int {
    generation_engine engine = new_generation_engine(1)
    generation_callback_state state = generate_stream(engine, "hi", 3)
    int fail = 0
    fail = fail + expect(len(state.tokens) > 0, "callback state has tokens")
    fail = fail + expect(state.cursor == 0, "callback cursor starts at 0")
    fail = fail + expect(!state.done, "callback state not done initially")
    fail
}

func string_contains(string text, string pattern) bool {
    int i = 0
    for i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
            if text[i + j] != pattern[j] {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            return true
        }
        i = i + 1
    }
    false
}

func main() {
    int fail = 0
    fail = fail + test_rms_norm_unit_vector()
    fail = fail + test_matmul_identity()
    fail = fail + test_rope_rotation()
    fail = fail + test_silu_zero_and_one()
    fail = fail + test_moe_route_top_k()
    fail = fail + test_transformer_layer_forward_runs()
    fail = fail + test_tokenizer_encode_decode_roundtrip()
    fail = fail + test_tokenizer_byte_fallback()
    fail = fail + test_generation_engine_end_to_end()
    fail = fail + test_generation_engine_callback_state()
    if fail == 0 {
        println("PASS real inference stack")
        return 0
    }
    println("FAIL real inference stack")
    1
}
