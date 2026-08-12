package neurx.quantization.quant_core
func quant_type_int8() string { "int8" }

func quant_type_int4() string { "int4" }

func quant_granularity_tensor() string { "per_tensor" }

func quant_granularity_group() string { "per_group" }

struct quantization_config {
    string quant_type
    string granularity
    int group_size
    bool symmetric
}

struct quantization_stats {
    float minimum
    float maximum
    float maximum_absolute
    float mean
    bool valid
}

struct quantized_tensor {
    string quant_type
    string granularity
    int element_count
    int group_size
    []int values
    []float scales
    []int zero_points
    bool packed
}

struct quantization_result {
    quantized_tensor tensor
    bool success
    string error_message
}

func default_int8_config() quantization_config {
    quantization_config config
    config.quant_type = quant_type_int8()
    config.granularity = quant_granularity_tensor()
    config.group_size = 0
    config.symmetric = true
    config
}

func default_int4_config(int group_size) quantization_config {
    quantization_config config
    config.quant_type = quant_type_int4()
    config.granularity = quant_granularity_group()
    config.group_size = group_size
    config.symmetric = true
    config
}

func empty_quantized_tensor() quantized_tensor {
    quantized_tensor tensor
    tensor.quant_type = ""
    tensor.granularity = ""
    tensor.element_count = 0
    tensor.group_size = 0
    tensor.values = []
    tensor.scales = []
    tensor.zero_points = []
    tensor.packed = false
    tensor
}

func new_quantization_result(quantized_tensor tensor, bool success, string error_message) quantization_result {
    quantization_result result
    result.tensor = tensor
    result.success = success
    result.error_message = error_message
    result
}

func quant_abs(float value) float {
    if value < 0.0 { return 0.0 - value }
    value
}

func quant_max(float left, float right) float {
    if left > right { return left }
    right
}

func quant_round(float value) int {
    if value >= 0.0 { return int(value + 0.5) }
    int(value - 0.5)
}

func quant_remainder(int value, int divisor) int {
    value - (value / divisor) * divisor
}

func quant_clamp(int value, int minimum, int maximum) int {
    if value < minimum { return minimum }
    if value > maximum { return maximum }
    value
}

func compute_tensor_stats([]float values) quantization_stats {
    quantization_stats stats
    stats.minimum = 0.0
    stats.maximum = 0.0
    stats.maximum_absolute = 0.0
    stats.mean = 0.0
    stats.valid = false
    if len(values) == 0 { return stats }
    stats.minimum = values[0]
    stats.maximum = values[0]
    float sum = 0.0
    int i = 0
    while i < len(values) {
        float value = values[i]
        if value < stats.minimum { stats.minimum = value }
        if value > stats.maximum { stats.maximum = value }
        stats.maximum_absolute = quant_max(stats.maximum_absolute, quant_abs(value))
        sum = sum + value
        i = i + 1
    }
    stats.mean = sum / float(len(values))
    stats.valid = true
    stats
}

func quantization_config_valid(quantization_config config) bool {
    if !config.symmetric { return false }
    if config.quant_type == quant_type_int8() {
        return config.granularity == quant_granularity_tensor()
    }
    if config.quant_type == quant_type_int4() {
        return config.granularity == quant_granularity_group() && config.group_size > 0
    }
    false
}

func quantize_int8([]float values) quantization_result {
    if len(values) == 0 {
        return new_quantization_result(empty_quantized_tensor(), false, "tensor is empty")
    }
    quantization_stats stats = compute_tensor_stats(values)
    float scale = stats.maximum_absolute / 127.0
    if scale <= 0.0 { scale = 1.0 }
    quantized_tensor tensor = empty_quantized_tensor()
    tensor.quant_type = quant_type_int8()
    tensor.granularity = quant_granularity_tensor()
    tensor.element_count = len(values)
    tensor.group_size = len(values)
    tensor.scales = append(tensor.scales, scale)
    tensor.zero_points = append(tensor.zero_points, 0)
    int i = 0
    while i < len(values) {
        int value = quant_clamp(quant_round(values[i] / scale), -127, 127)
        tensor.values = append(tensor.values, value)
        i = i + 1
    }
    new_quantization_result(tensor, true, "")
}

