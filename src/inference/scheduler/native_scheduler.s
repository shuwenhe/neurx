package neurx.inference.scheduler.native_scheduler
struct native_schedule_decision {
    bool accepted
    string request_id
    int token_budget
    string error_code
}
func schedule_native_request(string request_id, int max_tokens, int capacity, int active_requests) native_schedule_decision {
    if active_requests >= capacity {
        return native_schedule_decision { accepted: false, request_id: request_id, token_budget: 0, error_code: "capacity_exhausted" }
    }
    if max_tokens <= 0 {
        return native_schedule_decision { accepted: false, request_id: request_id, token_budget: 0, error_code: "invalid_token_limit" }
    }
    native_schedule_decision { accepted: true, request_id: request_id, token_budget: max_tokens, error_code: "" }
}
