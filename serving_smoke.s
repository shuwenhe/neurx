package main

use neurx.serving.serve.{new_serving_runtime_state, serving_runtime_submit_request, serving_runtime_schedule_next, serving_runtime_record_decode, serving_runtime_finish_request, serving_runtime_active_requests, serving_runtime_queue_depth, serving_runtime_last_selected_request, serving_runtime_cache_hits, serving_runtime_cache_misses}

func main() int {
    serving_runtime_state state = new_serving_runtime_state(4, 128, 4, 8, 16, 16, 64, 1024, "srpt")

    println("serving smoke test")
    println("active_requests=" + string(serving_runtime_active_requests(state)))
    println("queue_depth=" + string(serving_runtime_queue_depth(state)))

    state = serving_runtime_submit_request(state, "req-1", 32, 16)
    state = serving_runtime_submit_request(state, "req-2", 24, 12)
    println("accepted_after_submit=" + string(state.accepted_requests))
    println("rejected_after_submit=" + string(state.rejected_requests))
    println("active_after_submit=" + string(serving_runtime_active_requests(state)))
    println("queue_after_submit=" + string(serving_runtime_queue_depth(state)))

    state = serving_runtime_schedule_next(state)
    println("last_status=" + string(state.last_status))
    println("selected_request=" + serving_runtime_last_selected_request(state))

    state = serving_runtime_record_decode(state, 8)
    state = serving_runtime_finish_request(state, 32)
    println("finished_requests=" + string(state.finished_requests))
    println("active_after_finish=" + string(serving_runtime_active_requests(state)))
    println("queue_after_finish=" + string(serving_runtime_queue_depth(state)))
    println("cache_hits=" + string(serving_runtime_cache_hits(state)))
    println("cache_misses=" + string(serving_runtime_cache_misses(state)))
    0
}
