package neurx.amp

struct amp_runtime_config {
    string dtype
    bool enabled
    bool enable_grad_scaling
    float initial_scale
}

func new_amp_runtime_config(string dtype, bool enabled) amp_runtime_config {
    amp_runtime_config {
        dtype: dtype,
        enabled: enabled,
        enable_grad_scaling: true,
        initial_scale: 65536.0,
    }
}

func amp_enabled(amp_runtime_config cfg) bool {
    cfg.enabled
}

func amp_dtype(amp_runtime_config cfg) string {
    cfg.dtype
}

