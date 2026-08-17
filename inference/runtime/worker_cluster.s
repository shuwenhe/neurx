package neurx.inference.runtime.worker_cluster

func worker_starting_status() int { 1 }

func worker_ready_status() int { 2 }

func worker_busy_status() int { 3 }

func worker_failed_status() int { 4 }

func worker_recovering_status() int { 5 }

func worker_drained_status() int { 6 }

struct parallel_topology {
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    int expert_parallel_size
    int world_size
}

struct inference_worker {
    string worker_id
    string node_id
    int global_rank
    int local_rank
    int tensor_rank
    int pipeline_rank
    int data_rank
    int expert_rank
    int device_id
    int status
    int generation
    int last_heartbeat_ms
    int restart_count
    []string request_ids
    string failure_reason
}

struct worker_cluster_state {
    parallel_topology topology
    []inference_worker workers
    int heartbeat_timeout_ms
    int max_restarts
    int failures
    int recoveries
    bool initialized
    string error_message
}

struct worker_cluster_result {
    worker_cluster_state state
    inference_worker worker
    []string affected_request_ids
    bool success
    string error_message
}

func worker_empty() inference_worker {
    inference_worker worker
    worker.worker_id = ""
    worker.node_id = ""
    worker.global_rank = -1
    worker.local_rank = -1
    worker.tensor_rank = -1
    worker.pipeline_rank = -1
    worker.data_rank = -1
    worker.expert_rank = -1
    worker.device_id = -1
    worker.status = worker_failed_status()
    worker.generation = 0
    worker.last_heartbeat_ms = 0
    worker.restart_count = 0
    worker.request_ids = []
    worker.failure_reason = ""
    worker
}

func worker_new_result(worker_cluster_state state, inference_worker worker, bool success, string error_message) worker_cluster_result {
    worker_cluster_result result
    result.state = state
    result.worker = worker
    result.affected_request_ids = []
    result.success = success
    result.error_message = error_message
    result
}

func worker_normalize_topology(parallel_topology topology) parallel_topology {
    if topology.tensor_parallel_size <= 0 { topology.tensor_parallel_size = 1 }
    if topology.pipeline_parallel_size <= 0 { topology.pipeline_parallel_size = 1 }
    if topology.data_parallel_size <= 0 { topology.data_parallel_size = 1 }
    if topology.expert_parallel_size <= 0 { topology.expert_parallel_size = 1 }
    topology.world_size = topology.tensor_parallel_size * topology.pipeline_parallel_size * topology.data_parallel_size
    topology
}

func worker_topology_valid(parallel_topology topology) bool {
    if topology.tensor_parallel_size <= 0 || topology.pipeline_parallel_size <= 0 || topology.data_parallel_size <= 0 || topology.expert_parallel_size <= 0 { return false }
    if topology.world_size != topology.tensor_parallel_size * topology.pipeline_parallel_size * topology.data_parallel_size { return false }
    int expert_domain = topology.tensor_parallel_size * topology.data_parallel_size
    expert_domain / topology.expert_parallel_size * topology.expert_parallel_size == expert_domain
}

func new_worker_cluster(parallel_topology topology, int heartbeat_timeout_ms, int max_restarts) worker_cluster_state {
    worker_cluster_state state
    state.topology = worker_normalize_topology(topology)
    state.workers = []
    state.heartbeat_timeout_ms = heartbeat_timeout_ms
    if state.heartbeat_timeout_ms <= 0 { state.heartbeat_timeout_ms = 30000 }
    state.max_restarts = max_restarts
    if state.max_restarts < 0 { state.max_restarts = 0 }
    state.failures = 0
    state.recoveries = 0
    state.initialized = worker_topology_valid(state.topology)
    state.error_message = ""
    if !state.initialized { state.error_message = "invalid parallel topology" }
    state
}

func worker_at(worker_cluster_state state, int index) inference_worker {
    state.workers[index]
}

func worker_find(worker_cluster_state state, string worker_id) int {
    int i = 0
    while i < len(state.workers) {
        if state.workers[i].worker_id == worker_id { return i }
        i = i + 1
    }
    -1
}

func worker_find_rank(worker_cluster_state state, int global_rank) int {
    int i = 0
    while i < len(state.workers) {
        if state.workers[i].global_rank == global_rank { return i }
        i = i + 1
    }
    -1
}

