package neurx.inference.executor.native_executor
use neurx.backends.api.inference_backend.{backend_generation_result}
use neurx.backends.cpu.reference_inference.{cpu_reference_generate}
use neurx.backends.cpu.embedding_prefill.{cpu_embedding_prefill}
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
        generated = cpu_embedding_prefill(embedding, tokens.token_ids)
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
