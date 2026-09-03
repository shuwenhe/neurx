package neurx.quantization
use neurx.tensor.tensor
use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}
use neurx.strings.{concat2, from_i32, strings_eq, substring}
    INT8_DYNAMIC,
    INT8_STATIC,
    INT8_PER_CHANNEL,
    INT4_WEIGHT,
    INT4_FULL,
    FP8_E4M3,
}

struct quantization_stats {
    quantization_type quantization_method
    float min_value
    float max_value
    float mean_value
    float std_value
    int num_samples_used
    string calibration_method
    float mse_error
    float mae_error
    float kl_divergence
}

struct quantized_tensor {
    float scale
    int zero_point
    vector data_int8
    vector data_int4
    vector original_shape
    quantization_type dtype
    bool is_per_channel
    vector channel_scales
}

struct quantization_config {
    quantization_type quantization_type
    bool per_channel_for_weights
    bool per_tensor_for_activations
    int calibration_samples
    string calibration_method
    float percentile_value
    bool use_symmetric
    vector skip_layer_types
    vector skip_layers
}

struct quantization_state {
    quantization_config config
    vector activation_ranges
    bool calibration_complete
    int num_layers_quantized
    float total_size_reduction
    int num_params_original
    int num_params_quantized
}

func new_quantization_config(qtype quantization_type) quantization_config {
    quantization_config config
    config.quantization_type = qtype
    config.per_channel_for_weights = true
    config.per_tensor_for_activations = true
    config.calibration_samples = 1024
    config.calibration_method = "entropy"
    config.percentile_value = 99.99
    config.use_symmetric = false
    config.skip_layer_types = allocate_vector(5, 0.0)
    config.skip_layers = allocate_vector(10, 0.0)
    return config
}

func quantize_tensor(
    vector tensor,
    quantization_config config,
    quantization_stats stats
) quantized_tensor {
    quantized_tensor q_tensor
    q_tensor.original_shape = allocate_vector(4, 0.0)
    q_tensor.dtype = config.quantization_type
    q_tensor.is_per_channel = config.per_channel_for_weights
    (float min_val, float max_val) = compute_quantization_range(tensor, config, stats)
    int quantization_levels = 255
    if config.quantization_type == INT4_WEIGHT || config.quantization_type == INT4_FULL {
        quantization_levels = 15
    }
    q_tensor.scale = (max_val - min_val) / float(quantization_levels)
    if config.use_symmetric {
        q_tensor.zero_point = 0
    } else {
        q_tensor.zero_point = int(-min_val / q_tensor.scale)
    }
    q_tensor.data_int8 = allocate_vector(length(tensor), 0.0)
    for i in range(0, length(tensor)) {
        int q_val = int((tensor[i] / q_tensor.scale) + float(q_tensor.zero_point))
        if config.quantization_type == INT8_DYNAMIC || config.quantization_type == INT8_STATIC || config.quantization_type == INT8_PER_CHANNEL {
            q_val = clip_int(q_val, 0, 255)
        } else if config.quantization_type == INT4_WEIGHT || config.quantization_type == INT4_FULL {
            q_val = clip_int(q_val, 0, 15)
        }
        q_tensor.data_int8[i] = float(q_val)
    }
    return q_tensor
}

func dequantize_tensor(quantized_tensor q_tensor) vector {
    vector tensor = allocate_vector(length(q_tensor.data_int8), 0.0)
    for i in range(0, length(q_tensor.data_int8)) {
        int q_val = int(q_tensor.data_int8[i])
        tensor[i] = (float(q_val - q_tensor.zero_point)) * q_tensor.scale
    }
    return tensor
}

