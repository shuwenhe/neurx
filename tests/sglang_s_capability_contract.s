package neurx.tests.sglang_s_capability_contract
use neurx.serving.router.cache_aware_router.{cache_aware_router_config, cache_aware_router_state, cache_route_result, cache_route_affinity, cache_route_load, new_cache_aware_router, cache_router_register_worker, cache_router_set_worker, cache_router_route, cache_router_complete}
use neurx.serving.router.circuit_breaker.{circuit_breaker_config, circuit_breaker_state, circuit_admission_result, circuit_closed, circuit_open, circuit_half_open, new_circuit_breaker, circuit_try_acquire, circuit_record_success, circuit_record_failure}
use neurx.inference.speculative.jump_forward_decoder.{jump_forward_fsm, jump_forward_result, new_jump_forward_fsm, jump_forward_add_edge, jump_forward_add_final, jump_forward_try}
use neurx.inference.cache.hicache_controller.{hicache_config, hicache_state, hicache_action_result, hicache_prefix_result, hicache_write_back, hicache_write_through, hicache_action_device_to_host, hicache_action_host_to_storage, hicache_action_storage_to_host, new_hicache, hicache_admit_device_page, hicache_set_page_residency, hicache_set_lock_refs, hicache_prepare_backup, hicache_complete_backup, hicache_prepare_storage_write, hicache_complete_storage_write, hicache_prefetch_timeout_ms, hicache_prepare_prefetch, hicache_complete_prefetch, hicache_match_prefix}
use neurx.inference.scheduler.two_batch_overlap.{tbo_config, tbo_plan, tbo_stage_schedule, tbo_mode_extend, tbo_mode_decode, tbo_make_plan, tbo_schedule_stages}
use neurx.inference.llm.streaming_session.{streaming_session_config, streaming_session_state, session_update_result, session_ok, session_busy, session_streaming_rewrite_forbidden, new_streaming_session_state, session_open, session_begin_request, session_finish_request, session_abort_request, session_close, session_reap_timeouts}
use neurx.inference.scheduler.pd_bootstrap_room.{pd_bootstrap_config, pd_bootstrap_state, pd_room_result, pd_room_bootstrapping, pd_room_waiting_for_input, pd_room_transferring, pd_room_success, pd_room_failed, new_pd_bootstrap_state, pd_create_room, pd_room_peer_ready, pd_room_start_transfer, pd_room_complete, pd_room_poll, pd_room_release}
use neurx.inference.compute.gpu_tbo_executor.{gpu_tbo_config, gpu_tbo_executor_state, gpu_tbo_execution_result, gpu_op_attention, gpu_op_all_gather, gpu_exec_complete, gpu_exec_failed, new_gpu_tbo_executor, gpu_tbo_enqueue, gpu_tbo_execute_next, gpu_tbo_all_terminal}
use neurx.inference.cache.session_kv_binding.{session_kv_binding_config, session_kv_binding_state, session_kv_result, kv_owner_request, kv_owner_session, new_session_kv_binding, session_kv_save, session_kv_restore, session_kv_bind_page, session_kv_page_id, session_kv_return_to_session, session_kv_release}
use neurx.inference.distributed.transfer.transfer_adapters.{transfer_adapter_config, transfer_adapter_state, transfer_adapter_result, transfer_backend_mooncake, transfer_backend_nixl, transfer_backend_mori, transfer_metadata_ready, transfer_complete, transfer_failed, new_transfer_adapter_state, transfer_create, transfer_register_memory, transfer_mark_shard_ready, transfer_start, transfer_complete_shard, transfer_poll_timeout}
use neurx.inference.llm.program_dsl_runtime.{dsl_runtime_config, dsl_program_runtime, dsl_step_result, dsl_op_generate, dsl_op_set, dsl_op_fork, dsl_op_join_sum, dsl_op_halt, new_dsl_runtime, dsl_add_operation, dsl_step, dsl_resume_external}
use neurx.inference.sampling.dllm_runtime.{dllm_config, dllm_state, dllm_step_result, dllm_strategy_low_confidence, dllm_strategy_random, new_dllm_state, dllm_set_prediction, dllm_decode_step}
use neurx.inference.cache.kv_canary.{kv_canary_config, kv_canary_state, kv_canary_result, canary_healthy, canary_suspect, canary_quarantined, new_kv_canary, canary_register_page, canary_observe, canary_repair, canary_inject_perturbation}
use neurx.inference.model.adapters.model_kernel_registry.{model_kernel_registry_config, model_kernel_registry_state, model_kernel_selection, model_family_generic, model_family_deepseek_v4, model_family_mimo_v2, kernel_attention, new_model_kernel_registry, kernel_register, kernel_select, kernel_disable}