func quantize_int4_groupwise([]float values, int group_size) quantization_result {
    if len(values) == 0 {
        return new_quantization_result(empty_quantized_tensor(), false, "tensor is empty")
    }
    if group_size <= 0 {
        return new_quantization_result(empty_quantized_tensor(), false, "group_size must be positive")
    }
    quantized_tensor tensor = empty_quantized_tensor()
    tensor.quant_type = quant_type_int4()
    tensor.granularity = quant_granularity_group()
    tensor.element_count = len(values)
    tensor.group_size = group_size
    tensor.packed = true
    int group_start = 0
    while group_start < len(values) {
        int group_end = group_start + group_size
        if group_end > len(values) { group_end = len(values) }
        float maximum_absolute = 0.0
        int i = group_start
        while i < group_end {
            maximum_absolute = quant_max(maximum_absolute, quant_abs(values[i]))
            i = i + 1
        }
        float scale = maximum_absolute / 7.0
        if scale <= 0.0 { scale = 1.0 }
        tensor.scales = append(tensor.scales, scale)
        tensor.zero_points = append(tensor.zero_points, 0)
        i = group_start
        while i < group_end {
            int low = quant_clamp(quant_round(values[i] / scale), -7, 7) + 8
            int high = 8
            if i + 1 < group_end {
                high = quant_clamp(quant_round(values[i + 1] / scale), -7, 7) + 8
            }
            tensor.values = append(tensor.values, low + high * 16)
            i = i + 2
        }
        group_start = group_end
    }
    new_quantization_result(tensor, true, "")
}

func quantize_tensor([]float values, quantization_config config) quantization_result {
    if !quantization_config_valid(config) {
        return new_quantization_result(empty_quantized_tensor(), false, "unsupported quantization configuration")
    }
    if config.quant_type == quant_type_int8() { return quantize_int8(values) }
    quantize_int4_groupwise(values, config.group_size)
}

func dequantize_tensor(quantized_tensor tensor) []float {
    []float output = []
    if tensor.element_count <= 0 || len(tensor.scales) == 0 { return output }
    if tensor.quant_type == quant_type_int8() {
        int i = 0
        while i < len(tensor.values) && i < tensor.element_count {
            output = append(output, float(tensor.values[i]) * tensor.scales[0])
            i = i + 1
        }
        return output
    }
    if tensor.quant_type != quant_type_int4() || tensor.group_size <= 0 { return output }
    int element_index = 0
    int packed_index = 0
    while element_index < tensor.element_count && packed_index < len(tensor.values) {
        int group_index = element_index / tensor.group_size
        if group_index >= len(tensor.scales) { return [] }
        int packed = tensor.values[packed_index]
        int low = quant_remainder(packed, 16) - 8
        int high = packed / 16 - 8
        output = append(output, float(low) * tensor.scales[group_index])
        element_index = element_index + 1
        if element_index < tensor.element_count {
            output = append(output, float(high) * tensor.scales[group_index])
            element_index = element_index + 1
        }
        packed_index = packed_index + 1
    }
    output
}

func quantized_storage_bytes(quantized_tensor tensor) int {
    int value_bytes = len(tensor.values)
    if tensor.quant_type == quant_type_int8() { value_bytes = len(tensor.values) }
    value_bytes + len(tensor.scales) * 4 + len(tensor.zero_points)
}

func quantization_compression_milli(quantized_tensor tensor) int {
    int original_bytes = tensor.element_count * 4
    int compressed_bytes = quantized_storage_bytes(tensor)
    if original_bytes <= 0 || compressed_bytes <= 0 { return 0 }
    original_bytes * 1000 / compressed_bytes
}

func quantization_mean_squared_error([]float original, quantized_tensor tensor) float {
    []float restored = dequantize_tensor(tensor)
    if len(original) == 0 || len(restored) != len(original) { return -1.0 }
    float error = 0.0
    int i = 0
    while i < len(original) {
        float difference = original[i] - restored[i]
        error = error + difference * difference
        i = i + 1
    }
    error / float(len(original))
}

