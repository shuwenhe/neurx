package neurx.inference.executor.native_executor
use neurx.backends.api.inference_backend.{backend_generation_result}
use neurx.backends.cpu.reference_inference.{cpu_reference_generate}
use neurx.backends.cpu.transformer_decode.{cpu_transformer_result, cpu_transformer_prefill_decode}
use neurx.inference.scheduler.native_scheduler.{native_schedule_decision, schedule_native_request}
use neurx.inference.tokenizer.byte_tokenizer.{byte_tokenization_result, tokenize_bytes}
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, load_f32_embedding}

struct native_execution_result {
    bool ok
    string request_id
    string output
    string backend
    string error_code
    string error_message
}

func execute_native_request(string request_id, string model, string prompt, int max_tokens, int capacity, int active_requests) native_execution_result {
    native_schedule_decision decision = schedule_native_request(request_id, max_tokens, capacity, active_requests)
    if !decision.accepted {
        return native_execution_result { ok: false, request_id: request_id, output: "", backend: "", error_code: decision.error_code, error_message: "request was rejected by the scheduler" }
    }
    backend_generation_result generated = cpu_reference_generate("", "", 0)
    if model == "reference-model" {
        generated = cpu_reference_generate(model, prompt, decision.token_budget)
    } else {
        safetensors_embedding embedding = load_f32_embedding(model, "embedding.weight")
        if !embedding.valid {
            return native_execution_result { ok: false, request_id: request_id, output: "", backend: "cpu-prefill", error_code: embedding.error_code, error_message: "failed to load embedding model" }
        }
        byte_tokenization_result tokens = tokenize_bytes(prompt, embedding.rows, decision.token_budget)
        if !tokens.ok {
            return native_execution_result { ok: false, request_id: request_id, output: "", backend: "cpu-prefill", error_code: tokens.error_code, error_message: "tokenization failed" }
        }
        cpu_transformer_result transformed = cpu_transformer_prefill_decode(embedding, tokens.token_ids, decision.token_budget)
        if !transformed.ok {
            return native_execution_result { ok: false, request_id: request_id, output: "", backend: "cpu-transformer", error_code: transformed.error_code, error_message: "transformer prefill or decode failed" }
        }
        string token_text = "many"
        if transformed.next_token == 0 { token_text = "0" }
        if transformed.next_token == 1 { token_text = "1" }
        if transformed.next_token == 2 { token_text = "2" }
        if transformed.next_token == 3 { token_text = "3" }
        generated = backend_generation_result { ok: true, output: "token:" + token_text, backend: "cpu-transformer", error_code: "", error_message: "" }
    }
    native_execution_result {
        ok: generated.ok,
        request_id: request_id,
        output: generated.output,
        backend: generated.backend,
        error_code: generated.error_code,
        error_message: generated.error_message,
    }
}
