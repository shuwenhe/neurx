package neurx.inference.scheduler.disaggregated_runtime

func disaggregated_queued_prefill() int { 1 }

func disaggregated_prefilling() int { 2 }

func disaggregated_transferring() int { 3 }

func disaggregated_queued_decode() int { 4 }

func disaggregated_decoding() int { 5 }

func disaggregated_finished() int { 6 }

func disaggregated_failed() int { 7 }

func disaggregated_cancelled() int { 8 }

func kv_transfer_pending() int { 1 }

func kv_transfer_ready() int { 2 }

func kv_transfer_complete() int { 3 }

func kv_transfer_failed() int { 4 }

struct inference_worker {
    string worker_id
    string role
    string backend
    int capacity
    int active_requests
    bool healthy
}

struct disaggregated_request {
    string request_id
    int prompt_tokens
    int max_new_tokens
    int generated_tokens
    int phase
    string prefill_worker_id
    string decode_worker_id
    string kv_handle
    string error_message
}

struct kv_transfer_ticket {
    string transfer_id
    string request_id
    string source_worker_id
    string target_worker_id
    string kv_handle
    int byte_count
    int checksum
    int status
    int retry_count
    int max_retries
}

struct disaggregated_runtime_state {
    []inference_worker workers
    []disaggregated_request requests
    []kv_transfer_ticket transfers
    int kv_handoffs
    int transfer_failures
}

struct disaggregated_result {
    disaggregated_runtime_state state
    disaggregated_request request
    kv_transfer_ticket transfer
    bool accepted
    string error_message
}

func empty_inference_worker() inference_worker {
    inference_worker worker
    worker.worker_id = ""
    worker.role = ""
    worker.backend = ""
    worker.capacity = 0
    worker.active_requests = 0
    worker.healthy = false
    worker
}

func empty_disaggregated_request() disaggregated_request {
    disaggregated_request request
    request.request_id = ""
    request.prompt_tokens = 0
    request.max_new_tokens = 0
    request.generated_tokens = 0
    request.phase = disaggregated_failed()
    request.prefill_worker_id = ""
    request.decode_worker_id = ""
    request.kv_handle = ""
    request.error_message = ""
    request
}

func empty_kv_transfer_ticket() kv_transfer_ticket {
    kv_transfer_ticket transfer
    transfer.transfer_id = ""
    transfer.request_id = ""
    transfer.source_worker_id = ""
    transfer.target_worker_id = ""
    transfer.kv_handle = ""
    transfer.byte_count = 0
    transfer.checksum = 0
    transfer.status = kv_transfer_failed()
    transfer.retry_count = 0
    transfer.max_retries = 0
    transfer
}

func new_disaggregated_result(disaggregated_runtime_state state, disaggregated_request request, kv_transfer_ticket transfer, bool accepted, string error_message) disaggregated_result {
    disaggregated_result result
    result.state = state
    result.request = request
    result.transfer = transfer
    result.accepted = accepted
    result.error_message = error_message
    result
}

func new_disaggregated_runtime() disaggregated_runtime_state {
    disaggregated_runtime_state state
    state.workers = []inference_worker{cap: 64}
    state.requests = []disaggregated_request{cap: 1024}
    state.transfers = []kv_transfer_ticket{cap: 1024}
    state.kv_handoffs = 0
    state.transfer_failures = 0
    state
}

func disaggregated_worker_at(disaggregated_runtime_state state, int index) inference_worker {
    state.workers[index]
}

func disaggregated_request_at(disaggregated_runtime_state state, int index) disaggregated_request {
    state.requests[index]
}

func disaggregated_transfer_at(disaggregated_runtime_state state, int index) kv_transfer_ticket {
    state.transfers[index]
}

func disaggregated_find_worker(disaggregated_runtime_state state, string worker_id) int {
    int i = 0
    for i < len(state.workers) {
        inference_worker worker = disaggregated_worker_at(state, i)
        if worker.worker_id == worker_id {
            return i
        }
        i = i + 1
    }
    -1
}

func disaggregated_find_request(disaggregated_runtime_state state, string request_id) int {
    int i = 0
    for i < len(state.requests) {
        disaggregated_request request = disaggregated_request_at(state, i)
        if request.request_id == request_id {
            return i
        }
        i = i + 1
    }
    -1
}

func disaggregated_find_transfer(disaggregated_runtime_state state, string request_id) int {
    int i = 0
    for i < len(state.transfers) {
        kv_transfer_ticket transfer = disaggregated_transfer_at(state, i)
        if transfer.request_id == request_id {
            return i
        }
        i = i + 1
    }
    -1
}

func disaggregated_select_worker(disaggregated_runtime_state state, string role) int {
    int selected = -1
    int selected_load = 2147483647
    int i = 0
    for i < len(state.workers) {
        inference_worker worker = disaggregated_worker_at(state, i)
        if worker.healthy && worker.role == role && worker.active_requests < worker.capacity && worker.active_requests < selected_load {
            selected = i
            selected_load = worker.active_requests
        }
        i = i + 1
    }
    selected
}

