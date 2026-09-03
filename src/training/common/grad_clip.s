package neurx.training.grad_clip
struct grad_clip_config {
    string clip_mode
    float max_norm
    float max_value
    float min_value
}

func new_grad_clip_config(string clip_mode, float max_norm) grad_clip_config {
    grad_clip_config {
        clip_mode: clip_mode,
        max_norm: max_norm,
        max_value: max_norm,
        min_value: 0.0 - max_norm,
    }
}

func clip_grad_norm([]float grads, float max_norm) []float {
    if max_norm <= 0.0 {
        return grads
    }
    float total_norm = 0.0
    int i = 0
    for i < len(grads) {
        float g = grads[i]
        if g < 0.0 {
            g = 0.0 - g
        }
        total_norm = total_norm + g * g
        i = i + 1
    }
    total_norm = sqrt_approx(total_norm)
    if total_norm <= max_norm {
        return grads
    }
    float scale = max_norm / (total_norm + 0.0000001)
    []float clipped = make([]float, len(grads))
    i = 0
    for i < len(grads) {
        clipped[i] = grads[i] * scale
        i = i + 1
    }
    return clipped
}

func clip_grad_value([]float grads, float clip_value) []float {
    []float clipped = make([]float, len(grads))
    int i = 0
    for i < len(grads) {
        float g = grads[i]
        if g > clip_value {
            clipped[i] = clip_value
        } else {
            if g < 0.0 - clip_value {
                clipped[i] = 0.0 - clip_value
            } else {
                clipped[i] = g
            }
        }
        i = i + 1
    }
    return clipped
}

func clip_grad_by_norm([]float grads, float max_norm, []int param_indices) []float {
    []float subgrads = make([]float, len(param_indices))
    int i = 0
    for i < len(param_indices) {
        int idx = param_indices[i]
        if idx >= 0 {
            if idx < len(grads) {
                subgrads[i] = grads[idx]
            }
        }
        i = i + 1
    }
    float total_norm = 0.0
    i = 0
    for i < len(subgrads) {
        float g = subgrads[i]
        if g < 0.0 {
            g = 0.0 - g
        }
        total_norm = total_norm + g * g
        i = i + 1
    }
    total_norm = sqrt_approx(total_norm)
    if total_norm <= max_norm {
        return grads
    }
    float scale = max_norm / (total_norm + 0.0000001)
    []float clipped = make([]float, len(grads))
    i = 0
    for i < len(grads) {
        clipped[i] = grads[i]
        i = i + 1
    }
    i = 0
    for i < len(param_indices) {
        int idx = param_indices[i]
        if idx >= 0 {
            if idx < len(clipped) {
                clipped[idx] = clipped[idx] * scale
            }
        }
        i = i + 1
    }
    return clipped
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = 1.0
    if x > 1.0 {
        y = x
    }
    int i = 0
    for i < 32 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    return y
}