func sglang_expect(bool condition, string name) int {
    if condition { println("PASS " + name); return 0 }
    println("FAIL " + name)
    1
}

func test_cache_aware_routing() int {
    int failures = 0
    cache_aware_router_state state = new_cache_aware_router(cache_aware_router_config {cache_threshold_per_mille: 500, balance_absolute_threshold: 2, balance_relative_percent: 150, max_affinity_entries: 8})
    state = cache_router_register_worker(state, 101, 1, 7, 0)
    state = cache_router_register_worker(state, 102, 1, 7, 0)
    cache_route_result first = cache_router_route(state, 1, 7, 9001, 14, 16)
    state = cache_router_complete(first.state, first.worker_id)
    cache_route_result affinity = cache_router_route(state, 1, 7, 9001, 14, 16)
    failures = failures + sglang_expect(first.routed && affinity.worker_id == first.worker_id && affinity.strategy == cache_route_affinity() && affinity.matched_prefix_tokens == 14, "cache-aware prefix affinity")
    state = cache_router_set_worker(affinity.state, first.worker_id, 10, true)
    int other = 101
    if first.worker_id == 101 { other = 102 }
    state = cache_router_set_worker(state, other, 0, true)
    cache_route_result balanced = cache_router_route(state, 1, 7, 9001, 14, 16)
    failures = failures + sglang_expect(balanced.worker_id == other && balanced.strategy == cache_route_load(), "cache-aware imbalance fallback")
    cache_route_result isolated = cache_router_route(balanced.state, 2, 7, 9001, 14, 16)
    failures = failures + sglang_expect(!isolated.routed, "cache-aware pool isolation")
    failures
}

func test_circuit_breaker() int {
    int failures = 0
    circuit_breaker_state state = new_circuit_breaker(circuit_breaker_config {failure_threshold: 2, success_threshold: 2, open_timeout_ms: 100, failure_window_ms: 1000, half_open_max_requests: 1}, 0)
    state = circuit_record_failure(state, 10)
    state = circuit_record_failure(state, 20)
    circuit_admission_result denied = circuit_try_acquire(state, 50)
    failures = failures + sglang_expect(state.state == circuit_open() && !denied.allowed, "circuit opens and rejects")
    circuit_admission_result probe = circuit_try_acquire(denied.state, 120)
    circuit_admission_result limited = circuit_try_acquire(probe.state, 121)
    failures = failures + sglang_expect(probe.allowed && probe.state.state == circuit_half_open() && !limited.allowed, "circuit half-open probe limit")
    state = circuit_record_success(limited.state, 122)
    probe = circuit_try_acquire(state, 123)
    state = circuit_record_success(probe.state, 124)
    failures = failures + sglang_expect(state.state == circuit_closed() && state.total_failures == 2 && state.total_successes == 2, "circuit recovery threshold")
    failures
}

func test_jump_forward() int {
    int failures = 0
    jump_forward_fsm fsm = new_jump_forward_fsm(16)
    fsm = jump_forward_add_edge(fsm, 0, 1, 123)
    fsm = jump_forward_add_edge(fsm, 1, 2, 34)
    fsm = jump_forward_add_edge(fsm, 2, 3, 97)
    fsm = jump_forward_add_edge(fsm, 3, 4, 120)
    fsm = jump_forward_add_edge(fsm, 3, 5, 121)
    fsm = jump_forward_add_final(fsm, 4)
    jump_forward_result jump = jump_forward_try(fsm, 0)
    failures = failures + sglang_expect(jump.jumped && jump.step_count == 3 && jump.bytes[0] == 123 && jump.bytes[1] == 34 && jump.next_state == 3 && jump.bytes[2] == 97, "compressed FSM jump-forward")
    jump_forward_result branch = jump_forward_try(fsm, 3)
    failures = failures + sglang_expect(!branch.jumped && branch.step_count == 0 && branch.next_state == 3, "jump-forward stops at branch")
    jump_forward_fsm cycle = new_jump_forward_fsm(8)
    cycle = jump_forward_add_edge(cycle, 7, 8, 97)
    cycle = jump_forward_add_edge(cycle, 8, 7, 98)
    jump = jump_forward_try(cycle, 7)
    failures = failures + sglang_expect(jump.step_count == 2 && jump.next_state == 7, "jump-forward cycle guard")
    failures
}