func disaggregated_register_worker(disaggregated_runtime_state state, string worker_id, string role, string backend, int capacity) disaggregated_runtime_state {
    if worker_id == "" || disaggregated_find_worker(state, worker_id) >= 0 || capacity <= 0 {
        return state
    }
    if role != "prefill" && role != "decode" {
        return state
    }
    inference_worker worker
    worker.worker_id = worker_id
    worker.role = role
    worker.backend = backend
    worker.capacity = capacity
    worker.active_requests = 0
    worker.healthy = true
    state.workers = append(state.workers, worker)
    state
}

func disaggregated_submit(disaggregated_runtime_state state, string request_id, int prompt_tokens, int max_new_tokens) disaggregated_result {
    if request_id == "" || max_new_tokens <= 0 || disaggregated_find_request(state, request_id) >= 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "invalid or duplicate request")
    }
    string role = "prefill"
    int phase = disaggregated_queued_prefill()
    int normalized_prompt = prompt_tokens
    if normalized_prompt < 0 {
        normalized_prompt = 0
    }
    if normalized_prompt == 0 {
        role = "decode"
        phase = disaggregated_queued_decode()
    }
    int worker_index = disaggregated_select_worker(state, role)
    if worker_index < 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "no healthy worker capacity")
    }
    inference_worker worker = disaggregated_worker_at(state, worker_index)
    worker.active_requests = worker.active_requests + 1
    state.workers[worker_index] = worker
    disaggregated_request request
    request.request_id = request_id
    request.prompt_tokens = normalized_prompt
    request.max_new_tokens = max_new_tokens
    request.generated_tokens = 0
    request.phase = phase
    request.prefill_worker_id = ""
    request.decode_worker_id = ""
    request.kv_handle = ""
    request.error_message = ""
    if role == "prefill" {
        request.prefill_worker_id = worker.worker_id
    } else {
        request.decode_worker_id = worker.worker_id
    }
    state.requests = append(state.requests, request)
    new_disaggregated_result(state, request, empty_kv_transfer_ticket(), true, "")
}

func disaggregated_start_prefill(disaggregated_runtime_state state, string request_id) disaggregated_result {
    int request_index = disaggregated_find_request(state, request_id)
    if request_index < 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "request not found")
    }
    disaggregated_request request = disaggregated_request_at(state, request_index)
    if request.phase != disaggregated_queued_prefill() {
        return new_disaggregated_result(state, request, empty_kv_transfer_ticket(), false, "request is not queued for prefill")
    }
    request.phase = disaggregated_prefilling()
    state.requests[request_index] = request
    new_disaggregated_result(state, request, empty_kv_transfer_ticket(), true, "")
}

func disaggregated_complete_prefill(disaggregated_runtime_state state, string request_id, string kv_handle, int byte_count, int checksum, int max_retries) disaggregated_result {
    int request_index = disaggregated_find_request(state, request_id)
    if request_index < 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "request not found")
    }
    disaggregated_request request = disaggregated_request_at(state, request_index)
    if request.phase != disaggregated_prefilling() || kv_handle == "" || byte_count <= 0 {
        return new_disaggregated_result(state, request, empty_kv_transfer_ticket(), false, "invalid prefill completion")
    }
    int decode_index = disaggregated_select_worker(state, "decode")
    if decode_index < 0 {
        return new_disaggregated_result(state, request, empty_kv_transfer_ticket(), false, "no decode worker capacity")
    }
    inference_worker decode_worker = disaggregated_worker_at(state, decode_index)
    decode_worker.active_requests = decode_worker.active_requests + 1
    state.workers[decode_index] = decode_worker
    kv_transfer_ticket transfer
    transfer.transfer_id = request_id + "-kv"
    transfer.request_id = request_id
    transfer.source_worker_id = request.prefill_worker_id
    transfer.target_worker_id = decode_worker.worker_id
    transfer.kv_handle = kv_handle
    transfer.byte_count = byte_count
    transfer.checksum = checksum
    transfer.status = kv_transfer_ready()
    transfer.retry_count = 0
    transfer.max_retries = max_retries
    if transfer.max_retries < 0 {
        transfer.max_retries = 0
    }
    request.kv_handle = kv_handle
    request.decode_worker_id = decode_worker.worker_id
    request.phase = disaggregated_transferring()
    state.requests[request_index] = request
    state.transfers = append(state.transfers, transfer)
    new_disaggregated_result(state, request, transfer, true, "")
}

