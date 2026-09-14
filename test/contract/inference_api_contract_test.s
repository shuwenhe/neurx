package main
import (
    "neurx.inference.api.contracts."
)

func main() {
    inference_request request = inference_request {
        request_id: "contract-inference-1",
        model: "fixture-model",
        prompt: "hello",
        max_tokens: 16,
        timeout_ms: 30000,
        stream: true,
    }
    inference_validation_result result = validate_inference_request(request)
    if !result.valid {
        println("FAIL inference API contract: " + result.error_code)
        return 1
    }
    request.max_tokens = 0
    result = validate_inference_request(request)
    if result.valid || result.error_code != "invalid_max_tokens" {
        println("FAIL inference API rejected-invalid contract")
        return 1
    }
    println("PASS inference API contract")
    0
}