func worker_string_contains([]string values, string value) bool {
    int i = 0
    while i < len(values) {
        if values[i] == value { return true }
        i = i + 1
    }
    false
}

func worker_string_at([]string values, int index) string {
    values[index]
}

func worker_string_remove([]string values, string value) []string {
    []string filtered = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        if values[i] != value { filtered = append(filtered, values[i]) }
        i = i + 1
    }
    filtered
}

func worker_build(string worker_id, string node_id, int global_rank, int local_rank, int device_id, parallel_topology topology, int now_ms) inference_worker {
    inference_worker worker
    int replica_width = topology.tensor_parallel_size * topology.pipeline_parallel_size
    int replica_offset = global_rank - global_rank / replica_width * replica_width
    worker.worker_id = worker_id
    worker.node_id = node_id
    worker.global_rank = global_rank
    worker.local_rank = local_rank
    worker.tensor_rank = replica_offset - replica_offset / topology.tensor_parallel_size * topology.tensor_parallel_size
    worker.pipeline_rank = replica_offset / topology.tensor_parallel_size
    worker.data_rank = global_rank / replica_width
    int expert_source = worker.data_rank * topology.tensor_parallel_size + worker.tensor_rank
    worker.expert_rank = expert_source - expert_source / topology.expert_parallel_size * topology.expert_parallel_size
    worker.device_id = device_id
    worker.status = worker_starting_status()
    worker.generation = 1
    worker.last_heartbeat_ms = now_ms
    worker.restart_count = 0
    worker.request_ids = []
    worker.failure_reason = ""
    worker
}

func worker_register(worker_cluster_state state, string worker_id, string node_id, int global_rank, int local_rank, int device_id, int now_ms) worker_cluster_result {
    if !state.initialized { return worker_new_result(state, worker_empty(), false, state.error_message) }
    if worker_id == "" || node_id == "" || global_rank < 0 || global_rank >= state.topology.world_size || local_rank < 0 || device_id < 0 {
        return worker_new_result(state, worker_empty(), false, "invalid worker metadata")
    }
    if worker_find(state, worker_id) >= 0 || worker_find_rank(state, global_rank) >= 0 {
        return worker_new_result(state, worker_empty(), false, "duplicate worker or rank")
    }
    inference_worker worker = worker_build(worker_id, node_id, global_rank, local_rank, device_id, state.topology, now_ms)
    state.workers = append(state.workers, worker)
    worker_new_result(state, worker, true, "")
}

func worker_mark_ready(worker_cluster_state state, string worker_id, int generation, int now_ms) worker_cluster_result {
    int index = worker_find(state, worker_id)
    if index < 0 { return worker_new_result(state, worker_empty(), false, "worker not found") }
    inference_worker worker = worker_at(state, index)
    if generation != worker.generation { return worker_new_result(state, worker, false, "stale worker generation") }
    if worker.status != worker_starting_status() && worker.status != worker_recovering_status() {
        return worker_new_result(state, worker, false, "worker cannot become ready")
    }
    if worker.status == worker_recovering_status() { state.recoveries = state.recoveries + 1 }
    worker.status = worker_ready_status()
    worker.last_heartbeat_ms = now_ms
    worker.failure_reason = ""
    state.workers[index] = worker
    worker_new_result(state, worker, true, "")
}

func worker_heartbeat(worker_cluster_state state, string worker_id, int generation, int now_ms) worker_cluster_result {
    int index = worker_find(state, worker_id)
    if index < 0 { return worker_new_result(state, worker_empty(), false, "worker not found") }
    inference_worker worker = worker_at(state, index)
    if generation != worker.generation { return worker_new_result(state, worker, false, "stale worker generation") }
    if worker.status == worker_failed_status() || worker.status == worker_drained_status() {
        return worker_new_result(state, worker, false, "worker does not accept heartbeats")
    }
    worker.last_heartbeat_ms = now_ms
    state.workers[index] = worker
    worker_new_result(state, worker, true, "")
}

func worker_assign(worker_cluster_state state, string worker_id, string request_id) worker_cluster_result {
    int index = worker_find(state, worker_id)
    if index < 0 { return worker_new_result(state, worker_empty(), false, "worker not found") }
    inference_worker worker = worker_at(state, index)
    if worker.status != worker_ready_status() && worker.status != worker_busy_status() {
        return worker_new_result(state, worker, false, "worker is unavailable")
    }
    if !worker_string_contains(worker.request_ids, request_id) { worker.request_ids = append(worker.request_ids, request_id) }
    worker.status = worker_busy_status()
    state.workers[index] = worker
    worker_new_result(state, worker, true, "")
}