func test_hicache() int {
    int failures = 0
    hicache_config through_config = hicache_config {write_policy: hicache_write_through(), prefetch_threshold_pages: 2, prefetch_base_timeout_ms: 2000, prefetch_per_ki_token_ms: 100, prefetch_max_timeout_ms: 30000, storage_enabled: true}
    hicache_state state = new_hicache(through_config)
    state = hicache_admit_device_page(state, 11, 0, 1)
    hicache_action_result action = hicache_prepare_backup(state, 11, 0)
    state = hicache_complete_backup(action.state, action.page_index, true)
    action = hicache_prepare_storage_write(state, 11, 0, false)
    failures = failures + sglang_expect(action.scheduled && action.action == hicache_action_host_to_storage(), "HiCache write-through pipeline")
    state = hicache_complete_storage_write(action.state, action.page_index, true)
    state = hicache_set_page_residency(state, 11, 0, false, false)
    action = hicache_prepare_prefetch(state, 11, 0, 2)
    failures = failures + sglang_expect(action.scheduled && action.action == hicache_action_storage_to_host() && hicache_prefetch_timeout_ms(through_config, 2048) == 2200, "HiCache storage prefetch")
    state = hicache_complete_prefetch(action.state, action.page_index, true, false)
    state = hicache_admit_device_page(state, 12, 0, 1)
    state = hicache_admit_device_page(state, 21, 1, 1)
    hicache_prefix_result prefix = hicache_match_prefix(state, []int{11, 12, 13}, 0, []int{21, 22}, 1)
    failures = failures + sglang_expect(prefix.kv_hit_pages == 2 && prefix.auxiliary_hit_pages == 1 && prefix.usable_pages == 1, "HiCache multi-pool longest prefix")
    hicache_state write_back = new_hicache(hicache_config {write_policy: hicache_write_back(), prefetch_threshold_pages: 1, prefetch_base_timeout_ms: 1, prefetch_per_ki_token_ms: 1, prefetch_max_timeout_ms: 10, storage_enabled: true})
    write_back = hicache_admit_device_page(write_back, 31, 0, 1)
    action = hicache_prepare_backup(write_back, 31, 0)
    failures = failures + sglang_expect(!action.scheduled, "HiCache write-back reference threshold")
    write_back = hicache_set_lock_refs(write_back, 31, 0, 2)
    action = hicache_prepare_backup(write_back, 31, 0)
    write_back = hicache_complete_backup(action.state, action.page_index, true)
    hicache_action_result deferred = hicache_prepare_storage_write(write_back, 31, 0, false)
    hicache_action_result eviction = hicache_prepare_storage_write(deferred.state, 31, 0, true)
    failures = failures + sglang_expect(!deferred.scheduled && eviction.scheduled, "HiCache deferred write-back")
    failures
}

func test_two_batch_overlap() int {
    int failures = 0
    tbo_config config = tbo_config {token_distribution_threshold_per_mille: 300, minimum_tokens: 4, decode_delta_stages: 2}
    tbo_plan balanced = tbo_make_plan(config, tbo_mode_extend(), []int{4, 4, 4, 4}, 0, 0)
    failures = failures + sglang_expect(balanced.enabled && !balanced.two_chunk_split && balanced.child_a_tokens == 8 && balanced.child_b_tokens == 8, "TBO balanced prefill split")
    tbo_plan chunked = tbo_make_plan(config, tbo_mode_extend(), []int{1, 1, 18}, 0, 0)
    failures = failures + sglang_expect(chunked.enabled && chunked.two_chunk_split && chunked.child_a_tokens == 10 && chunked.child_b_tokens == 10, "TBO two-chunk skew correction")
    tbo_plan decode = tbo_make_plan(config, tbo_mode_decode(), []int{}, 6, 1)
    failures = failures + sglang_expect(decode.enabled && decode.child_a_sequences == 3 && decode.child_b_sequences == 3 && decode.delta_stages == 2, "TBO decode microbatch split")
    tbo_stage_schedule schedule = tbo_schedule_stages(5, 5, decode.delta_stages)
    failures = failures + sglang_expect(schedule.valid && schedule.tick_count == 7 && schedule.child_a_stages[0] == 0 && schedule.child_b_stages[0] == 0 - 1 && schedule.child_a_stages[2] == 2 && schedule.child_b_stages[2] == 0 && schedule.child_b_stages[6] == 4, "TBO overlapped stage order")
    failures
}

