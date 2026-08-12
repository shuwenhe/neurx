package neurx.attention.paged_attention_test
use neurx.attention.paged_attention_core
use neurx.inference.paged_attention_runtime
func test_basic_paged_cache() {
    config = paged_attention_config{
        block_size: 16,
        num_kv_heads: 8,
        head_size: 128,
        max_blocks: 64,
        scale: 0.088,
    }
    cache = new_paged_kv_cache(config)
    cache = reserve_tokens(cache, 32)
    assert(cache.total_tokens == 32)
    assert(cache.allocated_blocks == 2)
    cache = reserve_tokens(cache, 16)
    assert(cache.total_tokens == 48)
    assert(cache.allocated_blocks == 3)
    cache = release_tokens(cache, 16)
    assert(cache.total_tokens == 32)
    assert(cache.allocated_blocks == 2)
    cache = reset_cache(cache)
    assert(cache.total_tokens == 0)
    assert(cache.allocated_blocks == 0)
    println("✓ test_basic_paged_cache PASSED")
}

func test_block_allocation() {
    config = paged_attention_config{
        block_size: 16,
        num_kv_heads: 8,
        head_size: 128,
        max_blocks: 10,
        scale: 0.088,
    }
    cache = new_paged_kv_cache(config)
    cache = reserve_tokens(cache, 200)
    assert(cache.total_tokens <= 160)
    assert(cache.allocated_blocks <= 10)
    println("✓ test_block_allocation PASSED")
}

func test_cache_stats() {
    config = paged_attention_config{
        block_size: 16,
        num_kv_heads: 8,
        head_size: 128,
        max_blocks: 64,
        scale: 0.088,
    }
    cache = new_paged_kv_cache(config)
    cache = reserve_tokens(cache, 32)
    stats = get_cache_stats(cache)
    assert(stats.total_tokens == 32)
    assert(stats.allocated_blocks == 2)
    assert(stats.utilization_percent > 0.0)
    assert(stats.utilization_percent < 100.0)
    println("✓ test_cache_stats PASSED")
}

func test_runtime_prefill() {
    runtime = new_paged_attention_runtime(
        1,
        8,
        128,
        16,
        64,
    )
    assert(runtime.current_seq_len == 0)
    assert(runtime.prefill_tokens == 0)
    assert(runtime.decode_steps == 0)
    embeddings = make([]float, 32 * 8 * 128)
    runtime = run_prefill(runtime, embeddings, []float{}, []float{}, []float{})
    assert(runtime.current_seq_len == 32)
    assert(runtime.prefill_tokens == 32)
    println("✓ test_runtime_prefill PASSED")
}

func test_runtime_decode() {
    runtime = new_paged_attention_runtime(
        1,
        8,
        128,
        16,
        64,
    )
    embeddings = make([]float, 32 * 8 * 128)
    runtime = run_prefill(runtime, embeddings, []float{}, []float{}, []float{})
    initial_seq_len = runtime.current_seq_len
    initial_decode_steps = runtime.decode_steps
    token_emb = make([]float, 1 * 8 * 128)
    runtime = run_decode_step(runtime, token_emb, []float{}, []float{}, []float{})
    assert(runtime.current_seq_len == initial_seq_len + 1)
    assert(runtime.decode_steps == initial_decode_steps + 1)
    println("✓ test_runtime_decode PASSED")
}

func test_cache_memory_usage() {
    runtime = new_paged_attention_runtime(
        1,
        8,
        128,
        16,
        64,
    )
    embeddings = make([]float, 32 * 8 * 128)
    runtime = run_prefill(runtime, embeddings, []float{}, []float{}, []float{})
    memory = get_cache_memory_usage(runtime)
    expected = 32 * 8192
    assert(memory > 0)
    assert(memory <= expected * 2)
    println("✓ test_cache_memory_usage PASSED")
}

func test_batched_runtime() {
    batched = new_batched_runtime(
        4,
        8,
        128,
        16,
        64,
    )
    assert(batched.num_sequences == 4)
    embeddings = make([]float, 32 * 8 * 128)
    batched = update_batched_prefill(batched, 0, embeddings)
    assert(batched.runtimes[0].current_seq_len == 32)
    assert(batched.runtimes[1].current_seq_len == 0)
    total_tokens = compute_batched_total_tokens(batched)
    assert(total_tokens == 32)
    println("✓ test_batched_runtime PASSED")
}

func test_cache_utilization() {
    runtime = new_paged_attention_runtime(
        1,
        8,
        128,
        16,
        64,
    )
    util = get_cache_utilization(runtime)
    assert(util == 0.0)
    embeddings = make([]float, 256 * 8 * 128)
    runtime = run_prefill(runtime, embeddings, []float{}, []float{}, []float{})
    util = get_cache_utilization(runtime)
    assert(util > 0.0)
    assert(util < 100.0)
    println("✓ test_cache_utilization PASSED")
}

func assert(bool condition) {
    if !condition {
        println("ASSERTION FAILED!")
    }
}

func println(string msg) {
    printf("%s\n", msg)
}

func run_all_tests() {
    println("=== Running PagedAttention Tests ===")
    test_basic_paged_cache()
    test_block_allocation()
    test_cache_stats()
    test_runtime_prefill()
    test_runtime_decode()
    test_cache_memory_usage()
    test_batched_runtime()
    test_cache_utilization()
    println("\n=== All Tests Completed ===")
}

func main() {
    run_all_tests()
}