func post_training_quantization(
    vector model_layers,
    vector calibration_data,
    quantization_config config
) vector {
    vector quantized_layers = allocate_vector(length(model_layers), 0.0)
    for layer_idx in range(0, length(model_layers)) {
        vector layer = model_layers[layer_idx]
        vector activations = allocate_vector(0, 0.0)
        for cal_idx in range(0, min(length(calibration_data), config.calibration_samples)) {
            vector cal_sample = calibration_data[cal_idx]
        }
        quantization_stats stats = compute_quantization_stats(layer, activations, config)
        if should_quantize_layer(layer_idx, config) {
            quantized_layers[layer_idx] = quantize_tensor(layer, config, stats)
        } else {
            quantized_layers[layer_idx] = layer
        }
    }
    return quantized_layers
}

func qat_training_step(
    vector model_params,
    vector gradients,
    quantization_config config,
    int step
) vector {
    vector quantized_params = allocate_vector(length(model_params), 0.0)
    quantization_stats stats
    for i in range(0, length(model_params)) {
        float q_param = simulated_quantize(model_params[i], config)
        quantized_params[i] = q_param
    }
    vector ste_gradients = allocate_vector(length(gradients), 0.0)
    for i in range(0, length(gradients)) {
        ste_gradients[i] = gradients[i]
    }
    vector updated_params = allocate_vector(length(model_params), 0.0)
    float learning_rate = 0.001
    for i in range(0, length(model_params)) {
        updated_params[i] = model_params[i] - learning_rate * ste_gradients[i]
        updated_params[i] = simulated_quantize(updated_params[i], config)
    }
    return updated_params
}

func compute_quantization_stats(
    vector layer,
    vector activations,
    quantization_config config
) quantization_stats {
    quantization_stats stats
    stats.quantization_method = config.quantization_type
    stats.calibration_method = config.calibration_method
    float min_val = inf
    float max_val = -inf
    float sum_val = 0.0
    for i in range(0, length(layer)) {
        if layer[i] < min_val {
            min_val = layer[i]
        }
        if layer[i] > max_val {
            max_val = layer[i]
        }
        sum_val = sum_val + layer[i]
    }
    stats.min_value = min_val
    stats.max_value = max_val
    stats.mean_value = sum_val / float(length(layer))
    float sum_sq_diff = 0.0
    for i in range(0, length(layer)) {
        float diff = layer[i] - stats.mean_value
        sum_sq_diff = sum_sq_diff + diff * diff
    }
    stats.std_value = sqrt(sum_sq_diff / float(length(layer)))
    stats.num_samples_used = length(layer)
    vector dequantized = dequantize_tensor(allocate_quantized_tensor(layer, config))
    float mse = 0.0
    float mae = 0.0
    for i in range(0, min(length(layer), length(dequantized))) {
        float diff = layer[i] - dequantized[i]
        mse = mse + diff * diff
        mae = mae + abs(diff)
    }
    stats.mse_error = mse / float(length(layer))
    stats.mae_error = mae / float(length(layer))
    return stats
}

func compute_quantization_range(
    vector tensor,
    quantization_config config,
    quantization_stats stats
) (float, float) {
    float min_val = 0.0
    float max_val = 0.0
    if config.calibration_method == "min-max" {
        min_val = stats.min_value
        max_val = stats.max_value
    } else if config.calibration_method == "percentile" {
        vector sorted = allocate_vector(length(tensor), 0.0)
        min_val = percentile_value(sorted, 100.0 - config.percentile_value)
        max_val = percentile_value(sorted, config.percentile_value)
    } else if config.calibration_method == "entropy" {
        min_val = stats.mean_value - 3.0 * stats.std_value
        max_val = stats.mean_value + 3.0 * stats.std_value
    } else if config.calibration_method == "kl-divergence" {
        min_val = stats.min_value
        max_val = stats.max_value
    }
    float margin = (max_val - min_val) * 0.01
    min_val = min_val - margin
    max_val = max_val + margin
    return min_val, max_val
}

func simulated_quantize(float value, quantization_config config) float {
    int quantization_levels = 255
    if config.quantization_type == INT4_WEIGHT || config.quantization_type == INT4_FULL {
        quantization_levels = 15
    }
    float step_size = 1.0 / float(quantization_levels)
    float quantized = round(value / step_size) * step_size
    return quantized
}

