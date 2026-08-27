package neurx.serving.api.native_openai
use neurx.inference.api.contracts.{inference_request}
use neurx.inference.executor.native_executor.{native_execution_result}
use neurx.inference.tokenizer.hf_bpe_tokenizer.{hf_bpe_tokenizer, hf_bpe_decode_result, load_hf_bpe_tokenizer, hf_bpe_decode_generated}
use neurx.serving.lifecycle.native_inference_service.{serve_native_inference}
use neurx.serving.protocol.openai_tgi.{serving_json_escape, openai_chat_sse_chunk, openai_completion_sse_chunk, openai_sse_done, openai_error_json}

struct native_openai_response {
    bool ok
    int status
    string content_type
    string body
    string error_code
}

func native_openai_completion_json(inference_request request, native_execution_result result) string {
    "{\"id\":\"" + serving_json_escape(result.request_id) + "\",\"object\":\"text_completion\",\"model\":\"" + serving_json_escape(request.model) + "\",\"choices\":[{\"index\":0,\"text\":\"" + serving_json_escape(result.output) + "\",\"finish_reason\":\"" + result.finish_reason + "\"}],\"usage\":{\"completion_tokens\":" + string(len(result.token_ids)) + "}}"
}

func native_openai_chat_json(inference_request request, native_execution_result result) string {
    "{\"id\":\"" + serving_json_escape(result.request_id) + "\",\"object\":\"chat.completion\",\"model\":\"" + serving_json_escape(request.model) + "\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"" + serving_json_escape(result.output) + "\"},\"finish_reason\":\"" + result.finish_reason + "\"}],\"usage\":{\"completion_tokens\":" + string(len(result.token_ids)) + "}}"
}

func native_openai_stream(inference_request request, native_execution_result result, bool chat) string {
    hf_bpe_tokenizer tokenizer = load_hf_bpe_tokenizer(request.model)
    if !tokenizer.valid { return "data: " + openai_error_json("failed to load tokenizer.json", "tokenizer_error", 500) + "\n\n" + openai_sse_done() }
    string body = ""
    int i = 0
    for i < len(result.token_ids) {
        int[] single = int[]{cap: 1}
        single[0] = result.token_ids[i]
        hf_bpe_decode_result decoded = hf_bpe_decode_generated(tokenizer, single)
        if decoded.ok && decoded.text != "" {
            if chat { body = body + openai_chat_sse_chunk(result.request_id, request.model, 0, decoded.text, "") }
            else { body = body + openai_completion_sse_chunk(result.request_id, request.model, 0, decoded.text, "") }
        }
        i = i + 1
    }
    if chat { body = body + openai_chat_sse_chunk(result.request_id, request.model, 0, "", result.finish_reason) }
    else { body = body + openai_completion_sse_chunk(result.request_id, request.model, 0, "", result.finish_reason) }
    body + openai_sse_done()
}

func serve_native_openai(inference_request request, string route_kind, int capacity, int active_requests) native_openai_response {
    native_execution_result result = serve_native_inference(request, capacity, active_requests)
    if !result.ok { return native_openai_response { ok: false, status: 500, content_type: "application/json", body: openai_error_json(result.error_message, result.error_code, 500), error_code: result.error_code } }
    if route_kind == "openai-chat" { return native_openai_response { ok: true, status: 200, content_type: "application/json", body: native_openai_chat_json(request, result), error_code: "" } }
    if route_kind == "openai-completion" { return native_openai_response { ok: true, status: 200, content_type: "application/json", body: native_openai_completion_json(request, result), error_code: "" } }
    if route_kind == "openai-chat-stream" { return native_openai_response { ok: true, status: 200, content_type: "text/event-stream", body: native_openai_stream(request, result, true), error_code: "" } }
    if route_kind == "openai-completion-stream" { return native_openai_response { ok: true, status: 200, content_type: "text/event-stream", body: native_openai_stream(request, result, false), error_code: "" } }
    native_openai_response { ok: false, status: 404, content_type: "application/json", body: openai_error_json("route not found", "not_found", 404), error_code: "not_found" }
}
