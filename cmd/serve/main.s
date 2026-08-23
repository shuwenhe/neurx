package main
use neurx.runtime.command.{runtime_env_get, runtime_parse_int}
use neurx.inference.api.contracts.{inference_request}
use neurx.inference.executor.native_executor.{native_execution_result}
use neurx.serving.api.contracts.{serving_config, serving_validation_result, validate_serving_config}
use neurx.serving.lifecycle.native_inference_service.{serve_native_inference}
use neurx.serving.api.native_openai.{native_openai_response, serve_native_openai}

func main() {
    serving_config config = serving_config {
        model: runtime_env_get("NEURX_MODEL", ""),
        bind_address: runtime_env_get("NEURX_BIND_ADDRESS", "localhost"),
        port: runtime_parse_int(runtime_env_get("NEURX_PORT", "8000"), 8000),
        max_concurrency: runtime_parse_int(runtime_env_get("NEURX_MAX_CONCURRENCY", "128"), 128),
        request_timeout_ms: runtime_parse_int(runtime_env_get("NEURX_REQUEST_TIMEOUT_MS", "30000"), 30000),
        shutdown_grace_ms: runtime_parse_int(runtime_env_get("NEURX_SHUTDOWN_GRACE_MS", "30000"), 30000),
    }
    serving_validation_result validation = validate_serving_config(config)
    if !validation.valid {
        println("[neurx-serve] invalid configuration: " + validation.error_code + ": " + validation.error_message)
        return 2
    }
    string prompt = runtime_env_get("NEURX_PROMPT", "")
    if prompt == "" {
        println("[neurx-serve] NEURX_PROMPT is required for native one-shot inference")
        return 3
    }
    inference_request request = inference_request {
        request_id: runtime_env_get("NEURX_REQUEST_ID", "native-1"),
        model: config.model,
        prompt: prompt,
        max_tokens: runtime_parse_int(runtime_env_get("NEURX_MAX_TOKENS", "128"), 128),
        timeout_ms: config.request_timeout_ms,
        stream: runtime_env_get("NEURX_STREAM", "false") == "true",
    }
    string route = runtime_env_get("NEURX_ROUTE", "native")
    if route != "native" {
        native_openai_response response = serve_native_openai(request, route, config.max_concurrency, 0)
        if !response.ok { println(response.body); return 4 }
        println(response.body)
        return 0
    }
    native_execution_result result = serve_native_inference(request, config.max_concurrency, 0)
    if !result.ok {
        println("[neurx-serve] inference failed: " + result.error_code + ": " + result.error_message)
        return 4
    }
    println(result.output)
    0
}
