package neurx.serving.api.contracts
struct serving_config {
    string model
    string bind_address
    int port
    int max_concurrency
    int request_timeout_ms
    int shutdown_grace_ms
}

struct serving_validation_result {
    bool valid
    string error_code
    string error_message
}

func invalid_serving_config(string code, string message) serving_validation_result {
    serving_validation_result { valid: false, error_code: code, error_message: message }
}

func validate_serving_config(serving_config config) serving_validation_result {
    if config.model == "" { return invalid_serving_config("missing_model", "model is required") }
    if config.bind_address == "" { return invalid_serving_config("missing_bind_address", "bind address is required") }
    if config.port <= 0 || config.port > 65535 { return invalid_serving_config("invalid_port", "port is outside the valid range") }
    if config.max_concurrency <= 0 { return invalid_serving_config("invalid_concurrency", "max concurrency must be positive") }
    if config.request_timeout_ms <= 0 { return invalid_serving_config("invalid_timeout", "request timeout must be positive") }
    if config.shutdown_grace_ms < 0 { return invalid_serving_config("invalid_shutdown_grace", "shutdown grace must not be negative") }
    serving_validation_result { valid: true, error_code: "", error_message: "" }
}
