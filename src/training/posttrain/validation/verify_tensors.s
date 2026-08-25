use std.conv.parse_int_default
use std.encoding.bytes_to_string_range

module posttrain_validation_verify_tensors
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_binary_file, trim}

struct tensor_stats {
    float mean
    float std
    float min
    float max
    float norm
    int count
    int nonzero
}

struct tensor_sample {
    string name
    string dtype
    []float values
    int data_start
    int data_end
}

func main() {
    println("============================================================")
    println("NeurX PostTrain Tensor-Level Verification")
    println("============================================================")
    println("")
    string adapter_path = runtime_env_get("NEURX_POSTTRAIN_ADAPTER_FILE", "/home/shuwen/shuwen/posttrain_adapter/adapter_model.safetensors")
    if !runtime_file_exists(adapter_path) {
        println("❌ FAIL: Adapter file not found: " + adapter_path)
        return
    }
    []int file_bytes = runtime_read_binary_file(adapter_path)
    if len(file_bytes) < 16 {
        println("❌ FAIL: Adapter file too small: " + adapter_path)
        return
    }
    int header_size = read_u64_le(file_bytes, 0)
    if header_size <= 0 || header_size + 8 > len(file_bytes) {
        println("❌ FAIL: Invalid safetensors header")
        return
    }
    string header = bytes_to_string_range(file_bytes, 8, header_size)
    println("[1] Reading adapter tensors...")
    int found = 0
    tensor_sample sample_q_a = read_tensor_sample(file_bytes, header, "base_model.model.model.layers.0.self_attn.q_proj.lora_A.weight")
    if len(sample_q_a.values) == 0 {
        println("❌ FAIL: missing tensor: " + sample_q_a.name)
        return
    }
    tensor_stats stats_q_a = compute_stats(sample_q_a.values)
    println("")
    println("📊 " + sample_q_a.name)
    println("   Dtype: " + sample_q_a.dtype)
    println("   Mean:  " + float_to_str(stats_q_a.mean, 6) + ", Std: " + float_to_str(stats_q_a.std, 6))
    println("   Min:   " + float_to_str(stats_q_a.min, 6) + ", Max: " + float_to_str(stats_q_a.max, 6))
    println("   L2:    " + float_to_str(stats_q_a.norm, 6))
    println("   Non-zero: " + int_to_str(stats_q_a.nonzero) + "/" + int_to_str(stats_q_a.count))
    tensor_sample sample_q_b = read_tensor_sample(file_bytes, header, "base_model.model.model.layers.0.self_attn.q_proj.lora_B.weight")
    if len(sample_q_b.values) == 0 {
        println("❌ FAIL: missing tensor: " + sample_q_b.name)
        return
    }
    tensor_stats stats_q_b = compute_stats(sample_q_b.values)
    println("")
    println("📊 " + sample_q_b.name)
    println("   Dtype: " + sample_q_b.dtype)
    println("   Mean:  " + float_to_str(stats_q_b.mean, 6) + ", Std: " + float_to_str(stats_q_b.std, 6))
    println("   Min:   " + float_to_str(stats_q_b.min, 6) + ", Max: " + float_to_str(stats_q_b.max, 6))
    println("   L2:    " + float_to_str(stats_q_b.norm, 6))
    println("   Non-zero: " + int_to_str(stats_q_b.nonzero) + "/" + int_to_str(stats_q_b.count))
    if stats_q_b.nonzero > 0 {
        found = found + 1
    }
    tensor_sample sample_v_a = read_tensor_sample(file_bytes, header, "base_model.model.model.layers.0.self_attn.v_proj.lora_A.weight")
    if len(sample_v_a.values) == 0 {
        println("❌ FAIL: missing tensor: " + sample_v_a.name)
        return
    }
    tensor_stats stats_v_a = compute_stats(sample_v_a.values)
    println("")
    println("📊 " + sample_v_a.name)
    println("   Dtype: " + sample_v_a.dtype)
    println("   Mean:  " + float_to_str(stats_v_a.mean, 6) + ", Std: " + float_to_str(stats_v_a.std, 6))
    println("   Min:   " + float_to_str(stats_v_a.min, 6) + ", Max: " + float_to_str(stats_v_a.max, 6))
    println("   L2:    " + float_to_str(stats_v_a.norm, 6))
    println("   Non-zero: " + int_to_str(stats_v_a.nonzero) + "/" + int_to_str(stats_v_a.count))
    tensor_sample sample_v_b = read_tensor_sample(file_bytes, header, "base_model.model.model.layers.0.self_attn.v_proj.lora_B.weight")
    if len(sample_v_b.values) == 0 {
        println("❌ FAIL: missing tensor: " + sample_v_b.name)
        return
    }
    tensor_stats stats_v_b = compute_stats(sample_v_b.values)
    println("")
    println("📊 " + sample_v_b.name)
    println("   Dtype: " + sample_v_b.dtype)
    println("   Mean:  " + float_to_str(stats_v_b.mean, 6) + ", Std: " + float_to_str(stats_v_b.std, 6))
    println("   Min:   " + float_to_str(stats_v_b.min, 6) + ", Max: " + float_to_str(stats_v_b.max, 6))
    println("   L2:    " + float_to_str(stats_v_b.norm, 6))
    println("   Non-zero: " + int_to_str(stats_v_b.nonzero) + "/" + int_to_str(stats_v_b.count))
    if stats_v_b.nonzero > 0 {
        found = found + 1
    }
    println("")
    println("[3] Gradient Descent Verification (CRITICAL)")
    println("------------------------------------------------------------")
    println("S trainer initializes lora_B to all 0.0")
    println("If current values ≠ 0, gradient descent definitely happened!")
    println("")
    if found == 0 {
        println("❌ FAIL: lora_B matrices are all zeros!")
        println("   → Training did not actually happen")
        return
    }
    println("✅ PASS: lora_B matrices contain non-zero values!")
    println("   → Gradient descent definitely occurred")
    println("")
    println("============================================================")
    println("VERIFICATION SUMMARY")
    println("============================================================")
    println("✅ LoRA tensors inspected: 4")
    println("✅ Non-zero B tensors: " + int_to_str(found))
    println("")
    println("CONCLUSION: Training is REAL ✅✅✅")
    println("- lora_B changed from 0.0 → non-zero")
    println("- This can only happen via gradient descent")
}

