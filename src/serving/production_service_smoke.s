package main

use neurx.serving.runtime.production_runtime.{new_production_runtime_config}
use neurx.serving.runtime.production_service.{
    new_production_service_state,
    new_production_service_request,
    production_service_submit_request,
    production_service_next_batch,
    production_service_complete_prefill,
    production_service_complete_decode,
    production_service_render_chunk,
    production_service_render_done,
    production_service_render_error,
    production_service_active_requests,
}

func fail(string message) int {
    println("production-service FAIL " + message)
    1
}

func main() {
    production_runtime_config config = new_production_runtime_config(8, 128, 128, 8, 1, 4)
    state := new_production_service_state(config, "neurx")

    submit := new_production_service_request("req-1", "", "cuda", "bf16", 12, 0, 3, true)
    result := production_service_submit_request(state, submit)
    if !result.accepted || result.status != "accepted" { return fail("admission") }
    if production_service_active_requests(result.state) != 1 { return fail("active-requests") }
    if result.sse_frame == "" { return fail("stream-init") }

    scheduled := production_service_next_batch(result.state)
    if !scheduled.batch.ok || scheduled.batch.phase != "prefill" { return fail("first-batch") }
    state = production_service_complete_prefill(scheduled.state, scheduled.batch, true)
    scheduled = production_service_next_batch(state)
    if !scheduled.batch.ok || scheduled.batch.phase != "decode" { return fail("decode-batch") }
    []bool eos = []bool{cap: 1}
    eos[0] = true
    state = production_service_complete_decode(scheduled.state, scheduled.batch, eos, true)
    if production_service_active_requests(state) != 0 { return fail("drain") }
    if production_service_render_chunk("req-1", "neurx", 1, "hello", "") == "" { return fail("chunk-render") }
    if production_service_render_done() != "data: [DONE]\n\n" { return fail("done-render") }
    if production_service_render_error("busy", "overloaded", 429) == "" { return fail("error-render") }
    println("production-service PASS requests=1 batches=" + string(state.total_batches) + " chunks=" + string(state.total_chunks))
    0
}
