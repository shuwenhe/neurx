package main
use neurx.inference.api.contracts.{inference_request}
use neurx.inference.executor.native_executor.{native_execution_result, execute_native_request}
use neurx.inference.tokenizer.hf_bpe_tokenizer.{hf_bpe_tokenizer, load_hf_bpe_tokenizer}
use neurx.models.loaders.hf_transformer.{hf_model_weights, load_hf_model}
use neurx.serving.api.native_openai.{native_openai_response, serve_native_openai}

func contains(string text, string pattern) bool {
    int i = 0
    while i + len(pattern) <= len(text) {
        int j = 0
        bool same = true
        while j < len(pattern) { if text[i + j] != pattern[j] { same = false; j = len(pattern) } else { j = j + 1 } }
        if same { return true }
        i = i + 1
    }
    false
}

func main() {
    string model_dir = "artifacts/build/commands/native-test/hf-tiny"
    hf_model_weights model = load_hf_model(model_dir)
    hf_bpe_tokenizer tokenizer = load_hf_bpe_tokenizer(model_dir)
    println("e2e-check-load")
    println(model.valid)
    println(model.error_code)
    println(len(model.q_proj))
    println(len(model.k_proj))
    println(len(model.o_proj))
    println(tokenizer.valid)
    println(tokenizer.eos_id)
    if !model.valid || !tokenizer.valid || tokenizer.eos_id != 6 || !tokenizer.byte_level_trim_offsets { return 1 }
    native_execution_result generated = execute_native_request("e2e-1", model_dir, "Hi", 4, 4, 0)
    println("e2e-check-generate")
    println(generated.ok)
    println(generated.error_code)
    println(generated.finish_reason)
    println(len(generated.token_ids))
    if len(generated.token_ids) > 0 { println(generated.token_ids[0]) }
    if !generated.ok || generated.finish_reason != "stop" || len(generated.token_ids) != 1 || generated.token_ids[0] != 6 || generated.output != "" { return 1 }
    inference_request request = inference_request { request_id: "e2e-2", model: model_dir, prompt: "Hi", max_tokens: 4, timeout_ms: 30000, stream: false }
    native_openai_response chat = serve_native_openai(request, "openai-chat", 4, 0)
    if !chat.ok || !contains(chat.body, "\"object\":\"chat.completion\"") || !contains(chat.body, "\"finish_reason\":\"stop\"") { return 1 }
    request.stream = true
    native_openai_response stream = serve_native_openai(request, "openai-chat-stream", 4, 0)
    if !stream.ok || stream.content_type != "text/event-stream" || !contains(stream.body, "chat.completion.chunk") || !contains(stream.body, "data: [DONE]") { return 1 }
    println("PASS pure S HF load prefill decode EOS OpenAI SSE e2e")
    0
}
