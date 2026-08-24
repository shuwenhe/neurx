package neurx.backends.cpu.reference_inference
use neurx.backends.api.inference_backend.{backend_generation_result, backend_generation_success, backend_generation_failure}

func cpu_reference_generate(string model, string prompt, int max_tokens) backend_generation_result {
    if model == "" { return backend_generation_failure("cpu-reference", "model_not_loaded", "model is required") }
    if prompt == "" { return backend_generation_failure("cpu-reference", "empty_prompt", "prompt is required") }
    if max_tokens <= 0 { return backend_generation_failure("cpu-reference", "invalid_token_limit", "max_tokens must be positive") }

    int limit = len(prompt)
    if limit > max_tokens { limit = max_tokens }
    string output = ""
    int i = 0
    while i < limit {
        output = output + string(prompt[i])
        i = i + 1
    }
    backend_generation_success(output, "cpu-reference")
}
