package neurx.backends.api.inference_backend

struct backend_generation_result {
    bool ok
    string output
    string backend
    string error_code
    string error_message
}

func backend_generation_success(string output, string backend) backend_generation_result {
    backend_generation_result { ok: true, output: output, backend: backend, error_code: "", error_message: "" }
}

func backend_generation_failure(string backend, string code, string message) backend_generation_result {
    backend_generation_result { ok: false, output: "", backend: backend, error_code: code, error_message: message }
}
