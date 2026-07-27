package main
use neurx.serving.protocol.openai_tgi.{openai_chat_sse_chunk, openai_sse_done, openai_error_json, tgi_token_sse, serving_route_kind}
func fail(string message) int {
    println("serving-protocol FAIL " + message)
    1
}

func main() int {
    if serving_route_kind("POST", "/v1/chat/completions") != "openai-chat" { return fail("openai-route") }
    if serving_route_kind("POST", "/generate_stream") != "tgi-stream" { return fail("tgi-route") }
    if serving_route_kind("DELETE", "/v1/chat/completions") != "not-found" { return fail("method-check") }
    string chunk = openai_chat_sse_chunk("chatcmpl-1", "neurx", 1, "hello", "")
    string expected = "data: {\"id\":\"chatcmpl-1\",\"object\":\"chat.completion.chunk\",\"created\":1,\"model\":\"neurx\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"hello\"},\"finish_reason\":null}]}\n\n"
    if chunk != expected { return fail("openai-sse") }
    if openai_sse_done() != "data: [DONE]\n\n" { return fail("openai-done") }
    if tgi_token_sse(7, "x", false) == "" { return fail("tgi-sse") }
    if openai_error_json("busy", "overloaded", 429) == "" { return fail("error-json") }
    println("serving-protocol PASS openai=true tgi=true sse=true")
    0
}
