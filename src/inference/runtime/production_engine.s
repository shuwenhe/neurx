package neurx.inference.runtime.production_engine
use neurx.inference.runtime.model_manifest
use neurx.inference.runtime.worker_cluster
use neurx.inference.runtime.engine_lifecycle
use neurx.observability.tracing.inference_observability
func engine_request_active_status() int { 1 }
func engine_request_finished_status() int { 2 }
func engine_request_failed_status() int { 3 }
func engine_request_cancelled_status() int { 4 }
func engine_execution_pending_status() int { 1 }
func engine_execution_complete_status() int { 2 }
func engine_execution_failed_status() int { 3 }
func engine_kv_transfer_pending_status() int { 1 }
func engine_kv_transfer_complete_status() int { 2 }
func engine_kv_transfer_failed_status() int { 3 }
struct production_engine_config {
    string model_directory
    string backend_name
    string served_model_name
    int scheduler_strategy
    parallel_topology topology
    int total_kv_blocks
    int kv_block_size
    int kv_watermark_blocks
    int heartbeat_timeout_ms
    int max_worker_restarts
    int max_request_retries
    int gpu_device_count
    bool backend_abi_ready
}
struct production_request {
    string request_id
    string model
    bool stream
    int status
    int submitted_ms
    int first_token_ms
    int finished_ms
    int output_tokens
    int retry_count
    string finish_reason
    string error_message
}
struct gpu_execution_command {
    int execution_id
    string request_id
    bool prefill
    int token_count
    int computed_tokens
    int[] block_ids
    string[] worker_ids
    int data_rank
    int model_generation
    int status
}
struct gpu_execution_batch {
    int batch_id
    []gpu_execution_command commands
    int scheduled_tokens
    bool ready
    string error_message
}
struct gpu_execution_output {
    int execution_id
    string request_id
    int computed_tokens
    int generated_token_id
    string generated_text
    bool eos
    bool success
    string error_message
}
struct inference_stream_event {
    string request_id
    int sequence
    string event_type
    int token_id
    string text
    string finish_reason
    bool terminal
}
struct kv_transfer_ticket {
    int ticket_id
    string request_id
    string source_worker_id
    string target_worker_id
    int[] block_ids
    int byte_count
    int checksum
    int status
    string error_message
}
struct production_engine_state {
    production_engine_config config
    hf_model_manifest model
    worker_cluster_state cluster
    int scheduler_state
    engine_lifecycle_state lifecycle
    inference_observability_state metrics
    []production_request requests
    []gpu_execution_command inflight
    []inference_stream_event events
    []kv_transfer_ticket kv_transfers
    int model_generation
    int next_execution_id
    int next_batch_id
    int next_event_sequence
    int next_transfer_id
    int next_data_rank
    int now_ms
    bool initialized
    string error_message
}
struct production_engine_result {
    production_engine_state state
    production_request request
    gpu_execution_batch batch
    bool success
    string error_message
}
func engine_empty_request() production_request {
    production_request request
    request.request_id = ""
    request.model = ""
    request.stream = false
    request.status = engine_request_failed_status()
    request.submitted_ms = 0
    request.first_token_ms = 0
    request.finished_ms = 0
    request.output_tokens = 0
    request.retry_count = 0
    request.finish_reason = ""
    request.error_message = ""
    request
}
func engine_empty_batch() gpu_execution_batch {
    gpu_execution_batch batch
    batch.batch_id = 0
    batch.commands = []
    batch.scheduled_tokens = 0
    batch.ready = false
    batch.error_message = ""
    batch
}
func engine_result(production_engine_state state, production_request request, bool success, string error_message) production_engine_result {
    production_engine_result result
    result.state = state
    result.request = request
    result.batch = engine_empty_batch()
    result.success = success
    result.error_message = error_message
    result
}
func engine_normalize_config(production_engine_config config) production_engine_config {
    if config.served_model_name == "" { config.served_model_name = config.model_directory }
    if config.total_kv_blocks <= 0 { config.total_kv_blocks = 1 }
    if config.kv_block_size <= 0 { config.kv_block_size = 16 }
    if config.kv_watermark_blocks < 0 { config.kv_watermark_blocks = 0 }
    if config.max_request_retries < 0 { config.max_request_retries = 0 }
    config.topology = worker_normalize_topology(config.topology)
    config
}
func new_production_engine(production_engine_config config) production_engine_state {
    production_engine_state state
    state.config = engine_normalize_config(config)
    state.model = load_hf_model_manifest(state.config.model_directory)
    state.cluster = new_worker_cluster(state.config.topology, state.config.heartbeat_timeout_ms, state.config.max_worker_restarts)
    state.scheduler_state = 0
    state.lifecycle = new_engine_lifecycle(true, state.config.backend_name, true, true)
    state.metrics = new_inference_observability()
    state.requests = []
    state.inflight = []
    state.events = []
    state.kv_transfers = []
    state.model_generation = 1
    state.next_execution_id = 1
    state.next_batch_id = 1
    state.next_event_sequence = 1
    state.next_transfer_id = 1
    state.next_data_rank = 0
    state.now_ms = 0
    state.initialized = false
    state.error_message = ""
    if !state.model.valid {
        state.error_message = state.model.error_message
        return state
    }
    if !state.cluster.initialized {
        state.error_message = state.cluster.error_message
        return state
    }
    if state.config.backend_name == "cuda" && (!state.config.backend_abi_ready || state.config.gpu_device_count <= 0) {
        state.error_message = "CUDA backend ABI or device is unavailable"
        return state
    }
    if state.config.backend_name != "cuda" && state.config.backend_name != "ascend" {
        state.error_message = "production backend must be cuda or ascend"
        return state
    }
    state.initialized = true
    state
}
func engine_request_at(production_engine_state state, int index) production_request {
    state.requests[index]
}
func engine_find_request(production_engine_state state, string request_id) int {
    int i = 0
    for i < len(state.requests) {
        if state.requests[i].request_id == request_id { return i }
        i = i + 1
    }
    -1
}
func engine_find_execution(production_engine_state state, int execution_id) int {
    int i = 0
    for i < len(state.inflight) {
        if state.inflight[i].execution_id == execution_id { return i }
        i = i + 1
    }
    -1
}
func engine_execution_at(production_engine_state state, int index) gpu_execution_command {
    state.inflight[index]
}
func engine_remove_execution([]gpu_execution_command commands, int remove_index) []gpu_execution_command {
    []gpu_execution_command filtered = []gpu_execution_command{cap: len(commands)}
    int i = 0
    for i < len(commands) {
        if i != remove_index { filtered = append(filtered, commands[i]) }
        i = i + 1
    }
    filtered
}
func engine_append_event(production_engine_state state, string request_id, string event_type, int token_id, string text, string finish_reason, bool terminal) production_engine_state {
    inference_stream_event event
    event.request_id = request_id
    event.sequence = state.next_event_sequence
    event.event_type = event_type
    event.token_id = token_id
    event.text = text
    event.finish_reason = finish_reason
    event.terminal = terminal
    state.next_event_sequence = state.next_event_sequence + 1
    state.events = append(state.events, event)
    state
}
func engine_register_worker(production_engine_state state, string worker_id, string node_id, int global_rank, int local_rank, int device_id, int now_ms) production_engine_result {
    if !state.initialized { return engine_result(state, engine_empty_request(), false, state.error_message) }
    worker_cluster_result registered = worker_register(state.cluster, worker_id, node_id, global_rank, local_rank, device_id, now_ms)
    state.cluster = registered.state
    if !registered.success { return engine_result(state, engine_empty_request(), false, registered.error_message) }
    worker_cluster_result ready = worker_mark_ready(state.cluster, worker_id, registered.worker.generation, now_ms)
    state.cluster = ready.state
    engine_result(state, engine_empty_request(), ready.success, ready.error_message)
}
func engine_ready(production_engine_state state) bool {
    state.initialized && engine_is_available(state.lifecycle) && worker_ready_count(state.cluster) >= state.config.topology.tensor_parallel_size * state.config.topology.pipeline_parallel_size
}
func engine_submit(production_engine_state state, string request_id, string model, int prompt_tokens, int max_new_tokens, int priority, string[] prefix_hashes, bool stream, int now_ms) production_engine_result {
    if !engine_ready(state) { return engine_result(state, engine_empty_request(), false, "engine is not ready") }
    if model != "" && model != state.config.served_model_name { return engine_result(state, engine_empty_request(), false, "model is not served") }
    if engine_find_request(state, request_id) >= 0 { return engine_result(state, engine_empty_request(), false, "duplicate request") }
    scheduler_update_result submitted = scheduler_submit(state.scheduler, request_id, prompt_tokens, max_new_tokens, priority, prefix_hashes, "")
    state.scheduler = submitted.state
    if !submitted.success { return engine_result(state, engine_empty_request(), false, submitted.error_message) }
    production_request request
    request.request_id = request_id
    request.model = state.config.served_model_name
    request.stream = stream
    request.status = engine_request_active_status()
    request.submitted_ms = now_ms
    request.first_token_ms = 0
    request.finished_ms = 0
    request.output_tokens = 0
    request.retry_count = 0
    request.finish_reason = ""
    request.error_message = ""
    state.requests = append(state.requests, request)
    state.metrics = observability_start_request(state.metrics, prompt_tokens)
    state.lifecycle = engine_begin_request(state.lifecycle, request_id).state
    state = engine_append_event(state, request_id, "accepted", -1, "", "", false)
    engine_result(state, request, true, "")
}
func engine_select_data_rank(production_engine_state state) int {
    int attempts = 0
    int rank = state.next_data_rank
    for attempts < state.config.topology.data_parallel_size {
        if worker_replica_ready(state.cluster, rank) { return rank }
        rank = rank + 1
        if rank >= state.config.topology.data_parallel_size { rank = 0 }
        attempts = attempts + 1
    }
    -1
}
func engine_replica_worker_ids(production_engine_state state, int data_rank) string[] {
    string[] worker_ids = string[]{cap: state.config.topology.tensor_parallel_size * state.config.topology.pipeline_parallel_size}
    int i = 0
    for i < len(state.cluster.workers) {
        inference_worker worker = state.cluster.workers[i]
        if worker.data_rank == data_rank && (worker.status == worker_ready_status() || worker.status == worker_busy_status()) {
            worker_ids = append(worker_ids, worker.worker_id)
        }
        i = i + 1
    }
    worker_ids
}
func engine_assign_workers(production_engine_state state, string[] worker_ids, string request_id) production_engine_result {
    int i = 0
    for i < len(worker_ids) {
        worker_cluster_result assigned = worker_assign(state.cluster, worker_ids[i], request_id)
        state.cluster = assigned.state
        if !assigned.success { return engine_result(state, engine_empty_request(), false, assigned.error_message) }
        i = i + 1
    }
    engine_result(state, engine_empty_request(), true, "")
}
func engine_build_command(production_engine_state state, scheduled_request scheduled, int data_rank, string[] worker_ids) gpu_execution_command {
    gpu_execution_command command
    command.execution_id = state.next_execution_id
    command.request_id = scheduled.request_id
    command.prefill = scheduled.prefill
    command.token_count = scheduled.token_count
    command.computed_tokens = scheduled.computed_tokens
    command.block_ids = scheduled.block_ids
    command.worker_ids = worker_ids
    command.data_rank = data_rank
    command.model_generation = state.model_generation
    command.status = engine_execution_pending_status()
    command
}
func engine_schedule(production_engine_state state, int now_ms) production_engine_result {
    production_engine_result result = engine_result(state, engine_empty_request(), false, "")
    if !engine_ready(state) {
        result.error_message = "engine is not ready"
        return result
    }
    scheduler_step_result scheduled = scheduler_step(state.scheduler)
    state.scheduler = scheduled.state
    gpu_execution_batch batch = engine_empty_batch()
    batch.batch_id = state.next_batch_id
    batch.scheduled_tokens = scheduled.output.scheduled_tokens
    int i = 0
    for i < len(scheduled.output.requests) {
        scheduled_request request = scheduled_request_at(scheduled.output.requests, i)
        int data_rank = engine_select_data_rank(state)
        if data_rank < 0 {
            batch.error_message = "no complete data-parallel replica is ready"
            result.state = state
            result.batch = batch
            result.error_message = batch.error_message
            return result
        }
        string[] worker_ids = engine_replica_worker_ids(state, data_rank)
        production_engine_result assigned = engine_assign_workers(state, worker_ids, request.request_id)
        state = assigned.state
        if !assigned.success {
            batch.error_message = assigned.error_message
            result.state = state
            result.batch = batch
            result.error_message = batch.error_message
            return result
        }
        gpu_execution_command command = engine_build_command(state, request, data_rank, worker_ids)
        state.next_execution_id = state.next_execution_id + 1
        state.next_data_rank = data_rank + 1
        if state.next_data_rank >= state.config.topology.data_parallel_size { state.next_data_rank = 0 }
        state.inflight = append(state.inflight, command)
        batch.commands = append(batch.commands, command)
        i = i + 1
    }
    state.next_batch_id = state.next_batch_id + 1
    state.now_ms = now_ms
    batch.ready = len(batch.commands) > 0
    result.state = state
    result.batch = batch
    result.success = batch.ready
    if !batch.ready { result.error_message = "no requests scheduled" }
    result
}
func engine_release_command_workers(production_engine_state state, gpu_execution_command command) production_engine_state {
    int i = 0
    for i < len(command.worker_ids) {
        worker_cluster_result released = worker_release(state.cluster, command.worker_ids[i], command.request_id)
        state.cluster = released.state
        i = i + 1
    }
    state
}
func engine_invalidate_request_executions(production_engine_state state, string request_id) production_engine_state {
    []gpu_execution_command retained = []gpu_execution_command{cap: len(state.inflight)}
    int i = 0
    for i < len(state.inflight) {
        gpu_execution_command command = engine_execution_at(state, i)
        if command.request_id == request_id {
            state = engine_release_command_workers(state, command)
        } else {
            retained = append(retained, command)
        }
        i = i + 1
    }
    state.inflight = retained
    state
}
func engine_apply_output(production_engine_state state, gpu_execution_output output, int now_ms) production_engine_result {
    int execution_index = engine_find_execution(state, output.execution_id)
    if execution_index < 0 { return engine_result(state, engine_empty_request(), false, "execution not found") }
    gpu_execution_command command = engine_execution_at(state, execution_index)
    if command.request_id != output.request_id || command.model_generation != state.model_generation {
        return engine_result(state, engine_empty_request(), false, "stale or mismatched execution output")
    }
    state = engine_release_command_workers(state, command)
    state.inflight = engine_remove_execution(state.inflight, execution_index)
    int request_index = engine_find_request(state, output.request_id)
    if request_index < 0 { return engine_result(state, engine_empty_request(), false, "request not found") }
    production_request request = engine_request_at(state, request_index)
    if !output.success {
        scheduler_update_result failed = scheduler_apply_output(state.scheduler, output.request_id, 0, 0, false, output.error_message)
        state.scheduler = failed.state
        request.status = engine_request_failed_status()
        request.finished_ms = now_ms
        request.finish_reason = "error"
        request.error_message = output.error_message
        state.requests[request_index] = request
        state.lifecycle = engine_end_request(state.lifecycle, request.request_id).state
        state.metrics = observability_finish_request(state.metrics, request.output_tokens, now_ms - request.submitted_ms, true)
        state = engine_append_event(state, request.request_id, "error", -1, "", "error", true)
        return engine_result(state, request, false, output.error_message)
    }
    int generated_tokens = 0
    if output.generated_token_id >= 0 { generated_tokens = 1 }
    scheduler_update_result updated = scheduler_apply_output(state.scheduler, output.request_id, output.computed_tokens, generated_tokens, output.eos, "")
    state.scheduler = updated.state
    if !updated.success { return engine_result(state, request, false, updated.error_message) }
    if generated_tokens > 0 {
        request.output_tokens = request.output_tokens + 1
        if request.first_token_ms == 0 { request.first_token_ms = now_ms }
        state = engine_append_event(state, request.request_id, "token", output.generated_token_id, output.generated_text, "", false)
    }
    if updated.request.status == scheduler_finished_status() {
        request.status = engine_request_finished_status()
        request.finished_ms = now_ms
        request.finish_reason = "stop"
        state.lifecycle = engine_end_request(state.lifecycle, request.request_id).state
        state.metrics = observability_finish_request(state.metrics, request.output_tokens, now_ms - request.submitted_ms, false)
        state = engine_append_event(state, request.request_id, "finished", -1, "", request.finish_reason, true)
    }
    state.requests[request_index] = request
    engine_result(state, request, true, "")
}
func engine_preempt_request(production_engine_state state, string request_id) production_engine_state {
    state = engine_invalidate_request_executions(state, request_id)
    int running_index = scheduler_find_request(state.scheduler.running, request_id)
    if running_index >= 0 { state.scheduler = scheduler_preempt_at(state.scheduler, running_index) }
    int request_index = engine_find_request(state, request_id)
    if request_index >= 0 {
        production_request request = engine_request_at(state, request_index)
        request.retry_count = request.retry_count + 1
        if request.retry_count > state.config.max_request_retries {
            scheduler_update_result cancelled = scheduler_cancel(state.scheduler, request_id)
            state.scheduler = cancelled.state
            request.status = engine_request_failed_status()
            request.finish_reason = "worker_failure"
            request.error_message = "request retry limit reached"
            state.lifecycle = engine_end_request(state.lifecycle, request_id).state
            state = engine_append_event(state, request_id, "error", -1, "", request.finish_reason, true)
        } else {
            state = engine_append_event(state, request_id, "retry", -1, "", "", false)
        }
        state.requests[request_index] = request
    }
    state
}
func engine_fail_worker(production_engine_state state, string worker_id, string reason, int now_ms) production_engine_result {
    worker_cluster_result failed = worker_fail(state.cluster, worker_id, reason)
    state.cluster = failed.state
    if !failed.success { return engine_result(state, engine_empty_request(), false, failed.error_message) }
    int i = 0
    for i < len(failed.affected_request_ids) {
        state = engine_preempt_request(state, worker_string_at(failed.affected_request_ids, i))
        i = i + 1
    }
    state.now_ms = now_ms
    engine_result(state, engine_empty_request(), true, "")
}
func engine_check_workers(production_engine_state state, int now_ms) production_engine_result {
    worker_cluster_result expired = worker_expire_heartbeats(state.cluster, now_ms)
    state.cluster = expired.state
    int i = 0
    for i < len(expired.affected_request_ids) {
        state = engine_preempt_request(state, worker_string_at(expired.affected_request_ids, i))
        i = i + 1
    }
    state.now_ms = now_ms
    engine_result(state, engine_empty_request(), true, "")
}
func engine_cancel(production_engine_state state, string request_id, int now_ms) production_engine_result {
    int request_index = engine_find_request(state, request_id)
    if request_index < 0 { return engine_result(state, engine_empty_request(), false, "request not found") }
    production_request request = engine_request_at(state, request_index)
    state = engine_invalidate_request_executions(state, request_id)
    scheduler_update_result cancelled = scheduler_cancel(state.scheduler, request_id)
    state.scheduler = cancelled.state
    if !cancelled.success { return engine_result(state, request, false, cancelled.error_message) }
    request.status = engine_request_cancelled_status()
    request.finished_ms = now_ms
    request.finish_reason = "cancelled"
    state.requests[request_index] = request
    state.lifecycle = engine_end_request(state.lifecycle, request_id).state
    state.metrics = observability_finish_request(state.metrics, request.output_tokens, now_ms - request.submitted_ms, false)
    state = engine_append_event(state, request_id, "cancelled", -1, "", "cancelled", true)
    engine_result(state, request, true, "")
}
func engine_create_kv_transfer(production_engine_state state, string request_id, string source_worker_id, string target_worker_id, int[] block_ids, int byte_count, int checksum) production_engine_result {
    if worker_find(state.cluster, source_worker_id) < 0 || worker_find(state.cluster, target_worker_id) < 0 {
        return engine_result(state, engine_empty_request(), false, "KV transfer worker not found")
    }
    if byte_count <= 0 || len(block_ids) == 0 { return engine_result(state, engine_empty_request(), false, "invalid KV transfer") }
    kv_transfer_ticket ticket
    ticket.ticket_id = state.next_transfer_id
    ticket.request_id = request_id
    ticket.source_worker_id = source_worker_id
    ticket.target_worker_id = target_worker_id
    ticket.block_ids = block_ids
    ticket.byte_count = byte_count
    ticket.checksum = checksum
    ticket.status = engine_kv_transfer_pending_status()
    ticket.error_message = ""
    state.next_transfer_id = state.next_transfer_id + 1
    state.kv_transfers = append(state.kv_transfers, ticket)
    state.metrics = observability_record_kv_handoff(state.metrics)
    engine_result(state, engine_empty_request(), true, "")
}
func engine_complete_kv_transfer(production_engine_state state, int ticket_id, int checksum, bool success, string error_message) production_engine_result {
    int i = 0
    for i < len(state.kv_transfers) {
        kv_transfer_ticket ticket = state.kv_transfers[i]
        if ticket.ticket_id == ticket_id {
            if ticket.status != engine_kv_transfer_pending_status() {
                return engine_result(state, engine_empty_request(), false, "KV transfer is terminal")
            }
            if !success || checksum != ticket.checksum {
                ticket.status = engine_kv_transfer_failed_status()
                ticket.error_message = error_message
                if checksum != ticket.checksum { ticket.error_message = "KV transfer checksum mismatch" }
                state.kv_transfers[i] = ticket
                return engine_result(state, engine_empty_request(), false, ticket.error_message)
            }
            ticket.status = engine_kv_transfer_complete_status()
            state.kv_transfers[i] = ticket
            return engine_result(state, engine_empty_request(), true, "")
        }
        i = i + 1
    }
    engine_result(state, engine_empty_request(), false, "KV transfer not found")
}
func engine_drain_events(production_engine_state state) production_engine_state {
    state.events = []
    state
}
