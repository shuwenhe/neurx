package neurx.posttrain.training.gradient_utils

struct GlobalGradientStats {
    float total_norm
    float clip_coefficient
    bool clipped
    int total_params
}

func compute_global_grad_norm([][]float all_layer_grads) float {
    float total_norm_squared = 0.0

    int layer_idx = 0
    while layer_idx < len(all_layer_grads) {
        []float layer_grad = all_layer_grads[layer_idx]

        int i = 0
        while i < len(layer_grad) {
            float g = layer_grad[i]
            total_norm_squared = total_norm_squared + g * g
            i = i + 1
        }

        layer_idx = layer_idx + 1
    }

    return sqrt(total_norm_squared)
}

func clip_gradients_global([][]float all_layer_grads, float max_norm) GlobalGradientStats {

    float global_norm = compute_global_grad_norm(all_layer_grads)

    float clip_coef = max_norm / (global_norm + 1e-6)

    bool was_clipped = false

    if clip_coef < 1.0 {
        was_clipped = true

        int layer_idx = 0
        while layer_idx < len(all_layer_grads) {
            []float layer_grad = all_layer_grads[layer_idx]

            int i = 0
            while i < len(layer_grad) {
                layer_grad[i] = layer_grad[i] * clip_coef
                i = i + 1
            }

            layer_idx = layer_idx + 1
        }
    }

    int total_params = 0
    int idx = 0
    while idx < len(all_layer_grads) {
        total_params = total_params + len(all_layer_grads[idx])
        idx = idx + 1
    }

    GlobalGradientStats stats
    stats.total_norm = global_norm
    stats.clip_coefficient = clip_coef
    stats.clipped = was_clipped
    stats.total_params = total_params

    return stats
}

struct NaNInfStats {
    bool has_nan
    bool has_inf
    int nan_count
    int inf_count
    int total_checked
    string first_nan_layer
    string first_inf_layer
}

func is_nan(float x) bool {

    return x != x
}

func is_inf(float x) bool {

    float max_float = 3.4e38
    if x > max_float { return true }
    if x < (0.0 - max_float) { return true }
    return false
}

func check_gradients_nan_inf([][]float all_layer_grads, []string layer_names) NaNInfStats {
    NaNInfStats stats
    stats.has_nan = false
    stats.has_inf = false
    stats.nan_count = 0
    stats.inf_count = 0
    stats.total_checked = 0
    stats.first_nan_layer = ""
    stats.first_inf_layer = ""

    int layer_idx = 0
    while layer_idx < len(all_layer_grads) {
        []float layer_grad = all_layer_grads[layer_idx]
        string layer_name = ""
        if layer_idx < len(layer_names) {
            layer_name = layer_names[layer_idx]
        }

        int i = 0
        while i < len(layer_grad) {
            float g = layer_grad[i]
            stats.total_checked = stats.total_checked + 1

            if is_nan(g) {
                stats.nan_count = stats.nan_count + 1
                if !stats.has_nan {
                    stats.has_nan = true
                    stats.first_nan_layer = layer_name
                }
            }

            if is_inf(g) {
                stats.inf_count = stats.inf_count + 1
                if !stats.has_inf {
                    stats.has_inf = true
                    stats.first_inf_layer = layer_name
                }
            }

            i = i + 1
        }

        layer_idx = layer_idx + 1
    }

    return stats
}

func check_parameters_nan_inf([][]float all_layer_params, []string layer_names) NaNInfStats {

    return check_gradients_nan_inf(all_layer_params, layer_names)
}

struct GradientStatistics {
    float mean
    float std
    float min
    float max
    float l2_norm
    int zero_count
    float sparsity
}

func compute_gradient_statistics([]float gradients) GradientStatistics {
    GradientStatistics stats

    int n = len(gradients)
    if n == 0 {
        return stats
    }

    float sum = 0.0
    float min_val = gradients[0]
    float max_val = gradients[0]
    int zero_cnt = 0

    int i = 0
    while i < n {
        float g = gradients[i]
        sum = sum + g

        if g < min_val { min_val = g }
        if g > max_val { max_val = g }

        if g > -1e-8 && g < 1e-8 {
            zero_cnt = zero_cnt + 1
        }

        i = i + 1
    }

    float mean = sum / ((n as float))

    float var_sum = 0.0
    float l2_sum = 0.0

    i = 0
    while i < n {
        float g = gradients[i]
        float diff = g - mean
        var_sum = var_sum + diff * diff
        l2_sum = l2_sum + g * g
        i = i + 1
    }

    float variance = var_sum / ((n as float))
    float std_dev = sqrt(variance)
    float l2_norm = sqrt(l2_sum)

    float sparsity = ((zero_cnt as float)) / ((n as float))

    stats.mean = mean
    stats.std = std_dev
    stats.min = min_val
    stats.max = max_val
    stats.l2_norm = l2_norm
    stats.zero_count = zero_cnt
    stats.sparsity = sparsity

    return stats
}

func print_gradient_clip_stats(GlobalGradientStats stats) {
    println("[Gradient Clip]")
    print("  Total Norm: ")
    println(float_to_str_4(stats.total_norm))
    print("  Clipped: ")
    if stats.clipped {
        println("Yes")
        print("  Clip Coef: ")
        println(float_to_str_4(stats.clip_coefficient))
    } else {
        println("No")
    }
    print("  Total Params: ")
    println(int_to_str(stats.total_params))
}

func print_nan_inf_stats(NaNInfStats stats) {
    if stats.has_nan || stats.has_inf {
        println("[ERROR] Detected NaN/Inf in gradients!")

        if stats.has_nan {
            print("  NaN Count: ")
            println(int_to_str(stats.nan_count))
            print("  First NaN Layer: ")
            println(stats.first_nan_layer)
        }

        if stats.has_inf {
            print("  Inf Count: ")
            println(int_to_str(stats.inf_count))
            print("  First Inf Layer: ")
            println(stats.first_inf_layer)
        }

        println("  Training should be stopped or checkpointed!")
    }
}

func print_gradient_stats(GradientStatistics stats, string layer_name) {
    print("[Gradient Stats] ")
    println(layer_name)
    print("  Mean: ")
    println(float_to_str_4(stats.mean))
    print("  Std: ")
    println(float_to_str_4(stats.std))
    print("  L2 Norm: ")
    println(float_to_str_4(stats.l2_norm))
    print("  Sparsity: ")
    println(float_to_str_4(stats.sparsity))
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if negative { out = "-" + out }
    return out
}

func float_to_str_4(float value) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }

    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }

    string result = int_to_str(whole) + "."

    int i = 0
    while i < 4 {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }

    if negative { result = "-" + result }
    return result
}
