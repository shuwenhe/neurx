package neurx.inference.compute.gpu_tbo_executor

func gpu_op_attention() int { 1 }

func gpu_op_moe_dispatch() int { 2 }

func gpu_op_moe_experts() int { 3 }

func gpu_op_moe_combine() int { 4 }

func gpu_op_all_gather() int { 5 }

func gpu_op_reduce_scatter() int { 6 }

func gpu_op_copy() int { 7 }

func gpu_exec_pending() int { 0 }

func gpu_exec_running() int { 1 }

func gpu_exec_complete() int { 2 }

func gpu_exec_failed() int { 3 }

struct gpu_tbo_config {
    int capacity
    int device_id
    int compute_stream_a
    int compute_stream_b
    int communication_stream
    int world_size
    bool cuda_available
    bool collective_available
}

struct gpu_tbo_executor_state {
    gpu_tbo_config config
    int[] operation_ids
    int[] operation_types
    int[] batch_ids
    int[] stage_indices
    int[] stream_ids
    int[] input_ptr_low
    int[] output_ptr_low
    int[] element_counts
    int[] dependency_ids
    int[] statuses
    int[] backend_codes
    int operation_count
    int completed_count
    int failed_count
    int synchronization_count
}

struct gpu_tbo_execution_result {
    gpu_tbo_executor_state state
    int operation_id
    int operation_type
    int stream_id
    int backend_code
    bool launched
    bool complete
}

func gpu_tbo_int_array(int capacity) int[] {
    int[] values = int[]{cap: capacity}
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_gpu_tbo_executor(gpu_tbo_config config) gpu_tbo_executor_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 4096 { config.capacity = 4096 }
    if config.world_size <= 0 { config.world_size = 1 }
    gpu_tbo_executor_state {
        config: config,
        operation_ids: gpu_tbo_int_array(config.capacity), operation_types: gpu_tbo_int_array(config.capacity), batch_ids: gpu_tbo_int_array(config.capacity), stage_indices: gpu_tbo_int_array(config.capacity), stream_ids: gpu_tbo_int_array(config.capacity), input_ptr_low: gpu_tbo_int_array(config.capacity), output_ptr_low: gpu_tbo_int_array(config.capacity), element_counts: gpu_tbo_int_array(config.capacity), dependency_ids: gpu_tbo_int_array(config.capacity), statuses: gpu_tbo_int_array(config.capacity), backend_codes: gpu_tbo_int_array(config.capacity),
        operation_count: 0, completed_count: 0, failed_count: 0, synchronization_count: 0,
    }
}

func gpu_tbo_find_operation(gpu_tbo_executor_state state, int operation_id) int {
    int i = 0
    for i < state.operation_count {
        if state.operation_ids[i] == operation_id { return i }
        i = i + 1
    }
    0 - 1
}

func gpu_tbo_valid_type(int operation_type) bool {
    operation_type >= gpu_op_attention() && operation_type <= gpu_op_copy()
}

func gpu_tbo_enqueue(gpu_tbo_executor_state state, int operation_id, int operation_type, int batch_id, int stage_index, int stream_id, int input_ptr_low, int output_ptr_low, int element_count, int dependency_id) gpu_tbo_executor_state {
    if operation_id <= 0 || !gpu_tbo_valid_type(operation_type) || element_count <= 0 || input_ptr_low == 0 || output_ptr_low == 0 || state.operation_count >= state.config.capacity || gpu_tbo_find_operation(state, operation_id) >= 0 { return state }
    int slot = state.operation_count
    state.operation_ids[slot] = operation_id
    state.operation_types[slot] = operation_type
    state.batch_ids[slot] = batch_id
    state.stage_indices[slot] = stage_index
    state.stream_ids[slot] = stream_id
    state.input_ptr_low[slot] = input_ptr_low
    state.output_ptr_low[slot] = output_ptr_low
    state.element_counts[slot] = element_count
    state.dependency_ids[slot] = dependency_id
    state.statuses[slot] = gpu_exec_pending()
    state.operation_count = state.operation_count + 1
    state
}

func gpu_tbo_dependency_ready(gpu_tbo_executor_state state, int dependency_id) bool {
    if dependency_id == 0 { return true }
    int slot = gpu_tbo_find_operation(state, dependency_id)
    slot >= 0 && state.statuses[slot] == gpu_exec_complete()
}

func gpu_tbo_backend_available(gpu_tbo_executor_state state, int operation_type) bool {
    if !state.config.cuda_available { return false }
    if operation_type == gpu_op_all_gather() || operation_type == gpu_op_reduce_scatter() { return state.config.collective_available && state.config.world_size > 1 }
    true
}

func gpu_tbo_next_ready(gpu_tbo_executor_state state) int {
    int selected = 0 - 1
    int i = 0
    for i < state.operation_count {
        if selected < 0 && state.statuses[i] == gpu_exec_pending() && gpu_tbo_dependency_ready(state, state.dependency_ids[i]) { selected = i }
        i = i + 1
    }
    selected
}

func gpu_tbo_execute_next(gpu_tbo_executor_state state, int native_backend_code) gpu_tbo_execution_result {
    int slot = gpu_tbo_next_ready(state)
    if slot < 0 { return gpu_tbo_execution_result {state: state, operation_id: 0, operation_type: 0, stream_id: 0, backend_code: 0, launched: false, complete: false} }
    int operation_type = state.operation_types[slot]
    if !gpu_tbo_backend_available(state, operation_type) {
        state.statuses[slot] = gpu_exec_failed()
        state.backend_codes[slot] = 503
        state.failed_count = state.failed_count + 1
        return gpu_tbo_execution_result {state: state, operation_id: state.operation_ids[slot], operation_type: operation_type, stream_id: state.stream_ids[slot], backend_code: 503, launched: false, complete: false}
    }
    state.statuses[slot] = gpu_exec_running()
    state.backend_codes[slot] = native_backend_code
    if native_backend_code == 0 {
        state.statuses[slot] = gpu_exec_complete()
        state.completed_count = state.completed_count + 1
        if operation_type == gpu_op_all_gather() || operation_type == gpu_op_reduce_scatter() { state.synchronization_count = state.synchronization_count + 1 }
    } else {
        state.statuses[slot] = gpu_exec_failed()
        state.failed_count = state.failed_count + 1
    }
    gpu_tbo_execution_result {state: state, operation_id: state.operation_ids[slot], operation_type: operation_type, stream_id: state.stream_ids[slot], backend_code: native_backend_code, launched: true, complete: native_backend_code == 0}
}

func gpu_tbo_all_terminal(gpu_tbo_executor_state state) bool {
    state.completed_count + state.failed_count == state.operation_count
}
