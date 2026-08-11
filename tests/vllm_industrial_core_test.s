package main

use neurx.inference.cache.block_manager
use neurx.inference.scheduler.vllm_scheduler
use neurx.inference.runtime.engine_lifecycle

func test_block_manager_prefix_reuse() bool {
    block_manager_state state = neurx.inference.cache.block_manager.new_block_manager(8, 4, 1)
    block_allocation_result allocation = neurx.inference.cache.block_manager.block_manager_allocate(state, "request-1", 4, 0, true)
    if !allocation.success || len(allocation.new_block_ids) != 1 { return false }
    state = allocation.state
    state = neurx.inference.cache.block_manager.block_manager_mark_computed(state, "request-1", 4)
    state = neurx.inference.cache.block_manager.block_manager_cache_full_blocks(state, "request-1", ["prefix-1"])
    state = neurx.inference.cache.block_manager.block_manager_free_request(state, "request-1", false)
    prefix_match_result prefix = neurx.inference.cache.block_manager.block_manager_match_prefix(state, "request-2", ["prefix-1"])
    prefix.success && prefix.matched_blocks == 1 && prefix.matched_tokens == 4 && prefix.state.cache_hits == 1
}

func test_scheduler_budget() bool {
    vllm_scheduler_config config = neurx.inference.scheduler.vllm_scheduler.default_vllm_scheduler_config()
    config.max_scheduled_tokens = 4
    config.long_prefill_threshold = 4
    config.max_running_requests = 2
    vllm_scheduler_state state = neurx.inference.scheduler.vllm_scheduler.new_vllm_scheduler(config, 16, 4, 1)
    scheduler_update_result submitted = neurx.inference.scheduler.vllm_scheduler.scheduler_submit(state, "request-1", 12, 2, 0, [], "")
    if !submitted.success { return false }
    scheduler_step_result step = neurx.inference.scheduler.vllm_scheduler.scheduler_step(submitted.state)
    step.output.scheduled_tokens == 4 && step.output.token_budget_remaining == 0 && len(step.output.requests) == 1 && step.output.requests[0].prefill
}

func test_engine_sleep_wake() bool {
    engine_lifecycle_state state = neurx.inference.runtime.engine_lifecycle.new_engine_lifecycle(true, "cumem", true, true)
    engine_lifecycle_result registered = neurx.inference.runtime.engine_lifecycle.engine_register_segment(state, "model", "weights", 100, true, false, "model-v1")
    if !registered.accepted { return false }
    registered = neurx.inference.runtime.engine_lifecycle.engine_register_segment(registered.state, "kv", "kv_cache", 60, true, true, "")
    if !registered.accepted { return false }
    engine_lifecycle_result active = neurx.inference.runtime.engine_lifecycle.engine_begin_request(registered.state, "request-1")
    engine_lifecycle_result sleeping = neurx.inference.runtime.engine_lifecycle.engine_begin_sleep(active.state, 1, "abort")
    if !sleeping.accepted || len(sleeping.aborted_request_ids) != 1 || len(sleeping.transfers) != 2 { return false }
    engine_lifecycle_result slept = neurx.inference.runtime.engine_lifecycle.engine_commit_transition(sleeping.state, sleeping.transition_id, true, "")
    if !slept.accepted || slept.state.status != neurx.inference.runtime.engine_lifecycle.engine_asleep_status() || slept.state.host_bytes != 100 { return false }
    engine_lifecycle_result waking_weights = neurx.inference.runtime.engine_lifecycle.engine_begin_wake(slept.state, ["weights"])
    engine_lifecycle_result weights_ready = neurx.inference.runtime.engine_lifecycle.engine_commit_transition(waking_weights.state, waking_weights.transition_id, true, "")
    if weights_ready.state.status != neurx.inference.runtime.engine_lifecycle.engine_asleep_status() || weights_ready.state.device_bytes != 100 { return false }
    engine_lifecycle_result waking_kv = neurx.inference.runtime.engine_lifecycle.engine_begin_wake(weights_ready.state, ["kv_cache"])
    engine_lifecycle_result awake = neurx.inference.runtime.engine_lifecycle.engine_commit_transition(waking_kv.state, waking_kv.transition_id, true, "")
    awake.accepted && awake.state.status == neurx.inference.runtime.engine_lifecycle.engine_awake_status() && awake.state.device_bytes == 160
}

func main() {
    bool passed = test_block_manager_prefix_reuse()
    passed = passed && test_scheduler_budget()
    passed = passed && test_engine_sleep_wake()
    if passed {
        println("PASS vllm industrial core")
        return 0
    }
    println("FAIL vllm industrial core")
    1
}
