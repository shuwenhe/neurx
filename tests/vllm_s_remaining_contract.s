package neurx.tests.vllm_s_remaining_contract

use neurx.inference.cache.kv_event_stream.{kv_event_stream_config, kv_event_stream_state, kv_event_publish_result, kv_event_poll_result, kv_event_block_stored, kv_event_block_removed, kv_medium_gpu, init_kv_event_stream, publish_kv_event, poll_kv_events, acknowledge_kv_events}
use neurx.inference.cache.tiered_kv_offload.{tiered_kv_offload_config, tiered_kv_offload_state, offload_prepare_result, offload_lookup_result, offload_medium_cpu, offload_lookup_hit, init_tiered_kv_offload, prepare_offload_store, complete_offload_store, lookup_offloaded_block, prepare_offload_load, complete_offload_load, tiered_offload_bytes}
use neurx.inference.reasoning.reasoning_parser_registry.{reasoning_stream_state, reasoning_parser_qwen3, init_reasoning_stream, consume_reasoning_delta}
use neurx.inference.tokenizer.tokenizer_renderer_registry.{tokenizer_renderer_request, tokenizer_renderer_selection, tokenizer_backend_mistral, renderer_backend_mistral, tokenizer_truncate_left, select_tokenizer_renderer}
use neurx.inference.runtime.model_capability_inspection.{model_capability_manifest, model_inspection_request, model_inspection_result, model_task_generate, model_task_embed, inspect_model_capability}
use neurx.inference.multimodal.media_cache_budget.{media_cache_config, media_cache_state, media_cache_result, media_budget_result, media_modality_image, media_hash_bytes, init_media_cache, media_cache_insert, media_cache_lookup, compute_media_budget}
use neurx.inference.plugins.plugin_registry.{plugin_registry_config, plugin_registry_state, plugin_registration_result, plugin_group_endpoint, plugin_group_io_processor, plugin_status_active, plugin_status_skipped, init_plugin_registry, register_plugin, activate_plugin}

func remaining_expect(bool condition, string name) int {
    if condition { println("PASS " + name); return 0 }
    println("FAIL " + name)
    1
}

func test_kv_event_stream() int {
    int failures = 0
    kv_event_stream_state state = init_kv_event_stream(kv_event_stream_config {capacity: 2, data_parallel_rank: 0, worker_count: 2, enabled: true})
    kv_event_publish_result published = publish_kv_event(state, kv_event_block_stored(), 101, 0, kv_medium_gpu(), 0, 0)
    published = publish_kv_event(published.state, kv_event_block_stored(), 101, 0, kv_medium_gpu(), 0, 1)
    kv_event_poll_result common = poll_kv_events(published.state, 0, true)
    failures = failures + remaining_expect(common.event_count == 1 && common.block_hashes[0] == 101, "KV event worker aggregation")
    state = acknowledge_kv_events(published.state, common.high_watermark)
    published = publish_kv_event(state, kv_event_block_removed(), 202, 0, kv_medium_gpu(), 0, 0)
    published = publish_kv_event(published.state, kv_event_block_removed(), 303, 0, kv_medium_gpu(), 0, 0)
    failures = failures + remaining_expect(published.state.event_count == 2 && published.state.dropped_events == 1, "KV event replay capacity")
    failures
}

func test_tiered_offload() int {
    int failures = 0
    tiered_kv_offload_state state = init_tiered_kv_offload(tiered_kv_offload_config {capacity_blocks: 2, bytes_per_block: 128, medium: offload_medium_cpu(), locality: 1, enabled: true})
    offload_prepare_result prepared = prepare_offload_store(state, 11, 0)
    state = complete_offload_store(prepared.state, prepared.slot, true)
    offload_lookup_result lookup = lookup_offloaded_block(state, 11, 0)
    failures = failures + remaining_expect(lookup.status == offload_lookup_hit(), "tiered KV lookup")
    prepared = prepare_offload_load(lookup.state, 11, 0)
    state = complete_offload_load(prepared.state, prepared.slot, true)
    prepared = prepare_offload_store(state, 22, 0)
    state = complete_offload_store(prepared.state, prepared.slot, true)
    prepared = prepare_offload_store(state, 33, 0)
    state = complete_offload_store(prepared.state, prepared.slot, true)
    failures = failures + remaining_expect(state.evicted_blocks == 1 && state.loaded_blocks == 1 && tiered_offload_bytes(state) == 256, "tiered KV LRU and accounting")
    failures
}

