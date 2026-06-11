package neurx.test_serving_runtime

use neurx.serving.serve

func main() int {
    serving_runtime_state state = new_serving_runtime_state(2, 128, 2, 2, 16, 4, 16, 128, "srpt")

    state = serving_runtime_submit_request(state, "req-1", 12, 20)
    if state.accepted_requests != 1 {
        println("first request should be accepted")
        1
    }
    if serving_runtime_active_requests(state) != 1 {
        println("active request count should be 1")
        1
    }
    if serving_runtime_queue_depth(state) != 1 {
        println("queue depth should be 1 after first enqueue")
        1
    }

    state = serving_runtime_submit_request(state, "req-2", 8, 5)
    if state.accepted_requests != 2 {
        println("second request should be accepted")
        1
    }
    if serving_runtime_queue_depth(state) != 2 {
        println("queue depth should be 2 after second enqueue")
        1
    }

    state = serving_runtime_schedule_next(state)
    if serving_runtime_last_selected_request(state) != "req-2" {
        println("srpt scheduler should select req-2 first")
        1
    }
    if state.last_status != 202 {
        println("schedule status should be 202")
        1
    }

    state = serving_runtime_record_decode(state, 1)
    if state.vllm.metrics.decode_tokens != 1 {
        println("decode token accounting failed")
        1
    }

    state = serving_runtime_finish_request(state, 12)
    if state.finished_requests != 1 {
        println("finish accounting failed")
        1
    }
    if serving_runtime_active_requests(state) != 1 {
        println("active request count should drop after finish")
        1
    }
    if state.last_status != 200 {
        println("finish status should be 200")
        1
    }

    println("serving runtime test passed")
    0
}
