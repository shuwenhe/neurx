struct speculative_decode_runtime {
    draft_executor: draft_model_executor
    verifier_executor: verifier_executor
    decode_config: speculative_decode_config
    batch_size: int
    max_batch_tokens: int
    statistics: speculative_statistics
    request_queue: []int
}
struct speculative_generation_request {
    request_id: int
    input_ids: []int
    max_tokens: int
    temperature: float
    top_k: int
    top_p: float
    output_tokens: []int
    is_complete: bool
}
struct speculative_generation_batch {
    batch_requests: []speculative_generation_request
    draft_predictions: [][]draft_token
    verification_results: [][]verification_result
    final_outputs: [][]int
    batch_generation_time_ms: float
}
struct speculative_decode_context {
    sequence_length: int
    cached_hidden_states: [][]float
    kv_cache: [][]float
    is_prefill_stage: bool
    speculative_tokens_accepted: int
    speculative_tokens_rejected: int
}
func new_speculative_decode_runtime(draft_exec: draft_model_executor, verifier_exec: verifier_executor, config: speculative_decode_config) speculative_decode_runtime {
    runtime := speculative_decode_runtime{
        draft_executor: draft_exec,
        verifier_executor: verifier_exec,
        decode_config: config,
        batch_size: 32,
        max_batch_tokens: 4096,
        statistics: new_speculative_statistics(),
        request_queue: []int{},
    }
    runtime
}
func new_generation_request(req_id: int, input_ids: []int, max_tokens: int) speculative_generation_request {
    req := speculative_generation_request{
        request_id: req_id,
        input_ids: input_ids,
        max_tokens: max_tokens,
        temperature: 0.7,
        top_k: 50,
        top_p: 0.95,
        output_tokens: []int{},
        is_complete: false,
    }
    req
}
func new_generation_batch() speculative_generation_batch {
    batch := speculative_generation_batch{
        batch_requests: []speculative_generation_request{},
        draft_predictions: [][]draft_token{},
        verification_results: [][]verification_result{},
        final_outputs: [][]int{},
        batch_generation_time_ms: 0.0,
    }
    batch
}
func new_decode_context() speculative_decode_context {
    ctx := speculative_decode_context{
        sequence_length: 0,
        cached_hidden_states: [][]float{},
        kv_cache: [][]float{},
        is_prefill_stage: true,
        speculative_tokens_accepted: 0,
        speculative_tokens_rejected: 0,
    }
    ctx
}
func queue_generation_request(runtime: speculative_decode_runtime, request: speculative_generation_request) speculative_decode_runtime {
    updated := runtime
    updated.request_queue = append(updated.request_queue, request.request_id)
    updated
}
func dequeue_generation_request(runtime: speculative_decode_runtime) (speculative_decode_runtime, int) {
    updated := runtime
    req_id := -1
    if updated.request_queue.len > 0 {
        req_id = updated.request_queue[0]
        new_queue := []int{}
        i := 1
        while i < updated.request_queue.len {
            new_queue = append(new_queue, updated.request_queue[i])
            i = i + 1
        }
        updated.request_queue = new_queue
    }
    (updated, req_id)
}
func speculative_prefill_phase(runtime: speculative_decode_runtime, request: speculative_generation_request) ([]draft_token, []verification_result) {
    draft_preds := draft_predict_batch(runtime.draft_executor, request.input_ids, runtime.decode_config)
    verify_results := verify_draft_sequence(runtime.verifier_executor, draft_preds)
    (draft_preds, verify_results)
}
func speculative_decode_phase(runtime: speculative_decode_runtime, current_token_id: int, context: speculative_decode_context) ([]draft_token, []verification_result, []int) {
    draft_preds := draft_predict_batch(runtime.draft_executor, []int{current_token_id}, runtime.decode_config)
    verify_results := verify_draft_sequence(runtime.verifier_executor, draft_preds)
    output_tokens := []int{}
    i := 0
    while i < verify_results.len {
        if verify_results[i].accepted {
            output_tokens = append(output_tokens, draft_preds[i].token_id)
            context.speculative_tokens_accepted = context.speculative_tokens_accepted + 1
        } else {
            output_tokens = append(output_tokens, verify_results[i].fallback_token_id)
            context.speculative_tokens_rejected = context.speculative_tokens_rejected + 1
        }
        i = i + 1
    }
    (draft_preds, verify_results, output_tokens)
}
func process_speculative_batch(runtime: speculative_decode_runtime, batch: speculative_generation_batch) (speculative_decode_runtime, speculative_generation_batch) {
    updated_runtime := runtime
    updated_batch := batch
    i := 0
    while i < batch.batch_requests.len {
        request := batch.batch_requests[i]
        prefill_drafts, prefill_verifies := speculative_prefill_phase(updated_runtime, request)
        updated_batch.draft_predictions = append(updated_batch.draft_predictions, prefill_drafts)
        updated_batch.verification_results = append(updated_batch.verification_results, prefill_verifies)
        accepted_count := 0
        j := 0
        while j < prefill_verifies.len {
            if prefill_verifies[j].accepted {
                accepted_count = accepted_count + 1
            }
            j = j + 1
        }
        output := []int{}
        j = 0
        while j < prefill_verifies.len {
            if prefill_verifies[j].accepted {
                output = append(output, prefill_drafts[j].token_id)
            } else {
                output = append(output, prefill_verifies[j].fallback_token_id)
            }
            j = j + 1
        }
        updated_batch.final_outputs = append(updated_batch.final_outputs, output)
        i = i + 1
    }
    (updated_runtime, updated_batch)
}
func generate_with_speculative_decoding(runtime: speculative_decode_runtime, request: speculative_generation_request) (speculative_decode_runtime, []int) {
    updated_runtime := runtime
    output_tokens := request.input_ids
    token_count := 0
    while token_count < request.max_tokens {
        if output_tokens.len == 0 {
            break
        }
        last_token := output_tokens[output_tokens.len - 1]
        context := new_decode_context()
        context.sequence_length = output_tokens.len
        draft_preds, verify_results, decoded_tokens := speculative_decode_phase(updated_runtime, last_token, context)
        if decoded_tokens.len > 0 {
            j := 0
            while j < decoded_tokens.len {
                output_tokens = append(output_tokens, decoded_tokens[j])
                token_count = token_count + 1
                j = j + 1
            }
        } else {
            break
        }
        verify_batch := speculative_batch{
            batch_id: 0,
            sequence_ids: []int{request.request_id},
            draft_predictions: [][]draft_token{draft_preds},
            verification_results: verify_results,
            acceptance_rate: compute_acceptance_rate(verify_results),
            draft_time_ms: 1.0,
            verify_time_ms: 3.0,
        }
        updated_runtime.statistics = update_statistics(updated_runtime.statistics, verify_batch)
    }
    (updated_runtime, output_tokens)
}
func adaptive_num_draft_tokens(runtime: speculative_decode_runtime, current_acceptance_rate: float) int {
    if current_acceptance_rate > 0.9 {
        if runtime.decode_config.num_draft_tokens < 16 {
            return runtime.decode_config.num_draft_tokens + 1
        }
    } else if current_acceptance_rate < 0.7 {
        if runtime.decode_config.num_draft_tokens > 2 {
            return runtime.decode_config.num_draft_tokens - 1
        }
    }
    runtime.decode_config.num_draft_tokens
}
func compute_generation_speedup(runtime: speculative_decode_runtime, original_time_ms: float, speculative_time_ms: float) float {
    if speculative_time_ms > 0.0 {
        original_time_ms / speculative_time_ms
    } else {
        1.0
    }
}
func get_runtime_stats(runtime: speculative_decode_runtime) string {
    result := "Speculative Decode Runtime Stats:"
    result = result + " TotalTokens=" + (runtime.statistics.total_tokens_generated as string)
    result = result + " DraftTokens=" + (runtime.statistics.total_draft_tokens as string)
    result = result + " VerifiedTokens=" + (runtime.statistics.total_verified_tokens as string)
    result = result + " AcceptedTokens=" + (runtime.statistics.total_accepted_tokens as string)
    acceptance_rate := get_acceptance_rate(runtime.statistics)
    result = result + " AcceptanceRate=" + (acceptance_rate as string)
    speedup := get_speedup_factor(runtime.statistics)
    result = result + " Speedup=" + (speedup as string) + "x"
    result
}
func reset_runtime_statistics(runtime: speculative_decode_runtime) speculative_decode_runtime {
    updated := runtime
    updated.statistics = new_speculative_statistics()
    updated
}
