package neurx.serving.lifecycle.native_inference_service
import (
    "neurx.inference.api.contracts."
    "neurx.inference.executor.native_executor."
)

func serve_native_inference(inference_request request, int capacity, int active_requests) native_execution_result {
    inference_validation_result validation = validate_inference_request(request)
    if !validation.valid {
        return native_execution_result { ok: false, request_id: request.request_id, output: "", token_ids: [], finish_reason: "error", backend: "", error_code: validation.error_code, error_message: validation.error_message }
    }
    execute_native_request(request.request_id, request.model, request.prompt, request.max_tokens, capacity, active_requests)
}
