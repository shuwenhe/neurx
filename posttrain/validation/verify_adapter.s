module posttrain_validation_verify_adapter
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_binary_file, runtime_read_text_file, runtime_run_command_output, trim}
float MIN_ADAPTER_L1 = 1e-6
float MIN_LOSS_DROP = 1e-6
float MAX_LOSS_STEP_INCREASE = 1e-7
float MIN_WEIGHT_DELTA_L2 = 1e-6
int MIN_CHANGED_ELEMENTS = 1

func main() {
    string base_dir = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "../model/base-model")
    string adapter_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain_adapter")
    string output_dir = runtime_env_get("NEURX_MERGED_MODEL_DIR", "/home/shuwen/shuwen/posttrain")
    string adapter_file = adapter_dir + "/adapter_model.safetensors"
    string merged_file = output_dir + "/model.safetensors"
    string training_state_file = adapter_dir + "/training_state.json"
    if !runtime_file_exists(adapter_file) {
        println("error: missing adapter file: " + adapter_file)
        return
    }
    []int adapter_bytes = runtime_read_binary_file(adapter_file)
    if len(adapter_bytes) < 16 {
        println("error: adapter file too small")
        return
    }
    int header_size = read_u64_le(adapter_bytes, 0)
    if header_size <= 0 || header_size + 8 > len(adapter_bytes) {
        println("error: invalid adapter safetensors header")
        return
    }
    string state_text = runtime_read_text_file(training_state_file)
    if state_text == "" {
        println("error: missing training_state.json: " + training_state_file)
        return
    }
    []float loss_history = extract_json_array_values(state_text, "loss_history")
    if len(loss_history) < 2 {
        println("error: loss_history must contain at least two points")
        return
    }
    float start_loss = loss_history[0]
    float final_loss = loss_history[len(loss_history) - 1]
    if start_loss - final_loss < MIN_LOSS_DROP {
        println("error: loss did not decrease enough: start=" + float_to_str(start_loss, 6) + " final=" + float_to_str(final_loss, 6))
        return
    }
    float prev = start_loss
    int i = 1
    while i < len(loss_history) {
        float current = loss_history[i]
        if current - prev > MAX_LOSS_STEP_INCREASE {
            println("error: loss increased at step " + int_to_str(i) + ": prev=" + float_to_str(prev, 6) + " current=" + float_to_str(current, 6))
            return
        }
        prev = current
        i = i + 1
    }
    float adapter_l1 = parse_float(extract_json_number_field(state_text, "adapter_l1_norm", "0"), 0.0)
    float weight_delta_l2 = parse_float(extract_json_number_field(state_text, "weight_delta_l2", "0"), 0.0)
    int weight_changed_count = parse_int(extract_json_number_field(state_text, "weight_changed_count", "0"), 0)
    if adapter_l1 <= MIN_ADAPTER_L1 {
        println("error: adapter L1 norm too small: " + float_to_str(adapter_l1, 6))
        return
    }
    if weight_delta_l2 <= MIN_WEIGHT_DELTA_L2 {
        println("error: training_state reports tiny weight delta l2")
        return
    }
    if weight_changed_count < MIN_CHANGED_ELEMENTS {
        println("error: training_state reports no changed weights")
        return
    }
    println("training loss: start=" + float_to_str(start_loss, 6) + " final=" + float_to_str(final_loss, 6))
    println("training loss drop: " + float_to_str(start_loss - final_loss, 6))
    println("adapter L1 norm: " + float_to_str(adapter_l1, 6))
    if runtime_file_exists(merged_file) {
        string base_model_file = base_dir
    if runtime_file_exists(base_dir + "/model.safetensors") {
        base_model_file = base_dir + "/model.safetensors"
    }
        string diff_text = trim(runtime_run_command_output("cmp -bl " + shell_escape(base_model_file) + " " + shell_escape(merged_file) + " 2>/dev/null | wc -l"))
        if diff_text == "" {
            diff_text = "0"
        }
        int diff_count = parse_int(diff_text, 0)
        if diff_count <= 0 {
            println("error: merged tensor delta too small")
            return
        }
        println("merged byte diffs: " + int_to_str(diff_count))
    }
    println("posttrain adapter verification passed")
}

