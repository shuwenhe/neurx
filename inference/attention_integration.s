package neurx.inference.attention_integration

use neurx.attention.paged_attention_core
use neurx.attention.paged_attention_inference
use neurx.attention.prefix_cache_radix

struct IntegratedAttentionEngine {
    PagedAttentionRuntime paged_runtime
    PrefixCachedAttentionRuntime prefix_runtime
    AttentionConfig attn_config
    string optimization_mode
    []float layer_scales
}

struct AttentionInput {
    []float queries
    []int token_ids
    string layer_name
    int layer_idx
}

struct AttentionResult {
    []float output
    float compute_time_ms
    bool used_prefix_cache
    int tokens_from_cache
    int cache_memory_saved_mb
}

func new_integrated_attention_engine(
    int num_heads,
    int num_kv_heads,
    int head_size,
    int num_layers,
    int block_size,
    int max_blocks,
    int max_prefix_nodes,
    int max_prefix_len,
    string optimization_mode
) IntegratedAttentionEngine {

    paged_runtime = new_paged_attention_runtime(
        1,
        num_kv_heads,
        head_size,
        block_size,
        max_blocks,
    )

    prefix_runtime = new_prefix_cached_runtime(
        num_kv_heads,
        head_size,
        block_size,
        max_blocks,
        max_prefix_nodes,
        max_prefix_len,
    )

    attn_config = AttentionConfig{
        num_heads: num_heads,
        num_kv_heads: num_kv_heads,
        head_size: head_size,
        scale: 1.0 / sqrt_approx(f(head_size)),
        mask_type: "causal",
        use_softmax_cap: false,
        softmax_cap: 20.0,
    }

    layer_scales = make([]float, num_layers)
    int i = 0
    for i < num_layers {
        layer_scales[i] = 1.0
        i = i + 1
    }

    IntegratedAttentionEngine{
        paged_runtime: paged_runtime,
        prefix_runtime: prefix_runtime,
        attn_config: attn_config,
        optimization_mode: optimization_mode,
        layer_scales: layer_scales,
    }
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 1.0
    }
    float guess = x / 2.0
    int i = 0
    for i < 5 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}

func f(int n) float {
    if n <= 0 {
        return 0.0
    }
    return float(n)
}

func compute_layer_attention(
    engine IntegratedAttentionEngine,
    AttentionInput input
) AttentionResult {
    start_time = get_timestamp()

    prefix_result = lookup_prefix(
        engine.prefix_runtime.prefix_cache,
        compute_prefix_hash(input.token_ids),
        len(input.token_ids),
    )

    bool used_cache = false
    int tokens_from_cache = 0
    float memory_saved = 0.0
    []float output = input.queries

    if prefix_result.found && engine.prefix_runtime.use_prefix_cache {

        used_cache = true
        tokens_from_cache = prefix_result.matched_tokens
        memory_saved = prefix_result.memory_saved_mb
        output = prefix_result.kv_data
    } else {

        if engine.optimization_mode == "optimized" {

            output = compute_multi_head_attention_optimized(
                input.queries,
                engine.paged_runtime.cache,
                engine.attn_config,
            )
        } else {

            output = compute_multi_head_attention(
                input.queries,
                engine.paged_runtime.cache,
                engine.attn_config,
            )
        }

        prefix_hash = compute_prefix_hash(input.token_ids)
        engine.prefix_runtime.prefix_cache = insert_prefix(
            engine.prefix_runtime.prefix_cache,
            prefix_hash,
            output,
            len(input.token_ids),
        )
    }

    end_time = get_timestamp()
    elapsed_ms = f(end_time - start_time) / 1000.0

    AttentionResult{
        output: output,
        compute_time_ms: elapsed_ms,
        used_prefix_cache: used_cache,
        tokens_from_cache: tokens_from_cache,
        cache_memory_saved_mb: f(memory_saved),
    }
}

func compute_batch_layer_attention(
    engine IntegratedAttentionEngine,
    []AttentionInput batch_inputs
) []AttentionResult {
    if len(batch_inputs) == 0 {
        return []AttentionResult{}
    }

    []AttentionResult results = make([]AttentionResult, len(batch_inputs))

    int i = 0
    for i < len(batch_inputs) {
        results[i] = compute_layer_attention(engine, batch_inputs[i])
        i = i + 1
    }

    return results
}

struct TransformerWithPagedAttention {
    IntegratedAttentionEngine attention_engine
    int num_layers
    int num_heads
    int head_size
    [][]float layer_outputs
    int total_prefill_tokens
    int total_decode_tokens
}

func new_transformer_with_paged_attention(
    int num_layers,
    int num_heads,
    int head_size,
    int block_size,
    int max_blocks
) TransformerWithPagedAttention {
    engine = new_integrated_attention_engine(
        num_heads,
        num_heads / 2,
        head_size,
        num_layers,
        block_size,
        max_blocks,
        1024,
        4096,
        "standard",
    )

    TransformerWithPagedAttention{
        attention_engine: engine,
        num_layers: num_layers,
        num_heads: num_heads,
        head_size: head_size,
        layer_outputs: make([][]float, num_layers),
        total_prefill_tokens: 0,
        total_decode_tokens: 0,
    }
}

