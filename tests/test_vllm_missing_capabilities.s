package neurx.tests.test_vllm_missing_capabilities

use neurx.inference.speculative.registry.{speculative_backend_config, speculative_backend_state, speculative_verification_result, speculative_eagle, init_speculative_backend, verify_speculative_tokens, speculative_acceptance_percent}
use neurx.inference.attention.backend_registry.{attention_backend_request, attention_backend_selection, attention_flashmla, select_attention_backend}
use neurx.quantization.backend_registry.{quantization_request, quantization_selection, quant_fp8, quant_awq, select_quantization_backend}
use neurx.platforms.registry.{platform_request, platform_selection, select_platform}
use neurx.serving.protocol.anthropic_messages.{anthropic_message_request, anthropic_message_response, anthropic_validation_result, anthropic_validate_request, anthropic_messages_json, anthropic_content_delta_event}
use neurx.inference.speech.speech_to_text.{speech_to_text_config, speech_to_text_state, speech_chunk, speech_chunk_result, speech_task_transcribe, init_speech_to_text, speech_consume_chunk, speech_openai_json}
use neurx.distributed.elastic_ep.{elastic_ep_config, elastic_ep_state, elastic_ep_transition, elastic_phase_stable, init_elastic_ep, stage_elastic_ep_resize, commit_elastic_ep_resize, abort_elastic_ep_resize}
use neurx.distributed.eplb.{eplb_config, eplb_state, eplb_rebalance_plan, init_eplb, eplb_record_routing, eplb_imbalance_percent, eplb_plan_rebalance, eplb_apply_rebalance}
use neurx.distributed.kv_transfer.connectors.{kv_connector_config, kv_connector_state, kv_connector_operation, kv_connector_mooncake_store, init_kv_connector, begin_kv_connector_operation, finish_kv_connector_operation, shutdown_kv_connector}
use neurx.distributed.ec_transfer.{ec_transfer_config, ec_transfer_state, ec_transfer_request, init_ec_transfer, begin_ec_transfer, finish_ec_transfer, shutdown_ec_transfer}

func capability_expect(bool condition, string name) int {
    if condition {
        println("PASS " + name)
        return 0
    }
    println("FAIL " + name)
    1
}

func capability_contains(string text, string expected) bool {
    if len(expected) == 0 { return true }
    if len(text) < len(expected) { return false }
    int i = 0
    while i + len(expected) <= len(text) {
        bool match = true
        int j = 0
        while match && j < len(expected) {
            if text[i + j] != expected[j] { match = false }
            j = j + 1
        }
        if match { return true }
        i = i + 1
    }
    false
}

func test_speculative_registry() int {
    int failures = 0
    speculative_backend_config config = speculative_backend_config {backend: speculative_eagle(), num_speculative_tokens: 3, min_speculative_tokens: 1, max_speculative_tokens: 6, ngram_min: 0, ngram_max: 0, draft_model: "draft-eagle", dynamic_tokens: true, enabled: true}
    speculative_backend_state state = init_speculative_backend(config)
    failures = failures + capability_expect(state.initialized, "EAGLE backend initialization")
    speculative_verification_result result = verify_speculative_tokens(state, []int{1, 2, 3}, []int{1, 2, 9}, 10)
    failures = failures + capability_expect(result.accepted_count == 2 && len(result.output_tokens) == 3 && result.output_tokens[2] == 9, "speculative target verification")
    failures = failures + capability_expect(speculative_acceptance_percent(result.state) == 66, "speculative acceptance metrics")
    failures
}