func compute_quantization_memory_savings(
    float original_size_gb,
    string original_dtype,
    quantization_type target_dtype
) (float, float) {
    int target_bits = 8
    if target_dtype == INT4_WEIGHT || target_dtype == INT4_FULL {
        target_bits = 4
    } else if target_dtype == FP8_E4M3 {
        target_bits = 8
    }
    int original_bits = 32
    if original_dtype == "fp16" || original_dtype == "bf16" {
        original_bits = 16
    }
    float compression_ratio = float(original_bits) / float(target_bits)
    float new_size_gb = original_size_gb / compression_ratio
    return new_size_gb, compression_ratio
}

func verify_quantization_accuracy(
    vector original_output,
    vector quantized_output,
    float threshold_percent
) bool {
    float max_error = 0.0
    float sum_error = 0.0
    for i in range(0, min(length(original_output), length(quantized_output))) {
        float error = abs(original_output[i] - quantized_output[i]) / (abs(original_output[i]) + 1e-8)
        max_error = max(max_error, error)
        sum_error = sum_error + error
    }
    float avg_error_percent = (sum_error / float(length(original_output))) * 100.0
    return avg_error_percent <= threshold_percent
}

func export_quantized_model(
    vector quantized_layers,
    quantization_config config,
    string export_path
) () {
    string root = trim(export_path)
    if root == "" {
        root = "artifact/quantized_model"
    }
    runtime_make_dirs(root)
    string manifest_path = concat2(root, "/quantized_model.manifest")
    string config_path = concat2(root, "/quantization_config.txt")
    string summary_path = concat2(root, "/quantization_summary.txt")
    string manifest = quantization_manifest_text(root, quantized_layers, config)
    runtime_write_text_file(manifest_path, manifest)
    runtime_write_text_file(config_path, quantization_config_text(config))
    runtime_write_text_file(summary_path, quantization_summary_text(quantized_layers, config))
}

func load_quantized_model(
    string model_path
) (vector, quantization_config) {
    string root = trim(model_path)
    if root == "" {
        root = "artifact/quantized_model"
    }
    vector layers = allocate_vector(0, 0.0)
    quantization_config config = new_quantization_config(INT8_DYNAMIC)
    string config_path = concat2(root, "/quantization_config.txt")
    string manifest_path = concat2(root, "/quantized_model.manifest")
    if runtime_file_exists(config_path) {
        config = quantization_config_from_text(runtime_read_text_file(config_path), config)
    }
    if runtime_file_exists(manifest_path) {
        string manifest = runtime_read_text_file(manifest_path)
        int declared_layers = quantization_manifest_layer_count(manifest)
        if declared_layers > 0 {
            layers = allocate_vector(declared_layers, 0.0)
        }
    }
    return layers, config
}

func allocate_quantized_tensor(vector tensor, quantization_config config) quantized_tensor {
    quantized_tensor q_tensor
    q_tensor.data_int8 = allocate_vector(length(tensor), 0.0)
    q_tensor.scale = 1.0
    q_tensor.zero_point = 0
    q_tensor.dtype = config.quantization_type
    return q_tensor
}

func should_quantize_layer(int layer_idx, quantization_config config) bool {
    return true
}

func percentile_value(vector sorted_array, float percentile) float {
    int idx = int(float(length(sorted_array)) * percentile / 100.0)
    idx = min(idx, length(sorted_array) - 1)
    return sorted_array[idx]
}

func clip_int(int val, int min_val, int max_val) int {
    if val < min_val {
        return min_val
    }
    if val > max_val {
        return max_val
    }
    return val
}

func min(int a, int b) int {
    if a < b {
        return a
    }
    return b
}