func test_reasoning_and_rendering() int {
    int failures = 0
    reasoning_stream_state reasoning = init_reasoning_stream(reasoning_parser_qwen3())
    reasoning = consume_reasoning_delta(reasoning, "<think>check", false)
    reasoning = consume_reasoning_delta(reasoning, " facts</think>answer", true)
    failures = failures + remaining_expect(reasoning.reasoning_content == "check facts" && reasoning.content == "answer" && reasoning.reasoning_complete, "streaming reasoning parser")
    tokenizer_renderer_selection mistral = select_tokenizer_renderer(tokenizer_renderer_request {tokenizer_mode: "auto", model_family: "mistral", runner_type: "generate", use_fast: true, skip_tokenizer_init: false})
    failures = failures + remaining_expect(mistral.supported && mistral.tokenizer_backend == tokenizer_backend_mistral() && mistral.renderer_backend == renderer_backend_mistral() && mistral.truncation_side == tokenizer_truncate_left(), "tokenizer and renderer selection")
    tokenizer_renderer_selection invalid = select_tokenizer_renderer(tokenizer_renderer_request {tokenizer_mode: "slow", model_family: "generic", runner_type: "generate", use_fast: true, skip_tokenizer_init: false})
    failures = failures + remaining_expect(!invalid.supported && invalid.error_code == 2, "tokenizer mode validation")
    failures
}

func test_model_and_multimodal() int {
    int failures = 0
    model_capability_manifest manifest = model_capability_manifest {architecture: "QwenVL", model_family: "qwen", quantization: "fp8", task_mask: model_task_generate() + model_task_embed(), max_model_length: 32768, vocabulary_size: 151936, hidden_size: 4096, layer_count: 32, attention_head_count: 32, kv_head_count: 8, is_multimodal: true, is_moe: false, supports_lora: true, supports_prefix_cache: true}
    model_inspection_result inspection = inspect_model_capability(manifest, model_inspection_request {required_task: model_task_generate(), requested_context_length: 8192, require_multimodal: true, require_lora: true, require_prefix_cache: true})
    failures = failures + remaining_expect(inspection.supported && inspection.effective_context_length == 8192, "model capability inspection")
    media_cache_config config = media_cache_config {capacity_items: 2, encoder_compute_budget: 4096, encoder_cache_budget: 3072, max_model_length: 8192, max_batch_requests: 4, enabled: true}
    media_cache_state cache = init_media_cache(config)
    int first_hash = media_hash_bytes([]int{1, 2, 3, 4}, media_modality_image(), 7)
    int second_hash = media_hash_bytes([]int{1, 2, 3, 4}, media_modality_image(), 7)
    media_cache_result inserted = media_cache_insert(cache, first_hash, media_modality_image(), 512)
    media_cache_result cached = media_cache_lookup(inserted.state, second_hash)
    failures = failures + remaining_expect(first_hash == second_hash && cached.hit, "multimodal deterministic hash and cache")
    media_budget_result budget = compute_media_budget(config, 512, 3, true, 4096)
    failures = failures + remaining_expect(budget.supported && budget.encoder_budget == 3072 && budget.max_items_per_prompt == 3 && budget.max_items_per_batch == 6, "multimodal encoder budget")
    failures
}

func test_plugin_security() int {
    int failures = 0
    plugin_registry_state state = init_plugin_registry(plugin_registry_config {capacity: 4, supported_task_mask: model_task_generate(), endpoint_allowlist_configured: true})
    plugin_registration_result endpoint = register_plugin(state, 1001, plugin_group_endpoint(), model_task_generate(), false)
    state = activate_plugin(endpoint.state, endpoint.slot)
    failures = failures + remaining_expect(state.statuses[endpoint.slot] == plugin_status_skipped(), "endpoint plugin deny by default")
    endpoint = register_plugin(state, 1002, plugin_group_endpoint(), model_task_generate(), true)
    state = activate_plugin(endpoint.state, endpoint.slot)
    failures = failures + remaining_expect(state.statuses[endpoint.slot] == plugin_status_active() && state.active_count == 1, "allowlisted endpoint plugin activation")
    plugin_registration_result io = register_plugin(state, 2001, plugin_group_io_processor(), model_task_embed(), true)
    state = activate_plugin(io.state, io.slot)
    failures = failures + remaining_expect(state.statuses[io.slot] == plugin_status_skipped(), "plugin task compatibility gating")
    failures
}

func main() {
    int failures = 0
    failures = failures + test_kv_event_stream()
    failures = failures + test_tiered_offload()
    failures = failures + test_reasoning_and_rendering()
    failures = failures + test_model_and_multimodal()
    failures = failures + test_plugin_security()
    if failures == 0 { println("vLLM remaining capability contract: PASS") }
    else { println("vLLM remaining capability contract: FAIL") }
}
