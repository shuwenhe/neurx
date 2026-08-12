package neurx.scheduler.inference_vllm_scheduler
use neurx.inference.vllm.request_queue
struct vllm_scheduler_state {
    string strategy
    int tick
    int running_requests
    int preemptions
    int last_queue_depth
    string last_selected_request
    int last_selected_remaining
}

struct vllm_schedule_result {
    vllm_scheduler_state scheduler
    vllm_request_queue_state queue
    string request_id
    int prefill_tokens
    int remaining_tokens
    bool selected
}

func vllm_normalize_strategy(string strategy) string {
    if strategy == "srpt" {
        return "srpt"
    }
    "fcfs"
}

func new_vllm_scheduler_state(string strategy) vllm_scheduler_state {
    vllm_scheduler_state {
        strategy: vllm_normalize_strategy(strategy),
        tick: 0,
        running_requests: 0,
        preemptions: 0,
        last_queue_depth: 0,
        last_selected_request: "",
        last_selected_remaining: 0,
    }
}

func vllm_scheduler_next(vllm_scheduler_state state, vllm_request_queue_state queue) vllm_schedule_result {
    int queue_depth = vllm_queue_size(queue)
    if queue_depth <= 0 {
        return vllm_schedule_result {
            scheduler: vllm_scheduler_state {
                strategy: state.strategy,
                tick: state.tick + 1,
                running_requests: state.running_requests,
                preemptions: state.preemptions,
                last_queue_depth: 0,
                last_selected_request: "",
                last_selected_remaining: 0,
            },
            queue: queue,
            request_id: "",
            prefill_tokens: 0,
            remaining_tokens: 0,
            selected: false,
        }
    }
    vllm_queue_pop_result popped = vllm_queue_pop_front(queue)
    if state.strategy == "srpt" {
        popped = vllm_queue_pop_shortest(queue)
    }
    int preemptions = state.preemptions
    if state.strategy == "srpt" && state.running_requests > 0 {
        preemptions = preemptions + 1
    }
    vllm_schedule_result {
        scheduler: vllm_scheduler_state {
            strategy: state.strategy,
            tick: state.tick + 1,
            running_requests: state.running_requests + 1,
            preemptions: preemptions,
            last_queue_depth: queue_depth,
            last_selected_request: popped.request_id,
            last_selected_remaining: popped.remaining_tokens,
        },
        queue: popped.state,
        request_id: popped.request_id,
        prefill_tokens: popped.prefill_tokens,
        remaining_tokens: popped.remaining_tokens,
        selected: popped.ok,
    }
}

func vllm_scheduler_on_finish(vllm_scheduler_state state) vllm_scheduler_state {
    int next_running = state.running_requests
    if next_running > 0 {
        next_running = next_running - 1
    }
    vllm_scheduler_state {
        strategy: state.strategy,
        tick: state.tick,
        running_requests: next_running,
        preemptions: state.preemptions,
        last_queue_depth: state.last_queue_depth,
        last_selected_request: state.last_selected_request,
        last_selected_remaining: state.last_selected_remaining,
    }
}

func vllm_scheduler_state_dict(vllm_scheduler_state state) vllm_scheduler_state {
    state
}

func vllm_scheduler_load_state_dict(vllm_scheduler_state state, vllm_scheduler_state other) vllm_scheduler_state {
    other
}

