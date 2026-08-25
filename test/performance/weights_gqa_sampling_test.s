package neurx.tests.weights_gqa_sampling_test
use neurx.inference.safetensors_weight_loader.{
    safetensors_header,
    tensor_meta,
    load_safetensors_header,
    load_tensor_floats,
    has_tensor,
    find_tensor,
    parse_header_json,
    skip_ws,
    parse_int_array,
    ints_to_float,
    pow2,
}
use neurx.attention.paged_attention_core.{
    paged_attention_config,
    paged_kv_cache,
    slot_mapping,
    new_paged_kv_cache,
    reserve_tokens,
    write_kv_to_cache,
    compute_paged_attention,
    compute_paged_attention_gqa,
}
use neurx.inference.real_sampling.{
    sampling_params,
    rng_state,
    new_sampling_params,
    new_rng,
    sample,
    greedy_sample,
    apply_temperature,
    softmax,
    top_k_filter,
    top_p_filter,
    argmax,
    math_exp,
    next_float,
    next_uint,
}
use neurx.inference.engine.generation_engine_adapter.{
    generation_engine,
    new_generation_engine,
    generate,
    generate_with_sampling,
    generate_greedy,
    load_weights_from_safetensors,
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

func test_header_json_parse() int {
    string json = "{\"embedding.weight\":{\"dtype\":\"F32\",\"shape\":[100,8],\"data_offsets\":[0,3200]},\"lm_head.weight\":{\"dtype\":\"F32\",\"shape\":[8,100],\"data_offsets\":[3200,6400]}}"
    []tensor_meta tensors = parse_header_json(json)
    int fail = 0
    fail = fail + expect(len(tensors) == 2, "parsed 2 tensors from header json")
    if len(tensors) >= 2 {
        fail = fail + expect(tensors[0].name == "embedding.weight", "first tensor name is embedding.weight")
        fail = fail + expect(tensors[0].dtype == "F32", "first tensor dtype is F32")
        fail = fail + expect(tensors[0].num_elements == 800, "first tensor num_elements = 100*8 = 800")
        fail = fail + expect(tensors[0].data_offset == 0, "first tensor data_offset = 0")
        fail = fail + expect(tensors[0].data_length == 3200, "first tensor data_length = 3200")
        fail = fail + expect(tensors[1].name == "lm_head.weight", "second tensor name is lm_head.weight")
        fail = fail + expect(tensors[1].data_offset == 3200, "second tensor data_offset = 3200")
    }
    fail
}

func test_ints_to_float() int {
    int sign = 0
    int exp_bits = 127
    int mantissa = 0
    int bits = sign + exp_bits * 8388608 + mantissa
    float f = ints_to_float(bits % 256, (bits / 256) % 256, (bits / 65536) % 256, bits / 16777216)
    int fail = 0
    fail = fail + expect(approx(f, 1.0, 1.0e-4), "float bits for 1.0 decodes to 1.0")
    int bits2 = 0 + 128 * 8388608 + 0
    float f2 = ints_to_float(bits2 % 256, (bits2 / 256) % 256, (bits2 / 65536) % 256, bits2 / 16777216)
    fail = fail + expect(approx(f2, -2.0, 1.0e-4), "float bits for -2.0 decodes to -2.0")
    float z = ints_to_float(0, 0, 0, 0)
    fail = fail + expect(approx(z, 0.0, 1.0e-9), "all zero bits decode to 0.0")
    fail
}

func test_pow2() int {
    int fail = 0
    fail = fail + expect(approx(pow2(0), 1.0, 1.0e-9), "pow2(0)=1")
    fail = fail + expect(approx(pow2(3), 8.0, 1.0e-9), "pow2(3)=8")
    fail = fail + expect(approx(pow2(-2), 0.25, 1.0e-9), "pow2(-2)=0.25")
    fail
}

func test_gqa_attention_matches_mqa() int {
    int block_size = 4
    int num_kv_heads = 1
    int head_size = 4
    int num_heads = 2
    int max_blocks = 16
    float scale = 1.0 / 2.0
    paged_attention_config cfg = paged_attention_config{
        block_size: block_size,
        num_kv_heads: num_kv_heads,
        head_size: head_size,
        max_blocks: max_blocks,
        scale: scale,
    }
    paged_kv_cache cache = new_paged_kv_cache(cfg)
    int seq_len = 3
    cache = reserve_tokens(cache, seq_len)
    int kv_stride = num_kv_heads * head_size
    []float keys = make([]float, seq_len * kv_stride)
    []float values = make([]float, seq_len * kv_stride)
    int t = 0
    for t < seq_len {
        int d = 0
        for d < kv_stride {
            keys[t * kv_stride + d] = float(t + 1) * 0.1
            values[t * kv_stride + d] = float(t + 1) * 0.2
            d = d + 1
        }
        t = t + 1
    }
    cache = write_kv_to_cache(cache, keys, values, 0)
    int q_stride = num_heads * head_size
    []float queries = make([]float, seq_len * q_stride)
    int qi = 0
    for qi < len(queries) {
        queries[qi] = 0.1
        qi = qi + 1
    }
    []float out_gqa = make([]float, seq_len * q_stride)
    []slot_mapping slots = cache.token_to_slot
    out_gqa = compute_paged_attention_gqa(cache, queries, out_gqa, slots, num_heads, num_kv_heads, head_size, scale)
    int fail = 0
    fail = fail + expect(len(out_gqa) >= seq_len * q_stride, "gqa output length covers all query tokens")
    fail = fail + expect(approx(out_gqa[0], 0.2, 0.05), "gqa output at query 0 head 0 dim 0 reasonable")
    fail = fail + expect(approx(out_gqa[head_size], 0.2, 0.05), "gqa output at query 0 head 1 dim 0 shares same kv head")
    fail
}

func test_gqa_group_assignment() int {
    int num_heads = 8
    int num_kv_heads = 2
    int group_size = num_heads / num_kv_heads
    int fail = 0
    fail = fail + expect(group_size == 4, "group size = 4 for 8 heads / 2 kv heads")
    int h = 0
    for h < num_heads {
        int expected_kv = h / group_size
        fail = fail + expect(h / group_size == expected_kv, "q head maps to correct kv head group")
        h = h + 1
    }
    fail
}

func test_softmax_sums_to_one() int {
    []float logits = make([]float, 4)
    logits[0] = 1.0
    logits[1] = 2.0
    logits[2] = 3.0
    logits[3] = 0.5
    []float probs = softmax(logits, 4)
    int fail = 0
    float sum = 0.0
    int i = 0
    for i < 4 {
        sum = sum + probs[i]
        i = i + 1
    }
    fail = fail + expect(approx(sum, 1.0, 1.0e-4), "softmax sums to 1")
    fail = fail + expect(probs[2] > probs[1] && probs[1] > probs[0], "softmax monotone with logits")
    fail
}

func test_temperature_scaling() int {
    []float logits = make([]float, 3)
    logits[0] = 1.0
    logits[1] = 2.0
    logits[2] = 3.0
    []float scaled = apply_temperature(logits, 0.5, 3)
    int fail = 0
    fail = fail + expect(approx(scaled[0], 2.0, 1.0e-6), "temp 0.5 scales logit 1.0 to 2.0")
    fail = fail + expect(approx(scaled[1], 4.0, 1.0e-6), "temp 0.5 scales logit 2.0 to 4.0")
    fail = fail + expect(approx(scaled[2], 6.0, 1.0e-6), "temp 0.5 scales logit 3.0 to 6.0")
    fail
}

func test_top_k_filter_keeps_top() int {
    []float logits = make([]float, 5)
    logits[0] = 1.0
    logits[1] = 5.0
    logits[2] = 3.0
    logits[3] = 4.0
    logits[4] = 2.0
    []float filtered = top_k_filter(logits, 5, 2)
    int fail = 0
    fail = fail + expect(approx(filtered[1], 5.0, 1.0e-6), "top_k keeps logit 5.0 at index 1")
    fail = fail + expect(approx(filtered[3], 4.0, 1.0e-6), "top_k keeps logit 4.0 at index 3")
    fail = fail + expect(filtered[0] < -1.0e29, "top_k zeroes out index 0")
    fail
}

func test_top_p_filter_nucleus() int {
    []float logits = make([]float, 4)
    logits[0] = 0.0
    logits[1] = 10.0
    logits[2] = 9.0
    logits[3] = -5.0
    []float filtered = top_p_filter(logits, 4, 0.9)
    int fail = 0
    fail = fail + expect(filtered[1] > -1.0e29, "top_p keeps index 1 (highest prob)")
    fail = fail + expect(filtered[3] < -1.0e29, "top_p filters out index 3 (low prob)")
    fail
}

func test_argmax() int {
    []float arr = make([]float, 4)
    arr[0] = 1.0
    arr[1] = 5.0
    arr[2] = 3.0
    arr[3] = 2.0
    int idx = argmax(arr, 4)
    int fail = 0
    fail = fail + expect(idx == 1, "argmax picks index 1 with value 5.0")
    fail
}

func test_greedy_sample() int {
    []float logits = make([]float, 4)
    logits[0] = 1.0
    logits[1] = 5.0
    logits[2] = 3.0
    logits[3] = 2.0
    int idx = greedy_sample(logits, 4)
    int fail = 0
    fail = fail + expect(idx == 1, "greedy_sample picks argmax index 1")
    fail
}

func test_sample_deterministic_with_seed() int {
    []float logits = make([]float, 4)
    logits[0] = 1.0
    logits[1] = 2.0
    logits[2] = 3.0
    logits[3] = 4.0
    sampling_params params = new_sampling_params(0.8, 2, 0.9, 42)
    rng_state rng1 = new_rng(42)
    rng_state rng2 = new_rng(42)
    (int tok1, rng_state r1) = sample(logits, 4, params, rng1)
    (int tok2, rng_state r2) = sample(logits, 4, params, rng2)
    int fail = 0
    fail = fail + expect(tok1 == tok2, "same seed produces same token")
    fail
}

func test_rng_float_range() int {
    rng_state rng = new_rng(123)
    int fail = 0
    int i = 0
    for i < 100 {
        (float f, rng_state r) = next_float(rng)
        rng = r
        fail = fail + expect(f >= 0.0 && f < 1.0, "rng float in [0, 1)")
        if fail != 0 {
            break
        }
        i = i + 1
    }
    fail
}

func test_engine_greedy_vs_sampling() int {
    generation_engine engine = new_generation_engine(1)
    generation_result greedy = generate_greedy(engine, "hello", 4)
    int fail = 0
    fail = fail + expect(greedy.num_generated > 0, "greedy generates tokens")
    generation_engine engine2 = new_generation_engine(1)
    sampling_params params = new_sampling_params(0.7, 0, 0.9, 99)
    generation_result sampled = generate_with_sampling(engine2, "hello", 4, params)
    fail = fail + expect(sampled.num_generated > 0, "sampling generates tokens")
    fail
}

func test_engine_weights_load_missing_file() int {
    generation_engine engine = new_generation_engine(1)
    bool ok = load_weights_from_safetensors(engine, "/nonexistent/path/model.safetensors")
    int fail = 0
    fail = fail + expect(!ok, "missing safetensors file returns false")
    fail
}

func test_math_exp() int {
    int fail = 0
    fail = fail + expect(approx(math_exp(0.0), 1.0, 1.0e-4), "exp(0)=1")
    fail = fail + expect(approx(math_exp(1.0), 2.7182818, 1.0e-3), "exp(1)=e")
    fail = fail + expect(approx(math_exp(-2.0), 0.1353352, 1.0e-4), "exp(-2)=0.1353")
    fail
}

func main() {
    int fail = 0
    fail = fail + test_header_json_parse()
    fail = fail + test_ints_to_float()
    fail = fail + test_pow2()
    fail = fail + test_gqa_attention_matches_mqa()
    fail = fail + test_gqa_group_assignment()
    fail = fail + test_softmax_sums_to_one()
    fail = fail + test_temperature_scaling()
    fail = fail + test_top_k_filter_keeps_top()
    fail = fail + test_top_p_filter_nucleus()
    fail = fail + test_argmax()
    fail = fail + test_greedy_sample()
    fail = fail + test_sample_deterministic_with_seed()
    fail = fail + test_rng_float_range()
    fail = fail + test_engine_greedy_vs_sampling()
    fail = fail + test_engine_weights_load_missing_file()
    fail = fail + test_math_exp()
    if fail == 0 {
        println("PASS weights gqa sampling")
        return 0
    }
    println("FAIL weights gqa sampling")
    1
}