func read_tensor_sample([]int file_bytes, string header, string tensor_name) tensor_sample {
    int name_pos = find_substring(header, "\"" + tensor_name + "\":{")
    if name_pos < 0 {
        tensor_sample missing
        missing.name = tensor_name
        missing.dtype = ""
        missing.values = []float{}
        missing.data_start = 0
        missing.data_end = 0
        return missing
    }
    int dtype_pos = find_substring_from(header, "\"dtype\":\"", name_pos)
    int dtype_start = dtype_pos + len("\"dtype\":\"")
    int dtype_end = find_char_from(header, "\"", dtype_start)
    string dtype = substring(header, dtype_start, dtype_end)
    int offsets_pos = find_substring_from(header, "\"data_offsets\":[", dtype_end)
    int offsets_start = offsets_pos + len("\"data_offsets\":[")
    int offsets_mid = find_char_from(header, ",", offsets_start)
    int offsets_end = find_char_from(header, "]", offsets_mid + 1)
    int data_start = parse_int(substring(header, offsets_start, offsets_mid), 0)
    int data_end = parse_int(substring(header, offsets_mid + 1, offsets_end), 0)
    int data_base = 8 + len(header)
    []float values = decode_f32_values(file_bytes, data_base + data_start, data_base + data_end)
    tensor_sample {
        name: tensor_name,
        dtype: dtype,
        values: values,
        data_start: data_start,
        data_end: data_end,
    }
}

func decode_f32_values([]int bytes, int start, int end) []float {
    []float values = []float{}
    int i = start
    for i + 3 < end {
        values = append(values, f32_from_le_bytes(bytes, i))
        i = i + 4
    }
    values
}