func test_streaming_sessions() int {
    int failures = 0
    streaming_session_state state = new_streaming_session_state(streaming_session_config {capacity: 3, default_timeout_ms: 100})
    session_update_result update = session_open(state, 7001, true, 100, 0)
    update = session_begin_request(update.state, 7001, 11, 8, 0, false, false, 0, 1)
    update = session_finish_request(update.state, 7001, 11, 3, 10, 2, 10)
    update = session_begin_request(update.state, 7001, 12, 4, 0, false, false, 0, 11)
    failures = failures + sglang_expect(update.accepted && update.context_tokens == 15, "streaming session append context")
    session_update_result busy = session_begin_request(update.state, 7001, 13, 1, 0, false, false, 0, 12)
    session_update_result rewrite = session_abort_request(busy.state, 7001, 12, 13)
    rewrite = session_begin_request(rewrite.state, 7001, 14, 1, 0, true, false, 0, 14)
    failures = failures + sglang_expect(!busy.accepted && busy.status == session_busy() && !rewrite.accepted && rewrite.status == session_streaming_rewrite_forbidden(), "streaming session safety gates")
    update = session_begin_request(rewrite.state, 7001, 15, 2, 0, false, false, 0, 15)
    session_update_result closing = session_close(update.state, 7001)
    session_update_result finished = session_finish_request(closing.state, 7001, 15, 1, 12, 3, 20)
    failures = failures + sglang_expect(closing.accepted && !closing.released_kv && finished.released_kv && finished.state.session_count == 0, "streaming deferred close and KV release")
    update = session_open(finished.state, 7002, true, 50, 30)
    state = session_reap_timeouts(update.state, 100)
    failures = failures + sglang_expect(state.session_count == 0 && state.timed_out == 1, "streaming session timeout reap")
    failures
}

func test_pd_bootstrap_rooms() int {
    int failures = 0
    pd_bootstrap_state state = new_pd_bootstrap_state(pd_bootstrap_config {capacity: 2, bootstrap_timeout_ms: 100, waiting_timeout_ms: 200})
    pd_room_result room = pd_create_room(state, 9001, 77, 2, 8, 0)
    room = pd_room_peer_ready(room.state, 9001, 10)
    failures = failures + sglang_expect(room.status == pd_room_bootstrapping() && room.state.ready_peers[room.room_slot] == 1, "PD bootstrap peer quorum")
    room = pd_room_peer_ready(room.state, 9001, 20)
    failures = failures + sglang_expect(room.status == pd_room_waiting_for_input(), "PD bootstrap metadata ready")
    room = pd_room_start_transfer(room.state, 9001, 30)
    failures = failures + sglang_expect(room.status == pd_room_transferring(), "PD bootstrap transfer start")
    room = pd_room_complete(room.state, 9001, true, 0, 40)
    failures = failures + sglang_expect(room.status == pd_room_success() && room.state.completed_rooms == 1 && room.state.active_rooms == 0, "PD bootstrap transfer success")
    state = pd_room_release(room.state, 9001)
    room = pd_create_room(state, 9002, 78, 1, 4, 50)
    room = pd_room_poll(room.state, 9002, 151)
    failures = failures + sglang_expect(room.status == pd_room_failed() && room.state.failure_codes[room.room_slot] == 408 && room.state.failed_rooms == 1, "PD bootstrap timeout cleanup")
    failures
}

