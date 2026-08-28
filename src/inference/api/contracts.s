package neurx.inference.api.contracts
struct inference_request {
    string request_id
    string model
    string prompt
    int max_tokens
    int timeout_ms
    bool stream
}
struct inference_validation_result {
    bool valid
    string error_code
    string error_message
}
func valid_inference_request() inference_validation_result {
    inference_validation_result { valid: true, error_code: "", error_message: "" }
}
func invalid_inference_request(string code, string message) inference_validation_result {
    inference_validation_result { valid: false, error_code: code, error_message: message }
}
func validate_inference_request(inference_request request) inference_validation_result {
    if request.request_id == "" {
        return invalid_inference_request("missing_request_id", "request_id is required")
    }
    if request.model == "" {
        return invalid_inference_request("missing_model", "model is required")
    }
    if request.prompt == "" {
        return invalid_inference_request("missing_prompt", "prompt is required")
    }
    if request.max_tokens <= 0 {
        return invalid_inference_request("invalid_max_tokens", "max_tokens must be positive")
    }
    if request.timeout_ms <= 0 {
        return invalid_inference_request("invalid_timeout", "timeout_ms must be positive")
    }
    valid_inference_request()
}