func extract_json_number_field(string json_text, string field_name, string fallback) string {
    string needle = "\"" + field_name + "\""
    int pos = find_substring(json_text, needle)
    if pos < 0 {
        return fallback
    }
    pos = pos + len(needle)
    while pos < len(json_text) && (json_text[pos] == 32 || json_text[pos] == 9 || json_text[pos] == 10 || json_text[pos] == 13 || json_text[pos] == 58) {
        pos = pos + 1
    }
    string token = ""
    bool started = false
    while pos < len(json_text) {
        int ch = json_text[pos]
        if is_number_token_char(ch) {
            token = token + string_char(ch)
            started = true
        } else if started {
            break
        }
        pos = pos + 1
    }
    if token == "" {
        return fallback
    }
    token
}

func extract_json_array_values(string json_text, string field_name) []float {
    []float values = []float{}
    string needle = "\"" + field_name + "\""
    int pos = find_substring(json_text, needle)
    if pos < 0 {
        return values
    }
    pos = pos + len(needle)
    while pos < len(json_text) && json_text[pos] != 91 {
        pos = pos + 1
    }
    if pos >= len(json_text) {
        return values
    }
    pos = pos + 1
    string token = ""
    while pos < len(json_text) {
        int ch = json_text[pos]
        if ch == 93 {
            if token != "" {
                values = append(values, parse_float(token, 0.0))
            }
            break
        }
        if is_number_token_char(ch) {
            token = token + string_char(ch)
        } else {
            if token != "" {
                values = append(values, parse_float(token, 0.0))
                token = ""
            }
        }
        pos = pos + 1
    }
    values
}

func parse_float(string s, float fallback) float {
    string text = trim(s)
    if text == "" {
        return fallback
    }
    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    } else if text[0] == 43 {
        i = 1
    }
    float value = 0.0
    while i < len(text) {
        int ch = text[i]
        if ch == 46 {
            i = i + 1
            break
        }
        if ch < 48 || ch > 57 {
            return fallback
        }
        value = value * 10.0 + (ch - 48) as float
        i = i + 1
    }
    float frac = 0.1
    while i < len(text) {
        int ch = text[i]
        if ch == 101 || ch == 69 {
            break
        }
        if ch < 48 || ch > 57 {
            break
        }
        value = value + (ch - 48) as float * frac
        frac = frac * 0.1
        i = i + 1
    }
    int exp = 0
    int exp_sign = 1
    if i < len(text) && (text[i] == 101 || text[i] == 69) {
        i = i + 1
        if i < len(text) && text[i] == 45 {
            exp_sign = -1
            i = i + 1
        } else if i < len(text) && text[i] == 43 {
            i = i + 1
        }
        while i < len(text) {
            int ch = text[i]
            if ch < 48 || ch > 57 {
                break
            }
            exp = exp * 10 + (ch - 48)
            i = i + 1
        }
    }
    float result = value
    int scaled_exp = exp * exp_sign
    if scaled_exp > 0 {
        int j = 0
        while j < scaled_exp {
            result = result * 10.0
            j = j + 1
        }
    } else if scaled_exp < 0 {
        int j = 0
        while j < 0 - scaled_exp {
            result = result / 10.0
            j = j + 1
        }
    }
    result * (sign as float)
}

func is_number_token_char(int ch) bool {
    ch >= 48 && ch <= 57 || ch == 45 || ch == 43 || ch == 46 || ch == 101 || ch == 69
}

func find_substring(string text, string pattern) int {
    if len(pattern) > len(text) {
        return -1
    }
    int i = 0
    while i <= len(text) - len(pattern) {
        bool match = true
        int j = 0
        while j < len(pattern) {
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

func read_u64_le([]int bytes, int offset) int {
    int value = 0
    int i = 0
    int shift = 1
    while i < 8 {
        value = value + bytes[offset + i] * shift
        shift = shift * 256
        i = i + 1
    }
    value
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if text == "" {
        return fallback
    }
    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
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
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
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

func shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = string_char(value[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}