func test_gpu_tbo_execution() int {
    int failures = 0
    gpu_tbo_executor_state state = new_gpu_tbo_executor(gpu_tbo_config {capacity: 8, device_id: 0, compute_stream_a: 10, compute_stream_b: 11, communication_stream: 12, world_size: 2, cuda_available: true, collective_available: true})
    state = gpu_tbo_enqueue(state, 1, gpu_op_attention(), 101, 0, 10, 100, 200, 8, 0)
    state = gpu_tbo_enqueue(state, 2, gpu_op_all_gather(), 101, 1, 12, 200, 300, 8, 1)
    gpu_tbo_execution_result execution = gpu_tbo_execute_next(state, 0)
    failures = failures + sglang_expect(execution.launched && execution.complete && execution.operation_id == 1 && execution.state.statuses[0] == gpu_exec_complete(), "GPU TBO forward launch")
    execution = gpu_tbo_execute_next(execution.state, 0)
    failures = failures + sglang_expect(execution.operation_id == 2 && execution.state.synchronization_count == 1 && gpu_tbo_all_terminal(execution.state), "GPU TBO collective dependency")
    state = new_gpu_tbo_executor(gpu_tbo_config {capacity: 2, device_id: 0, compute_stream_a: 1, compute_stream_b: 2, communication_stream: 3, world_size: 2, cuda_available: true, collective_available: false})
    state = gpu_tbo_enqueue(state, 3, gpu_op_all_gather(), 102, 0, 3, 100, 200, 4, 0)
    execution = gpu_tbo_execute_next(state, 0)
    failures = failures + sglang_expect(!execution.launched && execution.backend_code == 503 && execution.state.statuses[0] == gpu_exec_failed(), "GPU TBO unavailable collective fails closed")
    failures
}

func test_session_kv_pool_binding() int {
    int failures = 0
    session_kv_binding_state state = new_session_kv_binding(session_kv_binding_config {capacity: 2, page_size: 4, maximum_pages_per_session: 16})
    session_kv_result result = session_kv_save(state, 7001, 11, 3, 9, 12, 100)
    state = session_kv_bind_page(result.state, 7001, 0, 100)
    state = session_kv_bind_page(state, 7001, 1, 104)
    state = session_kv_bind_page(state, 7001, 2, 109)
    failures = failures + sglang_expect(result.success && result.page_count == 3 && session_kv_page_id(state, 7001, 1) == 104 && state.ownership[result.slot] == kv_owner_session(), "Session saves real KV pool page table")
    result = session_kv_restore(state, 7001, 12, 7)
    int trimmed_offset = result.slot * result.state.config.maximum_pages_per_session + 2
    failures = failures + sglang_expect(result.success && result.committed_tokens == 7 && result.page_count == 2 && result.state.page_ids[trimmed_offset] == 0 && result.state.freed_tail_pages == 1 && result.state.ownership[result.slot] == kv_owner_request(), "Session restores KV prefix and trims pages")
    state = session_kv_return_to_session(result.state, 7001, 10, 12)
    failures = failures + sglang_expect(state.page_counts[result.slot] == 3 && state.ownership[result.slot] == kv_owner_session(), "Request returns KV ownership to Session")
    state = session_kv_release(state, 7001)
    failures = failures + sglang_expect(state.binding_count == 0 && state.released_pages == 3, "Session releases bound KV pages")
    failures
}

