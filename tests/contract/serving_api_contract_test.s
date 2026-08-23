package main
use neurx.serving.api.contracts.{serving_config, serving_validation_result, validate_serving_config}

func main() {
    serving_config config = serving_config {
        model: "fixture-model",
        bind_address: "localhost",
        port: 8000,
        max_concurrency: 16,
        request_timeout_ms: 30000,
        shutdown_grace_ms: 30000,
    }
    serving_validation_result result = validate_serving_config(config)
    if !result.valid { return 1 }
    config.port = 70000
    result = validate_serving_config(config)
    if result.valid || result.error_code != "invalid_port" { return 1 }
    println("PASS serving API contract")
    0
}