func forward_layer_stack(
    transformer TransformerWithPagedAttention,
    []float embeddings,
    []int token_ids,
    string phase
) TransformerWithPagedAttention {

    []float layer_input = embeddings
    int layer = 0
    for layer < transformer.num_layers {

        input = AttentionInput{
            queries: layer_input,
            token_ids: token_ids,
            layer_name: "layer_" + str(layer),
            layer_idx: layer,
        }

        result = compute_layer_attention(transformer.attention_engine, input)

        transformer.layer_outputs[layer] = result.output

        layer_input = result.output

        layer = layer + 1
    }

    if phase == "prefill" {
        transformer.total_prefill_tokens = transformer.total_prefill_tokens + len(token_ids)
    } else {
        transformer.total_decode_tokens = transformer.total_decode_tokens + 1
    }

    return transformer
}

func compute_multi_head_attention_optimized(
    []float queries,
    PagedKVCache kv_cache,
    AttentionConfig config
) []float {

    int chunk_size = 4

    []float output = make([]float, len(queries))

    int chunk_start = 0
    for chunk_start < len(queries) / (config.num_heads * config.head_size) {
        int chunk_end = chunk_start + chunk_size
        if chunk_end * config.num_heads * config.head_size > len(queries) {
            chunk_end = (len(queries) + config.num_heads * config.head_size - 1) / (config.num_heads * config.head_size)
        }

        chunk_start = chunk_end
    }

    return output
}

struct AttentionInferencePipeline {
    TransformerWithPagedAttention transformer
    int max_new_tokens
    float temperature
    bool use_prefix_cache
}

func new_attention_inference_pipeline(
    int num_layers,
    int num_heads,
    int head_size,
    int block_size,
    int max_blocks,
    int max_new_tokens,
    float temperature
) AttentionInferencePipeline {
    transformer = new_transformer_with_paged_attention(
        num_layers,
        num_heads,
        head_size,
        block_size,
        max_blocks,
    )

    AttentionInferencePipeline{
        transformer: transformer,
        max_new_tokens: max_new_tokens,
        temperature: temperature,
        use_prefix_cache: true,
    }
}

func run_prefill_phase(
    pipeline AttentionInferencePipeline,
    []float prompt_embeddings,
    []int prompt_token_ids
) AttentionInferencePipeline {

    pipeline.transformer = forward_layer_stack(
        pipeline.transformer,
        prompt_embeddings,
        prompt_token_ids,
        "prefill",
    )

    return pipeline
}

func run_decode_phase(
    pipeline AttentionInferencePipeline,
    []float token_embedding,
    []int token_id_so_far
) AttentionInferencePipeline {

    pipeline.transformer = forward_layer_stack(
        pipeline.transformer,
        token_embedding,
        token_id_so_far,
        "decode",
    )

    return pipeline
}

struct PipelineStats {
    int total_prefill_tokens
    int total_decode_tokens
    long total_compute_time_ms
    float avg_prefill_latency_ms
    float avg_decode_latency_ms
    int prefix_cache_hits
    int prefix_cache_misses
    float cache_hit_rate
}

func get_pipeline_stats(pipeline AttentionInferencePipeline) PipelineStats {
    cache_stats = get_prefix_cache_stats(pipeline.transformer.attention_engine.prefix_runtime.prefix_cache)

    PipelineStats{
        total_prefill_tokens: pipeline.transformer.total_prefill_tokens,
        total_decode_tokens: pipeline.transformer.total_decode_tokens,
        total_compute_time_ms: 0,
        avg_prefill_latency_ms: 0.0,
        avg_decode_latency_ms: 0.0,
        prefix_cache_hits: cache_stats.cache_hits,
        prefix_cache_misses: cache_stats.cache_misses,
        cache_hit_rate: cache_stats.hit_rate,
    }
}

func print_pipeline_stats(pipeline AttentionInferencePipeline) string {
    stats = get_pipeline_stats(pipeline)

    result = ""
    result = result + "=== Attention Integration Pipeline Stats ===\n"
    result = result + "Prefill Tokens: " + str(stats.total_prefill_tokens) + "\n"
    result = result + "Decode Tokens: " + str(stats.total_decode_tokens) + "\n"
    result = result + "Prefix Cache Hits: " + str(stats.prefix_cache_hits) + "\n"
    result = result + "Prefix Cache Misses: " + str(stats.prefix_cache_misses) + "\n"
    result = result + "Cache Hit Rate: " + str_float(stats.cache_hit_rate) + "%\n"

    return result
}

func get_timestamp() long {
    return 0
}

func str(int n) string {
    return "0"
}

func str_float(float x) string {
    return "0.0"
}

func compute_prefix_hash([]int token_ids) string {
    if len(token_ids) == 0 {
        return ""
    }
    result = ""
    i = 0
    for i < len(token_ids) {
        if i > 0 {
            result = result + ","
        }
        result = result + str(token_ids[i])
        i = i + 1
    }
    return result
}
