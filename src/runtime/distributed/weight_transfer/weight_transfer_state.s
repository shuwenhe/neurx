package neurx.distributed.weight_transfer

func weight_update_idle() int { 0 }

func weight_update_active() int { 1 }

func weight_update_complete() int { 2 }

func weight_update_failed() int { 3 }

struct weight_parameter_metadata {
    string name
    string dtype
    []int shape
    int byte_count
}

struct weight_transfer_config {
    string backend
    int rank
    int world_size
    bool supports_draft_model
}

struct weight_transfer_state {
    weight_transfer_config config
    bool initialized
    int phase
    int update_id
    int expected_parameters
    int received_parameters
    int bytes_received
    string last_parameter_name
    string error_message
}

struct weight_apply_result {
    weight_transfer_state state
    bool success
    string error_message
}

func weight_transfer_config_valid(weight_transfer_config config) bool {
    bool backend_valid = config.backend == "nccl" || config.backend == "ipc" || config.backend == "sparse_nccl"
    backend_valid && config.world_size > 0 && config.rank >= 0 && config.rank < config.world_size
}

func init_weight_transfer_engine(weight_transfer_config config) weight_transfer_state {
    bool initialized = weight_transfer_config_valid(config)
    string error_message = ""
    if !initialized {
        error_message = "invalid weight transfer configuration"
    }
    weight_transfer_state {
        config: config,
        initialized: initialized,
        phase: weight_update_idle(),
        update_id: 0,
        expected_parameters: 0,
        received_parameters: 0,
        bytes_received: 0,
        last_parameter_name: "",
        error_message: error_message,
    }
}

func start_weight_update(weight_transfer_state state, int update_id, int expected_parameters, bool draft_model) weight_apply_result {
    if !state.initialized {
        return weight_apply_result {state: state, success: false, error_message: "weight transfer engine is not initialized"}
    }
    if state.phase == weight_update_active() {
        return weight_apply_result {state: state, success: false, error_message: "weight update is already active"}
    }
    if expected_parameters <= 0 || update_id < 0 {
        return weight_apply_result {state: state, success: false, error_message: "invalid weight update metadata"}
    }
    if draft_model && !state.config.supports_draft_model {
        return weight_apply_result {state: state, success: false, error_message: "backend does not support draft model updates"}
    }
    weight_apply_result {
        state: weight_transfer_state {
            config: state.config,
            initialized: state.initialized,
            phase: weight_update_active(),
            update_id: update_id,
            expected_parameters: expected_parameters,
            received_parameters: 0,
            bytes_received: 0,
            last_parameter_name: "",
            error_message: "",
        },
        success: true,
        error_message: "",
    }
}

func apply_weight_parameter(weight_transfer_state state, weight_parameter_metadata metadata) weight_apply_result {
    if state.phase != weight_update_active() {
        return weight_apply_result {state: state, success: false, error_message: "weight update is not active"}
    }
    if metadata.name == "" || metadata.dtype == "" || metadata.byte_count <= 0 || len(metadata.shape) == 0 {
        return weight_apply_result {state: state, success: false, error_message: "invalid parameter metadata"}
    }
    if metadata.name == state.last_parameter_name {
        return weight_apply_result {state: state, success: false, error_message: "duplicate consecutive parameter in weight update"}
    }
    if state.received_parameters >= state.expected_parameters {
        return weight_apply_result {state: state, success: false, error_message: "weight update received too many parameters"}
    }
    weight_apply_result {
        state: weight_transfer_state {
            config: state.config,
            initialized: state.initialized,
            phase: state.phase,
            update_id: state.update_id,
            expected_parameters: state.expected_parameters,
            received_parameters: state.received_parameters + 1,
            bytes_received: state.bytes_received + metadata.byte_count,
            last_parameter_name: metadata.name,
            error_message: "",
        },
        success: true,
        error_message: "",
    }
}

func finish_weight_update(weight_transfer_state state) weight_apply_result {
    if state.phase != weight_update_active() {
        return weight_apply_result {state: state, success: false, error_message: "weight update is not active"}
    }
    if state.received_parameters != state.expected_parameters {
        weight_transfer_state failed_state = weight_transfer_state {
            config: state.config,
            initialized: state.initialized,
            phase: weight_update_failed(),
            update_id: state.update_id,
            expected_parameters: state.expected_parameters,
            received_parameters: state.received_parameters,
            bytes_received: state.bytes_received,
            last_parameter_name: state.last_parameter_name,
            error_message: "weight update parameter count mismatch",
        }
        return weight_apply_result {state: failed_state, success: false, error_message: failed_state.error_message}
    }
    weight_apply_result {
        state: weight_transfer_state {
            config: state.config,
            initialized: state.initialized,
            phase: weight_update_complete(),
            update_id: state.update_id,
            expected_parameters: state.expected_parameters,
            received_parameters: state.received_parameters,
            bytes_received: state.bytes_received,
            last_parameter_name: state.last_parameter_name,
            error_message: "",
        },
        success: true,
        error_message: "",
    }
}

func shutdown_weight_transfer_engine(weight_transfer_state state) weight_transfer_state {
    weight_transfer_state {
        config: state.config,
        initialized: false,
        phase: weight_update_idle(),
        update_id: state.update_id,
        expected_parameters: state.expected_parameters,
        received_parameters: state.received_parameters,
        bytes_received: state.bytes_received,
        last_parameter_name: state.last_parameter_name,
        error_message: state.error_message,
    }
}