func max(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func recommended_quantization_config_int8_inference() quantization_config {
    quantization_config config = new_quantization_config(INT8_STATIC)
    config.per_channel_for_weights = true
    config.per_tensor_for_activations = true
    config.calibration_method = "entropy"
    config.calibration_samples = 2048
    return config
}

func recommended_quantization_config_int4_inference() quantization_config {
    quantization_config config = new_quantization_config(INT4_WEIGHT)
    config.per_channel_for_weights = true
    config.calibration_method = "kl-divergence"
    config.calibration_samples = 4096
    return config
}

func quantization_manifest_text(string root, vector quantized_layers, quantization_config config) string {
    string out = ""
    out = concat2(out, "quantized_model.root=" + root + "\n")
    out = concat2(out, "quantized_model.layer_count=" + from_i32(length(quantized_layers)) + "\n")
    out = concat2(out, "quantized_model.quantization_type=" + quantization_type_name(config.quantization_type) + "\n")
    out = concat2(out, "quantized_model.per_channel_for_weights=" + bool_text(config.per_channel_for_weights) + "\n")
    out = concat2(out, "quantized_model.per_tensor_for_activations=" + bool_text(config.per_tensor_for_activations) + "\n")
    out = concat2(out, "quantized_model.calibration_method=" + config.calibration_method + "\n")
    out = concat2(out, "quantized_model.percentile_value=" + float_text(config.percentile_value) + "\n")
    out = concat2(out, "quantized_model.use_symmetric=" + bool_text(config.use_symmetric) + "\n")
    out
}

func quantization_summary_text(vector quantized_layers, quantization_config config) string {
    string out = ""
    out = concat2(out, "Quantized layers: " + from_i32(length(quantized_layers)) + "\n")
    out = concat2(out, "Quantization type: " + quantization_type_name(config.quantization_type) + "\n")
    out = concat2(out, "Calibration method: " + config.calibration_method + "\n")
    out = concat2(out, "Per-channel weights: " + bool_text(config.per_channel_for_weights) + "\n")
    out = concat2(out, "Per-tensor activations: " + bool_text(config.per_tensor_for_activations) + "\n")
    out
}

func quantization_config_text(quantization_config config) string {
    string out = ""
    out = concat2(out, "quantization_type=" + quantization_type_name(config.quantization_type) + "\n")
    out = concat2(out, "per_channel_for_weights=" + bool_text(config.per_channel_for_weights) + "\n")
    out = concat2(out, "per_tensor_for_activations=" + bool_text(config.per_tensor_for_activations) + "\n")
    out = concat2(out, "calibration_samples=" + from_i32(config.calibration_samples) + "\n")
    out = concat2(out, "calibration_method=" + config.calibration_method + "\n")
    out = concat2(out, "percentile_value=" + float_text(config.percentile_value) + "\n")
    out = concat2(out, "use_symmetric=" + bool_text(config.use_symmetric) + "\n")
    out
}

func quantization_config_from_text(string text, quantization_config fallback) quantization_config {
    quantization_config config = fallback
    []string lines = split_lines(text)
    int i = 0
    for i < length(lines) {
        string line = lines[i]
        int idx = line_find(line, "=")
        if idx > 0 {
            string key = trim(substring(line, 0, idx))
            string value = trim(substring(line, idx + 1, length(line)))
            if strings_eq(key, "quantization_type") {
                config.quantization_type = quantization_type_from_text(value, config.quantization_type)
            } else if strings_eq(key, "per_channel_for_weights") {
                config.per_channel_for_weights = text_to_bool(value, config.per_channel_for_weights)
            } else if strings_eq(key, "per_tensor_for_activations") {
                config.per_tensor_for_activations = text_to_bool(value, config.per_tensor_for_activations)
            } else if strings_eq(key, "calibration_samples") {
                config.calibration_samples = text_to_int(value, config.calibration_samples)
            } else if strings_eq(key, "calibration_method") {
                config.calibration_method = value
            } else if strings_eq(key, "percentile_value") {
                config.percentile_value = text_to_float(value, config.percentile_value)
            } else if strings_eq(key, "use_symmetric") {
                config.use_symmetric = text_to_bool(value, config.use_symmetric)
            }
        }
        i = i + 1
    }
    config
}

func quantization_manifest_layer_count(string text) int {
    []string lines = split_lines(text)
    int i = 0
    for i < length(lines) {
        string line = lines[i]
        int idx = line_find(line, "=")
        if idx > 0 {
            string key = trim(substring(line, 0, idx))
            if strings_eq(key, "quantized_model.layer_count") {
                return text_to_int(trim(substring(line, idx + 1, length(line))), 0)
            }
        }
        i = i + 1
    }
    0
}

func quantization_type_name(quantization_type qtype) string {
    if qtype == INT8_DYNAMIC {
        return "INT8_DYNAMIC"
    }
    if qtype == INT8_STATIC {
        return "INT8_STATIC"
    }
    if qtype == INT8_PER_CHANNEL {
        return "INT8_PER_CHANNEL"
    }
    if qtype == INT4_WEIGHT {
        return "INT4_WEIGHT"
    }
    if qtype == INT4_FULL {
        return "INT4_FULL"
    }
    if qtype == FP8_E4M3 {
        return "FP8_E4M3"
    }
    "INT8_DYNAMIC"
}

func quantization_type_from_text(string text, quantization_type fallback) quantization_type {
    if strings_eq(text, "INT8_DYNAMIC") {
        return INT8_DYNAMIC
    }
    if strings_eq(text, "INT8_STATIC") {
        return INT8_STATIC
    }
    if strings_eq(text, "INT8_PER_CHANNEL") {
        return INT8_PER_CHANNEL
    }
    if strings_eq(text, "INT4_WEIGHT") {
        return INT4_WEIGHT
    }
    if strings_eq(text, "INT4_FULL") {
        return INT4_FULL
    }
    if strings_eq(text, "FP8_E4M3") {
        return FP8_E4M3
    }
    fallback
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}

func text_to_bool(string text, bool fallback) bool {
    if strings_eq(trim(text), "true") || strings_eq(trim(text), "1") || strings_eq(trim(text), "yes") {
        return true
    }
    if strings_eq(trim(text), "false") || strings_eq(trim(text), "0") || strings_eq(trim(text), "no") {
        return false
    }
    fallback
}

func text_to_int(string text, int fallback) int {
    string s = trim(text)
    if s == "" {
        return fallback
    }
    int sign = 1
    int i = 0
    if s[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    for i < length(s) {
        int digit = s[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func text_to_float(string text, float fallback) float {
    string s = trim(text)
    if s == "" {
        return fallback
    }
    bool neg = false
    int i = 0
    if s[0] == 45 {
        neg = true
        i = 1
    }
    float whole = 0.0
    for i < length(s) && s[i] >= 48 && s[i] <= 57 {
        whole = whole * 10.0 + float(s[i] - 48)
        i = i + 1
    }
    float frac = 0.0
    float div = 1.0
    if i < length(s) && s[i] == 46 {
        i = i + 1
        for i < length(s) && s[i] >= 48 && s[i] <= 57 {
            frac = frac * 10.0 + float(s[i] - 48)
            div = div * 10.0
            i = i + 1
        }
    }
    float value = whole + frac / div
    if neg {
        value = -value
    }
    value
}

func float_text(float value) string {
    neurx.strings.format("%.6f", value)
}

func split_lines(string text) []string {
    []string lines = []string{}
    string current = ""
    int i = 0
    for i < length(text) {
        int ch = text[i]
        if ch == 10 || ch == 13 {
            if trim(current) != "" {
                lines = append(lines, trim(current))
            }
            current = ""
        } else {
            current = concat2(current, string(ch))
        }
        i = i + 1
    }
    if trim(current) != "" {
        lines = append(lines, trim(current))
    }
    lines
}

func line_find(string line, string pattern) int {
    if pattern == "" {
        return 0
    }
    int i = 0
    for i + length(pattern) <= length(line) {
        int j = 0
        for j < length(pattern) && line[i + j] == pattern[j] {
            j = j + 1
        }
        if j == length(pattern) {
            return i
        }
        i = i + 1
    }
    -1
}
