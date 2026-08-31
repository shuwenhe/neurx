package neurx.amp.training
import "neurx.autograd"
    FP32 = 0
    FP16 = 1
    BF16 = 2
}

struct amp_config {
    amp_dtype dtype
    bool enable_grad_scaling
    float initial_scale
    float scale_factor
    int scale_window
    float min_scale
    float max_scale
    int growth_interval
}

struct amp_state {
    float scale
    int growth_step
    bool last_overflow
    fp16_params: []autograd.tensor
    fp16_grads: []autograd.tensor
    fp32_params: []autograd.tensor
}

struct mixed_precision_model {
    pointer model
    amp_config amp_config
    amp_state amp_state
    param_groups: [][]autograd.tensor
}

struct autocast_state {
    bool enabled
    int dtype
}

struct grad_scaler_state {
    float scale
    float growth_factor
    float backoff_factor
    int growth_interval
    bool found_inf
}

func new_autocast_state(bool enabled, int dtype) autocast_state {
    autocast_state {
        enabled: enabled,
        dtype: dtype,
    }
}

func autocast_enter(autocast_state state) autocast_state {
    autocast_state {
        enabled: true,
        dtype: state.dtype,
    }
}

func autocast_exit(autocast_state state) autocast_state {
    autocast_state {
        enabled: false,
        dtype: state.dtype,
    }
}

func is_autocast_enabled(autocast_state state) bool {
    state.enabled
}

func new_grad_scaler(float scale, float growth_factor, float backoff_factor, int growth_interval, bool enabled) grad_scaler_state {
    grad_scaler_state {
        scale: scale,
        growth_factor: growth_factor,
        backoff_factor: backoff_factor,
        growth_interval: growth_interval,
        found_inf: false,
    }
}

func grad_scaler_step(grad_scaler_state scaler, float value) grad_scaler_state {
    bool found_inf = value > 1000000000000000000000000000000000000.0 || value < -1000000000000000000000000000000000000.0 || value != value
    float next_scale = scaler.scale
    if found_inf {
        next_scale = scaler.scale * scaler.backoff_factor
    }
    grad_scaler_state {
        scale: next_scale,
        growth_factor: scaler.growth_factor,
        backoff_factor: scaler.backoff_factor,
        growth_interval: scaler.growth_interval,
        found_inf: found_inf,
    }
}

func grad_scaler_get_scale(grad_scaler_state scaler) float {
    scaler.scale
}

func grad_scaler_found_inf(grad_scaler_state scaler) bool {
    scaler.found_inf
}

func new_amp_config(amp_dtype dtype, bool enable_grad_scaling) amp_config {
    amp_config config {
        dtype: dtype,
        enable_grad_scaling: enable_grad_scaling,
        initial_scale: 65536.0,
        scale_factor: 2.0,
        scale_window: 1000,
        min_scale: 1.0,
        max_scale: 2.0 * 65536.0,
        growth_interval: 100,
    }
    config
}

func new_amp_state(amp_config config, int num_params) amp_state {
    amp_state state {
        scale: config.initial_scale,
        growth_step: 0,
        last_overflow: false,
        fp16_params: make([]autograd.tensor, num_params),
        fp16_grads: make([]autograd.tensor, num_params),
        fp32_params: make([]autograd.tensor, num_params),
    }
    state
}

func amp_init_params([]autograd.tensor params, amp_config config) amp_state {
    int n = len(params)
    amp_state state = new_amp_state(config, n)
    for i := 0; i < n; i += 1 {
        autograd.tensor fp32 = params[i]
        autograd.tensor fp16 = autograd.tensor_cast(fp32, config.dtype)
        state.fp32_params = append(state.fp32_params, fp32)
        state.fp16_params = append(state.fp16_params, fp16)
        state.fp16_grads = append(state.fp16_grads, autograd.tensor_zero_like(fp16))
    }
    state
}

