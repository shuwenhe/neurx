package neurx.tests.sse_server_real_test
use neurx.inference.api.sse_server.{
    sse_server_config,
    sse_session,
    generation_callback_state,
    new_sse_server_config,
    new_sse_session,
    new_generation_callback_state,
    next_token,
    current_token,
    non_stream_response,
    route_request,
    split_to_tokens,
    sse_header,
    json_response_header,
    error_response,
}
use neurx.inference.api.http_server.{http_request, http_response}
use neurx.inference.api.openai_protocol.{openai_chat_chunk, openai_done_event}
func expect(bool cond, string name) int {
    if cond {
        println("PASS " + name)
        return 0
    }
    println("FAIL " + name)
    1
}

func test_split_to_tokens() int {
    []string toks = split_to_tokens("hi there")
    int fail = 0
    fail = fail + expect(len(toks) == 3, "split returns 3 tokens for 'hi there'")
    fail = fail + expect(toks[0] == "hi", "first token is hi")
    fail = fail + expect(toks[1] == " ", "second token is space")
    fail = fail + expect(toks[2] == "there", "third token is there")
    fail
}

func test_generation_callback_cursor() int {
    []string toks = []string{"hello", " ", "world"}
    generation_callback_state gen = new_generation_callback_state(toks)
    int fail = 0
    gen = next_token(gen)
    fail = fail + expect(current_token(gen) == "hello", "first token is hello")
    gen = next_token(gen)
    fail = fail + expect(current_token(gen) == " ", "second token is space")
    gen = next_token(gen)
    fail = fail + expect(current_token(gen) == "world", "third token is world")
    gen = next_token(gen)
    fail = fail + expect(gen.done, "gen done after all tokens")
    fail
}

func test_non_stream_response_shape() int {
    sse_session session = new_sse_session("req-1", "neurx-glm", false, 16)
    []string toks = []string{"x", "y"}
    generation_callback_state gen = new_generation_callback_state(toks)
    session.tokens_sent = 2
    string body = non_stream_response(session, gen)
    int fail = 0
    fail = fail + expect(body != "", "non-stream body non-empty")
    fail = fail + expect(string_contains(body, "chat.completion"), "body has chat.completion object")
    fail = fail + expect(string_contains(body, "xy"), "body contains concatenated content xy")
    fail = fail + expect(string_contains(body, "stop"), "body has finish_reason stop")
    fail
}

func test_route_chat_non_stream() int {
    sse_server_config cfg = new_sse_server_config("127.0.0.1", 0, "neurx-glm")
    http_request req = http_request{
        method: "POST",
        path: "/v1/chat/completions",
        headers: []string{},
        body: "{\"model\":\"neurx-glm\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4,\"stream\":false}",
    }
    http_response resp = route_request(req, cfg)
    int fail = 0
    fail = fail + expect(resp.status_code == 200, "non-stream chat returns 200")
    fail = fail + expect(string_contains(resp.body, "chat.completion"), "non-stream body has chat.completion")
    fail
}

func test_route_chat_stream() int {
    sse_server_config cfg = new_sse_server_config("127.0.0.1", 0, "neurx-glm")
    http_request req = http_request{
        method: "POST",
        path: "/v1/chat/completions",
        headers: []string{},
        body: "{\"model\":\"neurx-glm\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"stream\":true}",
    }
    http_response resp = route_request(req, cfg)
    int fail = 0
    fail = fail + expect(resp.status_code == 200, "stream chat returns 200")
    fail = fail + expect(string_contains(resp.body, "stream served"), "stream path indicates served")
    fail
}

func test_route_invalid_model() int {
    sse_server_config cfg = new_sse_server_config("127.0.0.1", 0, "neurx-glm")
    http_request req = http_request{
        method: "POST",
        path: "/v1/chat/completions",
        headers: []string{},
        body: "{\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}",
    }
    http_response resp = route_request(req, cfg)
    int fail = 0
    fail = fail + expect(resp.status_code == 400, "missing model returns 400")
    fail = fail + expect(string_contains(resp.body, "error"), "error body present")
    fail
}

func test_route_health_and_models() int {
    sse_server_config cfg = new_sse_server_config("0.0.0.0", 8080, "neurx-glm")
    http_request health_req = http_request{method: "GET", path: "/health", headers: []string{}, body: ""}
    http_response health_resp = route_request(health_req, cfg)
    int fail = 0
    fail = fail + expect(health_resp.status_code == 200, "health returns 200")
    fail = fail + expect(string_contains(health_resp.body, "ok"), "health body says ok")
    http_request models_req = http_request{method: "GET", path: "/v1/models", headers: []string{}, body: ""}
    http_response models_resp = route_request(models_req, cfg)
    fail = fail + expect(models_resp.status_code == 200, "models returns 200")
    fail = fail + expect(string_contains(models_resp.body, "neurx-glm"), "models body lists neurx-glm")
    fail
}

func test_openai_chunk_format() int {
    string chunk = openai_chat_chunk("req-1", "neurx-glm", "hello", "")
    int fail = 0
    fail = fail + expect(string_starts_with(chunk, "data: "), "chunk starts with SSE data prefix")
    fail = fail + expect(string_contains(chunk, "chat.completion.chunk"), "chunk has chat.completion.chunk object")
    fail = fail + expect(string_contains(chunk, "hello"), "chunk contains delta content")
    fail = fail + expect(string_contains(chunk, "\"finish_reason\":null"), "chunk has null finish_reason when empty")
    string done = openai_done_event()
    fail = fail + expect(string_contains(done, "[DONE]"), "done event contains [DONE]")
    fail
}

func string_contains(string text, string pattern) bool {
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

func string_starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if text[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func main() {
    int fail = 0
    fail = fail + test_split_to_tokens()
    fail = fail + test_generation_callback_cursor()
    fail = fail + test_non_stream_response_shape()
    fail = fail + test_route_chat_non_stream()
    fail = fail + test_route_chat_stream()
    fail = fail + test_route_invalid_model()
    fail = fail + test_route_health_and_models()
    fail = fail + test_openai_chunk_format()
    if fail == 0 {
        println("PASS sse server real path")
        return 0
    }
    println("FAIL sse server real path")
    1
}
