package main

use neurx.serving.runtime.production_runtime.{production_runtime_config, production_runtime_state, production_schedule_result, new_production_runtime_config, new_production_runtime_state, production_submit, production_schedule, production_complete_prefill, production_complete_decode, production_queue_size}

func fail(string message) int {
    println("production-serving FAIL " + message)
    1
}

func main() int {
    production_runtime_config config = new_production_runtime_config(8, 128, 128, 8, 1, 4)
    production_runtime_state state = new_production_runtime_state(config)
    state = production_submit(state, "cuda-long", "cuda", "bf16", 12, 0, 3)
    state = production_submit(state, "cuda-cached", "cuda", "fp8", 4, 4, 2)
    state = production_submit(state, "ascend-short", "ascend", "fp8", 4, 0, 2)
    if state.admitted_requests != 3 { return fail("admission") }

    production_schedule_result scheduled = production_schedule(state)
    if !scheduled.batch.ok || scheduled.batch.phase != "decode" { return fail("decode-priority") }
    if scheduled.batch.backend != "cuda" || scheduled.batch.dtype != "fp8" { return fail("cuda-batch-key") }
    []bool eos = []bool{cap: 1}
    eos[0] = true
    state = production_complete_decode(scheduled.state, scheduled.batch, eos, true)

    scheduled = production_schedule(state)
    if scheduled.batch.phase != "prefill" || scheduled.batch.total_tokens != 8 { return fail("chunked-prefill") }
    if scheduled.batch.backend != "cuda" || scheduled.batch.dtype != "bf16" { return fail("prefill-key") }
    state = production_complete_prefill(scheduled.state, scheduled.batch, true)

    scheduled = production_schedule(state)
    if scheduled.batch.backend != "ascend" || scheduled.batch.dtype != "bf16" { return fail("ascend-normalization") }
    state = production_complete_prefill(scheduled.state, scheduled.batch, true)
    scheduled = production_schedule(state)
    if scheduled.batch.phase != "decode" || scheduled.batch.backend != "ascend" { return fail("ascend-decode") }
    state = production_complete_decode(scheduled.state, scheduled.batch, eos, true)

    if state.completed_requests != 2 { return fail("completion-count") }
    if state.kv_handoffs != 2 { return fail("kv-handoff") }
    println("production-serving PASS admitted=" + string(state.admitted_requests) + " completed=" + string(state.completed_requests) + " prefill_tokens=" + string(state.prefill_tokens) + " decode_tokens=" + string(state.decode_tokens))
    0
}
