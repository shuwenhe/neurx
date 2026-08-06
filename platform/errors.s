package neurx.platform.errors

struct platform_error_state {
    string kind
    string message
    bool active
}

func new_tensor_error(string message) platform_error_state {
    platform_error_state {
        kind: "TensorError",
        message: message,
        active: true,
    }
}

func new_configuration_error(string message) platform_error_state {
    platform_error_state {
        kind: "ConfigurationError",
        message: message,
        active: true,
    }
}

func new_backend_not_available_error(string message) platform_error_state {
    platform_error_state {
        kind: "BackendNotAvailableError",
        message: message,
        active: true,
    }
}

func new_runtime_validation_error(string message) platform_error_state {
    platform_error_state {
        kind: "RuntimeValidationError",
        message: message,
        active: true,
    }
}

func clear_error() platform_error_state {
    platform_error_state {
        kind: "",
        message: "",
        active: false,
    }
}

func platform_error_kind(platform_error_state state) string {
    state.kind
}

func platform_error_message(platform_error_state state) string {
    state.message
}

func platform_error_active(platform_error_state state) bool {
    state.active
}

func platform_error_state_dict(platform_error_state state) platform_error_state {
    platform_error_state {
        kind: state.kind,
        message: state.message,
        active: state.active,
    }
}

func platform_error_load_state_dict(platform_error_state state, platform_error_state other) platform_error_state {
    platform_error_state {
        kind: other.kind,
        message: other.message,
        active: other.active,
    }
}