func worker_release(worker_cluster_state state, string worker_id, string request_id) worker_cluster_result {
    int index = worker_find(state, worker_id)
    if index < 0 { return worker_new_result(state, worker_empty(), false, "worker not found") }
    inference_worker worker = worker_at(state, index)
    worker.request_ids = worker_string_remove(worker.request_ids, request_id)
    if len(worker.request_ids) == 0 && worker.status == worker_busy_status() { worker.status = worker_ready_status() }
    state.workers[index] = worker
    worker_new_result(state, worker, true, "")
}

func worker_fail(worker_cluster_state state, string worker_id, string reason) worker_cluster_result {
    int index = worker_find(state, worker_id)
    if index < 0 { return worker_new_result(state, worker_empty(), false, "worker not found") }
    inference_worker worker = worker_at(state, index)
    worker_cluster_result result = worker_new_result(state, worker, true, "")
    result.affected_request_ids = worker.request_ids
    worker.status = worker_failed_status()
    worker.failure_reason = reason
    worker.request_ids = []
    state.failures = state.failures + 1
    state.workers[index] = worker
    result.state = state
    result.worker = worker
    result
}

func worker_begin_recovery(worker_cluster_state state, string worker_id, int now_ms) worker_cluster_result {
    int index = worker_find(state, worker_id)
    if index < 0 { return worker_new_result(state, worker_empty(), false, "worker not found") }
    inference_worker worker = worker_at(state, index)
    if worker.status != worker_failed_status() { return worker_new_result(state, worker, false, "worker is not failed") }
    if worker.restart_count >= state.max_restarts {
        worker.status = worker_drained_status()
        state.workers[index] = worker
        return worker_new_result(state, worker, false, "worker restart limit reached")
    }
    worker.status = worker_recovering_status()
    worker.generation = worker.generation + 1
    worker.restart_count = worker.restart_count + 1
    worker.last_heartbeat_ms = now_ms
    worker.failure_reason = ""
    state.workers[index] = worker
    worker_new_result(state, worker, true, "")
}

func worker_expire_heartbeats(worker_cluster_state state, int now_ms) worker_cluster_result {
    worker_cluster_result result = worker_new_result(state, worker_empty(), true, "")
    int i = 0
    while i < len(state.workers) {
        inference_worker worker = worker_at(state, i)
        bool active = worker.status == worker_ready_status() || worker.status == worker_busy_status() || worker.status == worker_starting_status() || worker.status == worker_recovering_status()
        if active && now_ms - worker.last_heartbeat_ms > state.heartbeat_timeout_ms {
            int j = 0
            while j < len(worker.request_ids) {
                string request_id = worker_string_at(worker.request_ids, j)
                if !worker_string_contains(result.affected_request_ids, request_id) {
                    result.affected_request_ids = append(result.affected_request_ids, request_id)
                }
                j = j + 1
            }
            worker.status = worker_failed_status()
            worker.failure_reason = "worker heartbeat timeout"
            worker.request_ids = []
            state.workers[i] = worker
            state.failures = state.failures + 1
        }
        i = i + 1
    }
    result.state = state
    result
}

func worker_ready_count(worker_cluster_state state) int {
    int count = 0
    int i = 0
    while i < len(state.workers) {
        int status = state.workers[i].status
        if status == worker_ready_status() || status == worker_busy_status() { count = count + 1 }
        i = i + 1
    }
    count
}

func worker_cluster_ready(worker_cluster_state state) bool {
    state.initialized && len(state.workers) == state.topology.world_size && worker_ready_count(state) == state.topology.world_size
}

func worker_replica_ready(worker_cluster_state state, int data_rank) bool {
    if data_rank < 0 || data_rank >= state.topology.data_parallel_size { return false }
    int expected = state.topology.tensor_parallel_size * state.topology.pipeline_parallel_size
    int count = 0
    int i = 0
    while i < len(state.workers) {
        inference_worker worker = state.workers[i]
        if worker.data_rank == data_rank && (worker.status == worker_ready_status() || worker.status == worker_busy_status()) { count = count + 1 }
        i = i + 1
    }
    count == expected
}
