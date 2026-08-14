package neurx.tests.paged_attention_real_test
use neurx.attention.paged_attention_core.{
    paged_attention_config,
    paged_kv_cache,
    slot_mapping,
    new_paged_kv_cache,
    reserve_tokens,
    write_kv_to_cache,
    compute_paged_attention,
    compute_softmax,
    math_exp,
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

func test_softmax_simple() int {
    float[] scores = []float{1.0, 2.0, 3.0}
    float[] probs = compute_softmax(scores)
    float sum = 0.0
    int i = 0
    while i < len(probs) {
        sum = sum + probs[i]
        i = i + 1
    }
    int fail = 0
    fail = fail + expect(approx(sum, 1.0, 1.0e-4), "softmax sums to 1")
    fail = fail + expect(probs[2] > probs[1] && probs[1] > probs[0], "softmax monotone")
    fail
}

func test_exp_basic() int {
    int fail = 0
    fail = fail + expect(approx(math_exp(0.0), 1.0, 1.0e-4), "exp(0)=1")
    fail = fail + expect(approx(math_exp(1.0), 2.7182818, 1.0e-3), "exp(1)=e")
    fail = fail + expect(approx(math_exp(-1.0), 0.3678794, 1.0e-3), "exp(-1)=1/e")
    fail
}

func test_paged_kv_write_and_attention() int {
    int block_size = 4
    int num_kv_heads = 2
    int head_size = 4
    int num_heads = 2
    int seq_len = 3
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
    cache = reserve_tokens(cache, seq_len)
    int fail = 0
    fail = fail + expect(len(cache.token_to_slot) == seq_len, "token_to_slot length after reserve")
    fail = fail + expect(cache.allocated_blocks == 1, "allocated blocks after reserve")
    fail = fail + expect(cache.token_to_slot[0].block_id == 0 && cache.token_to_slot[0].offset_in_block == 0, "slot 0 maps to block 0 offset 0")
    fail = fail + expect(cache.token_to_slot[2].block_id == 0 && cache.token_to_slot[2].offset_in_block == 2, "slot 2 maps to block 0 offset 2")
    int kv_stride = num_kv_heads * head_size
    float[] keys = make([]float, seq_len * kv_stride)
    float[] values = make([]float, seq_len * kv_stride)
    int t = 0
    while t < seq_len {
        int d = 0
        while d < kv_stride {
            keys[t * kv_stride + d] = float(t + 1) * 0.1
            values[t * kv_stride + d] = float(t + 1) * 0.2
            d = d + 1
        }
        t = t + 1
    }
    cache = write_kv_to_cache(cache, keys, values, 0)
    fail = fail + expect(cache.blocks[0].num_filled == seq_len, "block 0 num_filled equals seq_len")
    float first_k = cache.blocks[0].key_data[0]
    fail = fail + expect(approx(first_k, 0.1, 1.0e-6), "first key value written correctly")
    int q_stride = num_heads * head_size
    float[] queries = make([]float, seq_len * q_stride)
    int qi = 0
    while qi < seq_len * q_stride {
        queries[qi] = 0.1
        qi = qi + 1
    }
    float[] output = make([]float, seq_len * q_stride)
    []slot_mapping slots = cache.token_to_slot
    output = compute_paged_attention(cache, queries, output, slots, num_heads, head_size, scale)
    fail = fail + expect(len(output) >= seq_len * q_stride, "output length covers all query tokens")
    float out0 = output[0]
    fail = fail + expect(approx(out0, 0.2, 0.05), "attention output at query 0 head 0 dim 0 reasonable")
    fail
}

func main() {
    int fail = 0
    fail = fail + test_softmax_simple()
    fail = fail + test_exp_basic()
    fail = fail + test_paged_kv_write_and_attention()
    if fail == 0 {
        println("PASS paged attention real computation")
        return 0
    }
    println("FAIL paged attention real computation")
    1
}
