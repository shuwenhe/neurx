package main
use neurx.inference.api.contracts.{inference_request}
use neurx.inference.executor.native_executor.{native_execution_result}
use neurx.serving.lifecycle.native_inference_service.{serve_native_inference}

func main() {
    inference_request request = inference_request {
        request_id: "native-contract-1",
        model: "reference-model",
        prompt: "industrial",
        max_tokens: 5,
        timeout_ms: 30000,
        stream: false,
    }
    native_execution_result result = serve_native_inference(request, 4, 0)
    if !result.ok || result.output != "indus" || result.backend != "cpu-reference" { return 1 }
    result = serve_native_inference(request, 1, 1)
    if result.ok || result.error_code != "capacity_exhausted" { return 1 }
    request.prompt = ""
    result = serve_native_inference(request, 4, 0)
    if result.ok || result.error_code != "missing_prompt" { return 1 }
    println("PASS native inference pipeline contract")
    0
}
