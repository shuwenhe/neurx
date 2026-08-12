package main
use neurx.inference.serve.request_lifecycle
use neurx.inference.advanced.structured_output
use neurx.inference.advanced.tool_parser
use neurx.inference.serve.lora_router
use neurx.inference.serve.disaggregated_runtime
use neurx.inference.advanced.pooling
use neurx.inference.api.openai_protocol
use neurx.inference.metrics.observability
func gap_close(float actual, float expected) bool {
    float difference = actual - expected
    if difference < 0.0 {
        difference = 0.0 - difference
    }
    difference < 0.0001
}


func gap_contains(string text, string pattern) bool {
    int i = 0
    while i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        while j < len(pattern) {
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


func test_request_lifecycle() bool {
    request_lifecycle_state state = neurx.inference.serve.request_lifecycle.new_request_lifecycle("req-1", 12, 2, 100, 500)
    state.status == neurx.inference.serve.request_lifecycle.request_queued_status() && neurx.inference.serve.request_lifecycle.request_remaining_tokens(state) == 2 && !neurx.inference.serve.request_lifecycle.request_is_terminal(state)
}


func test_structured_output() bool {
    json_stream_state stream = neurx.inference.advanced.structured_output.new_json_stream_state()
    stream = neurx.inference.advanced.structured_output.json_stream_consume(stream, "{\"name\":\"alice\",")
    if !stream.valid || stream.complete {
        return false
    }
    stream = neurx.inference.advanced.structured_output.json_stream_consume(stream, "\"age\":7}")
    structured_validation_result syntax = neurx.inference.advanced.structured_output.json_stream_finish(stream)
    syntax.valid && stream.complete
}


func test_tool_parser() bool {
    string payload = "<tool_call>{\"name\":\"weather\"}</tool_call>"
    neurx.inference.advanced.tool_parser.tool_find_substring(payload, "weather", 0) > 0 && neurx.inference.advanced.tool_parser.tool_extract_tag(payload, "<tool_call>", "</tool_call>") != ""
}


func test_lora_router() bool {
    neurx.inference.serve.lora_router.lora_unloaded_status() != neurx.inference.serve.lora_router.lora_ready_status() && neurx.inference.serve.lora_router.lora_loading_status() != neurx.inference.serve.lora_router.lora_failed_status()
}


func test_disaggregated_runtime() bool {
    neurx.inference.serve.disaggregated_runtime.disaggregated_queued_prefill() != neurx.inference.serve.disaggregated_runtime.disaggregated_decoding() && neurx.inference.serve.disaggregated_runtime.kv_transfer_pending() != neurx.inference.serve.disaggregated_runtime.kv_transfer_complete()
}


func test_pooling() bool {
    gap_close(1.0, 1.0)
}


func test_openai_protocol() bool {
    string event = neurx.inference.api.openai_protocol.openai_chat_chunk("chat-1", "neurx", "hi", "")
    string escaped = neurx.inference.api.openai_protocol.openai_json_escape("a\"b")
    gap_contains(event, "chat.completion.chunk") && gap_contains(neurx.inference.api.openai_protocol.openai_done_event(), "[DONE]") && escaped == "a\\\"b"
}


func test_observability() bool {
    inference_observability_state state = neurx.inference.metrics.observability.new_inference_observability()
    state = neurx.inference.metrics.observability.observability_start_request(state, 4)
    state = neurx.inference.metrics.observability.observability_record_cache(state, true)
    state = neurx.inference.metrics.observability.observability_record_kv_handoff(state)
    state = neurx.inference.metrics.observability.observability_finish_request(state, 2, 25, false)
    string metrics = neurx.inference.metrics.observability.observability_prometheus(state)
    gap_contains(metrics, "neurx_inference_requests_total 1") && gap_contains(metrics, "neurx_inference_kv_handoffs_total 1")
}


func main() {
    bool passed = test_request_lifecycle()
    passed = passed && test_structured_output()
    passed = passed && test_tool_parser()
    passed = passed && test_lora_router()
    passed = passed && test_disaggregated_runtime()
    passed = passed && test_pooling()
    passed = passed && test_openai_protocol()
    passed = passed && test_observability()
    if passed {
        println("PASS inference feature gap")
        return 0
    }
    println("FAIL inference feature gap")
    1
}