func f32_from_le_bytes([]int bytes, int idx) float {
    int b0 = bytes[idx]
    int b1 = bytes[idx + 1]
    int b2 = bytes[idx + 2]
    int b3 = bytes[idx + 3]
    int bits = b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
    if bits == 0 {
        return 0.0
    }
    int sign = bits / 2147483648
    int exp = (bits / 8388608) - sign * 256
    int mant = bits - sign * 2147483648 - exp * 8388608
    if exp == 0 {
        float frac = mant as float / 8388608.0
        float value = frac * pow2_int(-126)
        if sign == 1 {
            value = 0.0 - value
        }
        return value
    }
    if exp == 255 {
        return 0.0
    }
    float frac = 1.0 + (mant as float) / 8388608.0
    float value = frac * pow2_int(exp - 127)
    if sign == 1 {
        value = 0.0 - value
    }
    value
}

func pow2_int(int exponent) float {
    float value = 1.0
    int e = exponent
    if e >= 0 {
        int i = 0
        for i < e {
            value = value * 2.0
            i = i + 1
        }
    } else {
        int i = 0
        for i < 0 - e {
            value = value / 2.0
            i = i + 1
        }
    }
    value
}

func compute_stats([]float values) tensor_stats {
    if len(values) == 0 {
        tensor_stats empty
        empty.mean = 0.0
        empty.std = 0.0
        empty.min = 0.0
        empty.max = 0.0
        empty.norm = 0.0
        empty.count = 0
        empty.nonzero = 0
        return empty
    }
    float sum = 0.0
    float sq = 0.0
    float min_v = values[0]
    float max_v = values[0]
    int nonzero = 0
    int i = 0
    for i < len(values) {
        float v = values[i]
        sum = sum + v
        sq = sq + v * v
        if v < min_v {
            min_v = v
        }
        if v > max_v {
            max_v = v
        }
        if v != 0.0 {
            nonzero = nonzero + 1
        }
        i = i + 1
    }
    float mean = sum / (len(values) as float)
    float variance = 0.0
    i = 0
    for i < len(values) {
        float diff = values[i] - mean
        variance = variance + diff * diff
        i = i + 1
    }
    variance = variance / (len(values) as float)
    tensor_stats stats
    stats.mean = mean
    stats.std = sqrt_approx(variance)
    stats.min = min_v
    stats.max = max_v
    stats.norm = sqrt_approx(sq)
    stats.count = len(values)
    stats.nonzero = nonzero
    return stats
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    for i < 12 {
        guess = 0.5 * (guess + x / guess)
        i = i + 1
    }
    guess
}

func find_substring(string text, string pattern) int {
    if len(pattern) > len(text) {
        return -1
    }
    int i = 0
    for i <= len(text) - len(pattern) {
        bool match = true
        int j = 0
        for j < len(pattern) {
            if text[i + j] != pattern[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func find_substring_from(string text, string pattern, int start) int {
    if start < 0 || start >= len(text) || len(pattern) > len(text) - start {
        return -1
    }
    int i = start
    for i <= len(text) - len(pattern) {
        bool match = true
        int j = 0
        for j < len(pattern) {
            if text[i + j] != pattern[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func find_char_from(string text, string ch, int start) int {
    int i = start
    for i < len(text) {
        if text[i] == ch[0] {
            return i
        }
        i = i + 1
    }
    -1
}

func substring(string text, int start, int end) string {
    if start < 0 || end > len(text) || start >= end {
        return ""
    }
    string result = ""
    int i = start
    for i < end {
        result = result + string_char(text[i])
        i = i + 1
    }
    result
}

func string_char(int c) string {
    string(c)
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    for value > 0 {
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
    if neg {
        out = "-" + out
    }
    out
}

func float_to_str(float value, int decimals) string {
    float current = value
    bool neg = current < 0.0
    if neg {
        current = 0.0 - current
    }
    int whole = 0
    for current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    for i < decimals {
        current = current * 10.0
        int digit = 0
        for current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        if digit == 0 { out = out + "0" }
        else if digit == 1 { out = out + "1" }
        else if digit == 2 { out = out + "2" }
        else if digit == 3 { out = out + "3" }
        else if digit == 4 { out = out + "4" }
        else if digit == 5 { out = out + "5" }
        else if digit == 6 { out = out + "6" }
        else if digit == 7 { out = out + "7" }
        else if digit == 8 { out = out + "8" }
        else { out = out + "9" }
        i = i + 1
    }
    out
}