func disaggregated_ack_transfer(disaggregated_runtime_state state, string request_id, int checksum) disaggregated_result {
    int request_index = disaggregated_find_request(state, request_id)
    int transfer_index = disaggregated_find_transfer(state, request_id)
    if request_index < 0 || transfer_index < 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "transfer not found")
    }
    disaggregated_request request = disaggregated_request_at(state, request_index)
    kv_transfer_ticket transfer = disaggregated_transfer_at(state, transfer_index)
    if transfer.status != kv_transfer_ready() || transfer.checksum != checksum {
        transfer.retry_count = transfer.retry_count + 1
        state.transfer_failures = state.transfer_failures + 1
        if transfer.retry_count > transfer.max_retries {
            transfer.status = kv_transfer_failed()
            request.phase = disaggregated_failed()
            request.error_message = "KV transfer checksum mismatch"
            int failed_prefill_index = disaggregated_find_worker(state, request.prefill_worker_id)
            int failed_decode_index = disaggregated_find_worker(state, request.decode_worker_id)
            if failed_prefill_index >= 0 && state.workers[failed_prefill_index].active_requests > 0 {
                state.workers[failed_prefill_index].active_requests = state.workers[failed_prefill_index].active_requests - 1
            }
            if failed_decode_index >= 0 && state.workers[failed_decode_index].active_requests > 0 {
                state.workers[failed_decode_index].active_requests = state.workers[failed_decode_index].active_requests - 1
            }
        }
        state.transfers[transfer_index] = transfer
        state.requests[request_index] = request
        return new_disaggregated_result(state, request, transfer, false, "KV transfer checksum mismatch")
    }
    transfer.status = kv_transfer_complete()
    request.phase = disaggregated_queued_decode()
    int prefill_index = disaggregated_find_worker(state, request.prefill_worker_id)
    if prefill_index >= 0 && state.workers[prefill_index].active_requests > 0 {
        state.workers[prefill_index].active_requests = state.workers[prefill_index].active_requests - 1
    }
    state.kv_handoffs = state.kv_handoffs + 1
    state.transfers[transfer_index] = transfer
    state.requests[request_index] = request
    new_disaggregated_result(state, request, transfer, true, "")
}

func disaggregated_decode_step(disaggregated_runtime_state state, string request_id, int token_count, bool eos) disaggregated_result {
    int request_index = disaggregated_find_request(state, request_id)
    if request_index < 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "request not found")
    }
    disaggregated_request request = disaggregated_request_at(state, request_index)
    if request.phase != disaggregated_queued_decode() && request.phase != disaggregated_decoding() {
        return new_disaggregated_result(state, request, empty_kv_transfer_ticket(), false, "request is not decoding")
    }
    int add_tokens = token_count
    if add_tokens < 0 {
        add_tokens = 0
    }
    request.phase = disaggregated_decoding()
    request.generated_tokens = request.generated_tokens + add_tokens
    if eos || request.generated_tokens >= request.max_new_tokens {
        request.phase = disaggregated_finished()
        int worker_index = disaggregated_find_worker(state, request.decode_worker_id)
        if worker_index >= 0 && state.workers[worker_index].active_requests > 0 {
            state.workers[worker_index].active_requests = state.workers[worker_index].active_requests - 1
        }
    }
    state.requests[request_index] = request
    new_disaggregated_result(state, request, empty_kv_transfer_ticket(), true, "")
}

func disaggregated_set_worker_health(disaggregated_runtime_state state, string worker_id, bool healthy) disaggregated_runtime_state {
    int worker_index = disaggregated_find_worker(state, worker_id)
    if worker_index < 0 {
        return state
    }
    state.workers[worker_index].healthy = healthy
    state
}

func disaggregated_cancel(disaggregated_runtime_state state, string request_id) disaggregated_result {
    int request_index = disaggregated_find_request(state, request_id)
    if request_index < 0 {
        return new_disaggregated_result(state, empty_disaggregated_request(), empty_kv_transfer_ticket(), false, "request not found")
    }
    disaggregated_request request = disaggregated_request_at(state, request_index)
    if request.phase == disaggregated_finished() || request.phase == disaggregated_failed() || request.phase == disaggregated_cancelled() {
        return new_disaggregated_result(state, request, empty_kv_transfer_ticket(), false, "request is terminal")
    }
    int prefill_index = disaggregated_find_worker(state, request.prefill_worker_id)
    int decode_index = disaggregated_find_worker(state, request.decode_worker_id)
    bool release_prefill = request.phase == disaggregated_queued_prefill() || request.phase == disaggregated_prefilling() || request.phase == disaggregated_transferring()
    bool release_decode = request.phase == disaggregated_queued_decode() || request.phase == disaggregated_decoding() || request.phase == disaggregated_transferring()
    if release_prefill && prefill_index >= 0 && state.workers[prefill_index].active_requests > 0 {
        state.workers[prefill_index].active_requests = state.workers[prefill_index].active_requests - 1
    }
    if release_decode && decode_index >= 0 && state.workers[decode_index].active_requests > 0 {
        state.workers[decode_index].active_requests = state.workers[decode_index].active_requests - 1
    }
    request.phase = disaggregated_cancelled()
    request.error_message = "cancelled"
    state.requests[request_index] = request
    new_disaggregated_result(state, request, empty_kv_transfer_ticket(), true, "")
}
