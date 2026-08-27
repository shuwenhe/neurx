package neurx.posttrain.training.stability

func clip_all_gradients(float[][] all_grads, float max_norm) float {
    float total = 0.0
    int layer = 0
    for layer < len(all_grads) {
        int i = 0
        for i < len(all_grads[layer]) {
            float g = all_grads[layer][i]
            total = total + g * g
            i = i + 1
        }
        layer = layer + 1
    }
    float global_norm = sqrt(total)
    if global_norm > max_norm {
        float scale = max_norm / global_norm
        layer = 0
        for layer < len(all_grads) {
            int i = 0
            for i < len(all_grads[layer]) {
                all_grads[layer][i] = all_grads[layer][i] * scale
                i = i + 1
            }
            layer = layer + 1
        }
    }
    return global_norm
}

func has_nan(float x) bool {
    return x != x
}

func has_inf(float x) bool {
    if x > 1e38 { return true }
    if x < -1e38 { return true }
    return false
}

func check_grads_healthy(float[][] all_grads) bool {
    int layer = 0
    for layer < len(all_grads) {
        int i = 0
        for i < len(all_grads[layer]) {
            float g = all_grads[layer][i]
            if has_nan(g) {
                println("[ERROR] NaN detected in gradients!")
                return false
            }
            if has_inf(g) {
                println("[ERROR] Inf detected in gradients!")
                return false
            }
            i = i + 1
        }
        layer = layer + 1
    }
    return true
}

func compute_accuracy(float[][][] logits, int[][] targets) float {
    int correct = 0
    int total = 0
    int b = 0
    for b < len(logits) {
        int t = 0
        for t < len(logits[b]) {
            int pred = 0
            float max_val = logits[b][t][0]
            int v = 1
            for v < len(logits[b][t]) {
                if logits[b][t][v] > max_val {
                    max_val = logits[b][t][v]
                    pred = v
                }
                v = v + 1
            }
            if pred == targets[b][t] {
                correct = correct + 1
            }
            total = total + 1
            t = t + 1
        }
        b = b + 1
    }
    if total == 0 { return 0.0 }
    return ((correct as float)) / ((total as float))
}