func test_transfer_adapters() int {
    int failures = 0
    transfer_adapter_state state = new_transfer_adapter_state(transfer_adapter_config {capacity: 4, maximum_shards: 2, maximum_retries: 1, timeout_ms: 100, mooncake_available: true, nixl_available: true, mori_available: true})
    transfer_adapter_result transfer = transfer_create(state, 1, 91, transfer_backend_mooncake(), 0, 1, 100, 200, 4096, 2, 77, 0)
    transfer = transfer_register_memory(transfer.state, 1, true, 1)
    transfer = transfer_mark_shard_ready(transfer.state, 1, 2)
    transfer = transfer_mark_shard_ready(transfer.state, 1, 3)
    transfer = transfer_start(transfer.state, 1, 4)
    transfer = transfer_complete_shard(transfer.state, 1, true, 77, 5)
    transfer = transfer_complete_shard(transfer.state, 1, true, 77, 6)
    failures = failures + sglang_expect(transfer.status == transfer_complete() && transfer.state.transferred_bytes == 4096, "Mooncake sharded transfer completion")
    transfer = transfer_create(transfer.state, 2, 92, transfer_backend_nixl(), 0, 1, 300, 400, 1024, 1, 88, 10)
    transfer = transfer_register_memory(transfer.state, 2, true, 11)
    transfer = transfer_mark_shard_ready(transfer.state, 2, 12)
    transfer = transfer_start(transfer.state, 2, 13)
    transfer = transfer_complete_shard(transfer.state, 2, true, 99, 14)
    failures = failures + sglang_expect(transfer.status == transfer_metadata_ready() && transfer.state.retry_counts[transfer.slot] == 1, "NIXL checksum retry")
    transfer = transfer_start(transfer.state, 2, 15)
    transfer = transfer_complete_shard(transfer.state, 2, false, 99, 16)
    failures = failures + sglang_expect(transfer.status == transfer_failed() && transfer.state.error_codes[transfer.slot] == 422, "NIXL retry exhaustion")
    transfer = transfer_create(transfer.state, 3, 93, transfer_backend_mori(), 1, 2, 500, 600, 2048, 1, 0, 20)
    transfer = transfer_poll_timeout(transfer.state, 3, 121)
    failures = failures + sglang_expect(transfer.status == transfer_failed() && transfer.state.error_codes[transfer.slot] == 408, "Mori transfer timeout")
    failures
}

func test_program_dsl_runtime() int {
    int failures = 0
    dsl_program_runtime runtime = new_dsl_runtime(dsl_runtime_config {maximum_operations: 8, maximum_threads: 2, variable_count: 3, maximum_steps: 16})
    runtime = dsl_add_operation(runtime, dsl_op_fork(), 0, 0, 0, 4)
    runtime = dsl_add_operation(runtime, dsl_op_generate(), 0, 0, 0, 0)
    runtime = dsl_add_operation(runtime, dsl_op_join_sum(), 2, 1, 1, 0)
    runtime = dsl_add_operation(runtime, dsl_op_halt(), 0, 0, 0, 0)
    runtime = dsl_add_operation(runtime, dsl_op_set(), 1, 7, 0, 0)
    runtime = dsl_add_operation(runtime, dsl_op_halt(), 0, 0, 0, 0)
    dsl_step_result step = dsl_step(runtime)
    step = dsl_step(step.runtime)
    int waiting_thread = step.thread_id
    failures = failures + sglang_expect(step.needs_external_result && step.runtime.thread_count == 2, "SGLang DSL fork and generate suspension")
    step = dsl_step(step.runtime)
    step = dsl_step(step.runtime)
    runtime = dsl_resume_external(step.runtime, waiting_thread, 5)
    step = dsl_step(runtime)
    step = dsl_step(step.runtime)
    failures = failures + sglang_expect(step.runtime.halted && step.runtime.variables[0] == 5 && step.runtime.variables[1] == 7 && step.runtime.variables[2] == 7, "SGLang DSL resume and join")
    runtime = new_dsl_runtime(dsl_runtime_config {maximum_operations: 6, maximum_threads: 2, variable_count: 2, maximum_steps: 12})
    runtime = dsl_add_operation(runtime, dsl_op_fork(), 0, 0, 0, 3)
    runtime = dsl_add_operation(runtime, dsl_op_join_sum(), 1, 1, 0, 0)
    runtime = dsl_add_operation(runtime, dsl_op_halt(), 0, 0, 0, 0)
    runtime = dsl_add_operation(runtime, dsl_op_set(), 0, 9, 0, 0)
    runtime = dsl_add_operation(runtime, dsl_op_halt(), 0, 0, 0, 0)
    step = dsl_step(runtime)
    step = dsl_step(step.runtime)
    step = dsl_step(step.runtime)
    step = dsl_step(step.runtime)
    step = dsl_step(step.runtime)
    step = dsl_step(step.runtime)
    failures = failures + sglang_expect(step.runtime.halted && step.runtime.variables[1] == 9, "SGLang DSL join wakes without starvation")
    failures
}