func test_backend_registries() int {
    int failures = 0
    attention_backend_selection attention = select_attention_backend(attention_backend_request {platform: "cuda", compute_capability: 90, require_paged_kv: true, require_mla: true, require_fp8_kv: true, require_cuda_graph: true})
    failures = failures + capability_expect(attention.found && attention.capability.backend == attention_flashmla(), "attention capability selection")
    quantization_selection fp8 = select_quantization_backend(quantization_request {backend: quant_fp8(), platform: "cuda", is_moe: true, online_quantization: true, quantized_kv_cache: true})
    failures = failures + capability_expect(fp8.supported, "FP8 quantization capability selection")
    quantization_selection awq_cpu = select_quantization_backend(quantization_request {backend: quant_awq(), platform: "cpu", is_moe: false, online_quantization: false, quantized_kv_cache: false})
    failures = failures + capability_expect(!awq_cpu.supported, "unsupported quantization rejection")
    platform_selection cuda = select_platform(platform_request {platform: "cuda", require_graph_capture: true, require_speculative_decode: true, require_multimodal: true, require_fp8: true, require_distributed: true})
    failures = failures + capability_expect(cuda.supported && cuda.capability.distributed_backend == "nccl", "CUDA platform capability selection")
    platform_selection cpu_speculative = select_platform(platform_request {platform: "cpu", require_graph_capture: false, require_speculative_decode: true, require_multimodal: false, require_fp8: false, require_distributed: false})
    failures = failures + capability_expect(!cpu_speculative.supported, "platform requirement rejection")
    failures
}

func test_anthropic_protocol() int {
    int failures = 0
    anthropic_message_request request = anthropic_message_request {model: "neurx-1", system_prompt: "help", user_content: "hello", max_tokens: 16, temperature: 0.5, top_p: 0.9, stream: true, stop_sequence: ""}
    anthropic_validation_result validation = anthropic_validate_request(request)
    failures = failures + capability_expect(validation.valid, "Anthropic request validation")
    anthropic_message_response response = anthropic_message_response {id: "msg_1", model: request.model, role: "assistant", content: "hello \"S\"", stop_reason: "end_turn", stop_sequence: "", input_tokens: 4, output_tokens: 3}
    string json = anthropic_messages_json(response)
    failures = failures + capability_expect(capability_contains(json, "\"type\":\"message\"") && capability_contains(json, "hello \\\"S\\\""), "Anthropic response serialization")
    string event = anthropic_content_delta_event(0, "token")
    failures = failures + capability_expect(capability_contains(event, "event: content_block_delta") && capability_contains(event, "text_delta"), "Anthropic SSE serialization")
    failures
}

func test_speech_state() int {
    int failures = 0
    speech_to_text_config config = speech_to_text_config {model: "whisper", task: speech_task_transcribe(), language: "", sample_rate: 2, channels: 1, chunk_seconds: 2, streaming: true, word_timestamps: false}
    speech_to_text_state state = init_speech_to_text(config)
    failures = failures + capability_expect(state.initialized, "speech-to-text initialization")
    speech_chunk first = speech_chunk {sequence_id: 0, samples: []float{0.1, 0.2, 0.3, 0.4}, start_ms: 0, end_ms: 2000, final_chunk: false}
    speech_chunk_result decoded = speech_consume_chunk(state, first, "hello", "en")
    speech_chunk second = speech_chunk {sequence_id: 1, samples: []float{0.5, 0.6}, start_ms: 2000, end_ms: 3000, final_chunk: true}
    decoded = speech_consume_chunk(decoded.state, second, "world", "en")
    failures = failures + capability_expect(decoded.success && decoded.state.complete && decoded.state.transcript == "hello world", "streaming speech chunks")
    failures = failures + capability_expect(decoded.state.audio_duration_ms == 3000 && decoded.state.samples_received == 6, "speech accounting")
    failures = failures + capability_expect(capability_contains(speech_openai_json(decoded.state, true), "hello world"), "OpenAI transcription serialization")
    failures
}