func amp_cast_to_fp16(mixed_precision_model model) mixed_precision_model {
    for i := 0; i < len(model.amp_state.fp32_params); i += 1 {
        model.amp_state.fp16_params[i] = autograd.tensor_cast(
            model.amp_state.fp32_params[i],
            model.amp_config.dtype,
        )
    }
    model
}

func amp_cast_grad_to_fp32(mixed_precision_model model) mixed_precision_model {
    for i := 0; i < len(model.amp_state.fp16_grads); i += 1 {
        autograd.tensor fp32_grad = autograd.tensor_cast(
            model.amp_state.fp16_grads[i],
            amp_dtype.FP32,
        )
        if model.amp_config.enable_grad_scaling {
            fp32_grad = autograd.tensor_div_scalar(fp32_grad, model.amp_state.scale)
        }
        autograd.tensor_add_inplace(model.amp_state.fp32_params[i].grad, fp32_grad)
    }
    model
}

func amp_scale_loss(float loss, amp_state state) float {
    if state.last_overflow {
        return loss
    }
    loss * state.scale
}

func amp_check_overflow([]autograd.tensor grads) bool {
    for i := 0; i < len(grads); i += 1 {
        if autograd.tensor_has_nan(grads[i]) || autograd.tensor_has_inf(grads[i]) {
            return true
        }
    }
    false
}

func amp_update_scale(amp_state state, amp_config config, bool has_overflow) amp_state {
    if has_overflow {
        state.scale = max(state.scale / config.scale_factor, config.min_scale)
        state.last_overflow = true
        state.growth_step = 0
    } else {
        state.last_overflow = false
        state.growth_step = state.growth_step + 1
        if state.growth_step >= config.growth_interval {
            if state.scale < config.max_scale {
                state.scale = min(state.scale * config.scale_factor, config.max_scale)
            }
            state.growth_step = 0
        }
    }
    state
}

func amp_step(mixed_precision_model model) bool {
    bool overflow = amp_check_overflow(model.amp_state.fp16_grads)
    if overflow {
        model.amp_state = amp_update_scale(model.amp_state, model.amp_config, true)
        autograd.zero_grad(model.amp_state.fp32_params)
        return false
    }
    amp_cast_grad_to_fp32(model)
    model.amp_state = amp_update_scale(model.amp_state, model.amp_config, false)
    true
}

func amp_grad_scaling(mixed_precision_model model) mixed_precision_model {
    if !model.amp_config.enable_grad_scaling {
        return model
    }
    float scale = model.amp_state.scale
    for i := 0; i < len(model.amp_state.fp16_grads); i += 1 {
        autograd.tensor_mul_scalar_inplace(model.amp_state.fp16_grads[i], scale)
    }
    model
}

func amp_sync_params(mixed_precision_model model) mixed_precision_model {
    for i := 0; i < len(model.amp_state.fp32_params); i += 1 {
        model.amp_state.fp16_params[i] = autograd.tensor_cast(
            model.amp_state.fp32_params[i],
            model.amp_config.dtype,
        )
    }
    model
}

func amp_zero_grad(mixed_precision_model model) mixed_precision_model {
    autograd.zero_grad(model.amp_state.fp32_params)
    for i := 0; i < len(model.amp_state.fp16_grads); i += 1 {
        autograd.tensor_fill_zero(model.amp_state.fp16_grads[i])
    }
    model
}

func mixed_precision_forward(mixed_precision_model model, func f) float {
    amp_cast_to_fp16(model)
    float loss = f()
    if model.amp_config.enable_grad_scaling {
        loss = amp_scale_loss(loss, model.amp_state)
    }
    loss
}

func mixed_precision_backward(mixed_precision_model model, float loss) mixed_precision_model {
    autograd.backward(loss)
    for i := 0; i < len(model.amp_state.fp16_params); i += 1 {
        autograd.tensor_copy(model.amp_state.fp16_grads[i], model.amp_state.fp16_params[i].grad)
    }
    amp_grad_scaling(model)
    model
}

func max(float a, float b) float {
    if a > b {
        return a
    }
    b
}

func min(float a, float b) float {
    if a < b {
        return a
    }
    b
}