func test_dllm_runtime() int {
    int failures = 0
    dllm_state state = new_dllm_state(dllm_config {sequence_length: 6, maximum_steps: 3, tokens_per_step: 2, remask_strategy: dllm_strategy_low_confidence(), confidence_threshold_per_mille: 700, block_size: 2}, []int{10, 11})
    state = dllm_set_prediction(state, 2, 20, 900)
    state = dllm_set_prediction(state, 3, 21, 800)
    state = dllm_set_prediction(state, 4, 22, 500)
    state = dllm_set_prediction(state, 5, 23, 400)
    dllm_step_result decoded = dllm_decode_step(state)
    failures = failures + sglang_expect(decoded.selected_count == 2 && decoded.state.masked_count == 2 && decoded.state.token_ids[2] == 20, "DLLM confidence commit step")
    state = dllm_set_prediction(decoded.state, 4, 22, 950)
    state = dllm_set_prediction(state, 5, 23, 900)
    decoded = dllm_decode_step(state)
    failures = failures + sglang_expect(decoded.complete && decoded.state.committed_tokens == 6 && decoded.state.masked_count == 0, "DLLM iterative unmask completion")
    state = new_dllm_state(dllm_config {sequence_length: 5, maximum_steps: 2, tokens_per_step: 2, remask_strategy: dllm_strategy_random(), confidence_threshold_per_mille: 1000, block_size: 5}, []int{10})
    decoded = dllm_decode_step(state)
    failures = failures + sglang_expect(decoded.selected_count == 2 && decoded.selected_positions[0] == 3 && decoded.selected_positions[1] == 4, "DLLM deterministic random remask strategy")
    failures
}

func test_kv_canary() int {
    int failures = 0
    kv_canary_state state = new_kv_canary(kv_canary_config {capacity: 4, sample_interval: 1, failure_threshold: 2, perturbation_seed: 7})
    state = canary_register_page(state, 101, 1234)
    kv_canary_result observed = canary_observe(state, 101, 999)
    failures = failures + sglang_expect(observed.sampled && observed.status == canary_suspect(), "KV Canary detects suspect page")
    observed = canary_observe(observed.state, 101, 998)
    failures = failures + sglang_expect(observed.status == canary_quarantined() && observed.state.quarantined_pages == 1, "KV Canary quarantines repeated corruption")
    state = canary_repair(observed.state, 101, 1234)
    failures = failures + sglang_expect(state.statuses[0] == canary_healthy() && state.quarantined_pages == 0 && canary_inject_perturbation(state, 101, 3) != 1234, "KV Canary repair and perturbation probe")
    failures
}

func test_model_kernel_registry() int {
    int failures = 0
    model_kernel_registry_state state = new_model_kernel_registry(model_kernel_registry_config {capacity: 4, platform_mask: 1})
    state = kernel_register(state, 1, model_family_generic(), kernel_attention(), 1, 70, 32768, true, true, false, 10)
    state = kernel_register(state, 2, model_family_deepseek_v4(), kernel_attention(), 1, 80, 16384, true, true, true, 5)
    model_kernel_selection selected = kernel_select(state, model_family_deepseek_v4(), kernel_attention(), 90, 8192, false, true)
    failures = failures + sglang_expect(selected.supported && selected.kernel_id == 2 && !selected.fallback, "model-specific TBO kernel selection")
    selected = kernel_select(selected.state, model_family_mimo_v2(), kernel_attention(), 90, 8192, false, false)
    failures = failures + sglang_expect(selected.supported && selected.kernel_id == 1 && selected.fallback, "generic kernel fallback")
    state = kernel_disable(selected.state, 2)
    selected = kernel_select(state, model_family_deepseek_v4(), kernel_attention(), 90, 8192, false, true)
    failures = failures + sglang_expect(!selected.supported, "kernel capability gate after disable")
    failures
}

func main() {
    int failures = 0
    failures = failures + test_cache_aware_routing()
    failures = failures + test_circuit_breaker()
    failures = failures + test_jump_forward()
    failures = failures + test_hicache()
    failures = failures + test_two_batch_overlap()
    failures = failures + test_streaming_sessions()
    failures = failures + test_pd_bootstrap_rooms()
    failures = failures + test_gpu_tbo_execution()
    failures = failures + test_session_kv_pool_binding()
    failures = failures + test_transfer_adapters()
    failures = failures + test_program_dsl_runtime()
    failures = failures + test_dllm_runtime()
    failures = failures + test_kv_canary()
    failures = failures + test_model_kernel_registry()
    if failures == 0 { println("SGLang capability contract: PASS") }
    else { println("SGLang capability contract: FAIL") }
}