func test_elastic_ep() int {
    int failures = 0
    elastic_ep_state state = init_elastic_ep(elastic_ep_config {minimum_world_size: 2, maximum_world_size: 8, initial_world_size: 4, expert_count: 16, rebalance_threshold_percent: 20, enabled: true})
    elastic_ep_transition staged = stage_elastic_ep_resize(state, 6)
    failures = failures + capability_expect(staged.accepted && staged.state.target_world_size == 6, "elastic EP resize staging")
    elastic_ep_transition committed = commit_elastic_ep_resize(staged.state)
    failures = failures + capability_expect(committed.accepted && committed.state.active_world_size == 6 && committed.state.generation == 1 && committed.state.phase == elastic_phase_stable(), "elastic EP resize commit")
    elastic_ep_state aborted = abort_elastic_ep_resize(committed.state, "operator rollback")
    failures = failures + capability_expect(aborted.active_world_size == 6 && aborted.error_message == "operator rollback", "elastic EP rollback")
    failures
}

func test_eplb() int {
    int failures = 0
    eplb_state state = init_eplb(eplb_config {expert_count: 4, rank_count: 2, replicas_per_expert: 1, rebalance_threshold_percent: 20, enabled: true})
    state = eplb_record_routing(state, 0, 60)
    state = eplb_record_routing(state, 2, 40)
    state = eplb_record_routing(state, 1, 5)
    failures = failures + capability_expect(eplb_imbalance_percent(state) > 20, "EPLB imbalance detection")
    eplb_rebalance_plan plan = eplb_plan_rebalance(state)
    failures = failures + capability_expect(plan.required && plan.source_rank == 0 && plan.destination_rank == 1, "EPLB migration planning")
    state = eplb_apply_rebalance(state, plan)
    failures = failures + capability_expect(state.rebalance_count == 1 && state.expert_rank[plan.expert_id] == 1, "EPLB migration commit")
    failures
}

func test_transfer_backends() int {
    int failures = 0
    kv_connector_config connector_config = kv_connector_config {backend: kv_connector_mooncake_store(), endpoint: "store://kv", role: "producer", rank: 0, world_size: 2, timeout_ms: 5000, layerwise: true, enabled: true}
    kv_connector_state connector = init_kv_connector(connector_config)
    failures = failures + capability_expect(connector.connected && connector.capability.supports_remote_store, "KV connector initialization")
    kv_connector_operation operation = begin_kv_connector_operation(connector, 4096, true)
    connector = finish_kv_connector_operation(operation.state, 4096, true, "")
    failures = failures + capability_expect(operation.accepted && connector.completed_operations == 1 && connector.bytes_transferred == 4096, "KV connector transfer lifecycle")
    connector = shutdown_kv_connector(connector)
    failures = failures + capability_expect(connector.shutdown && !connector.connected, "KV connector shutdown")
    ec_transfer_state ec = init_ec_transfer(ec_transfer_config {engine_id: "engine-0", rank: 0, world_size: 2, tensor_parallel_size: 1, timeout_ms: 5000, enabled: true})
    ec_transfer_request ec_request = begin_ec_transfer(ec, 1, 3, 12288, true)
    ec = finish_ec_transfer(ec_request.state, ec_request.tensor_count, ec_request.byte_count, true, "")
    failures = failures + capability_expect(ec_request.accepted && ec.completed_requests == 1 && ec.tensors_transferred == 3 && ec.bytes_transferred == 12288, "EC transfer lifecycle")
    ec = shutdown_ec_transfer(ec)
    failures = failures + capability_expect(ec.shutdown && !ec.initialized, "EC transfer shutdown")
    failures
}

func main() {
    int failures = 0
    failures = failures + test_speculative_registry()
    failures = failures + test_backend_registries()
    failures = failures + test_anthropic_protocol()
    failures = failures + test_speech_state()
    failures = failures + test_elastic_ep()
    failures = failures + test_eplb()
    failures = failures + test_transfer_backends()
    if failures == 0 { println("vLLM missing capability contract: PASS") }
    else { println("vLLM missing capability contract: FAIL") }
}
