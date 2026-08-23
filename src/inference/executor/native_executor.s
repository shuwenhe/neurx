package neurx.inference.executor.native_executor
use neurx.backends.api.inference_backend.{backend_generation_result}
use neurx.backends.cpu.reference_inference.{cpu_reference_generate}
use neurx.inference.scheduler.native_scheduler.{native_schedule_decision, schedule_native_request}

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
    backend_generation_result generated = cpu_reference_generate(model, prompt, decision.token_budget)
    native_execution_result {
        ok: generated.ok,
        request_id: request_id,
        output: generated.output,
        backend: generated.backend,
        error_code: generated.error_code,
        error_message: generated.error_message,
    }
}
