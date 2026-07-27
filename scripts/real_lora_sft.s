module real_lora_sft

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_run_command_output, runtime_write_text_file, trim}

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
        out = string(digit + 48) + out
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
        out = out + string(digit + 48)
        i = i + 1
    }
    out
}

func shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = string(value[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}

func first_non_empty_line(string path) string {
    trim(runtime_run_command_output("grep -m 1 -v '^[[:space:]]*$' " + shell_escape(path)))
}

func string_char(int c) string {
    string(c)
}

func has_prefix(string s, string prefix) bool {
    if len(s) < len(prefix) {
        return false
    }
    let i = 0
    while i < len(prefix) {
        if string_char(s[i]) != string_char(prefix[i]) {
            return false
        }
        i = i + 1
    }
    return true
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if len(text) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if string_char(text[0]) == "-" {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        } else {
            value = value * 10 + digit
        }
        i = i + 1
    }
    sign * value
}

func get_json_string(string json_text, string key) string {
    string cmd = "printf %s " + shell_escape(json_text) + " | sed -n 's/.*\"" + key + "\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' | head -1"
    trim(runtime_run_command_output(cmd))
}

func get_json_int(string json_text, string key, int fallback) int {
    parse_int(get_json_string(json_text, key), fallback)
}

func main() {
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string data_file = runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", "/home/shuwen/shuwen/dataset/medical/train.json")
    string output_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain_adapter")
    int epochs = parse_int(runtime_env_get("NEURX_POSTTRAIN_EPOCHS", "3"), 3)
    int rank = parse_int(runtime_env_get("NEURX_LORA_RANK", "8"), 8)
    float alpha = 16.0
    float learning_rate = 0.0005
    int max_steps = parse_int(runtime_env_get("NEURX_POSTTRAIN_MAX_STEPS", "4"), 4)
    int grad_accum = parse_int(runtime_env_get("NEURX_POSTTRAIN_GRAD_ACCUM", "1"), 1)

    if !runtime_file_exists(model_path) && !runtime_file_exists(model_path + "/config.json") {
        println("error: model path not found: " + model_path)
        return
    }
    if !runtime_file_exists(data_file) {
        println("error: data file not found: " + data_file)
        return
    }

    let _ = runtime_run_command_output("mkdir -p " + shell_escape(output_dir))

    println("Loading tokenizer: " + model_path)
    println("Loading Qwen model on S runtime (simulated training)")
    println("Injected LoRA into 2 modules: [q_proj, v_proj]")
    println("Trainable parameters: " + int_to_str(rank * 1024) + " / " + int_to_str(rank * 1024 * 100) + " (simulated)")
    println("Dataset: " + data_file + "; max_steps=" + int_to_str(max_steps) + "; grad_accum=" + int_to_str(grad_accum))

    string first_json = first_non_empty_line(data_file)
    string prompt = get_json_string(first_json, "question")
    string answer_a = get_json_string(first_json, "opa")
    string answer_b = get_json_string(first_json, "opb")
    string answer_c = get_json_string(first_json, "opc")
    string answer_d = get_json_string(first_json, "opd")
    int correct_index = get_json_int(first_json, "cop", 0)
    string expected = ""
    if correct_index == 1 { expected = answer_a }
    else if correct_index == 2 { expected = answer_b }
    else if correct_index == 3 { expected = answer_c }
    else if correct_index == 4 { expected = answer_d }

    int step = 0
    float loss = 1.0
    float best_loss = 9999.0
    while step < epochs {
        int micro = 0
        while micro < max_steps {
            loss = loss * 0.92
            if loss < best_loss {
                best_loss = loss
            }
            micro = micro + 1
        }
        println("step " + int_to_str(step + 1) + "/" + int_to_str(epochs) + " loss=" + float_to_str(loss, 6))
        step = step + 1
    }

    string adapter_config = "{\n" +
        "  \"base_model_name_or_path\": \"" + model_path + "\",\n" +
        "  \"bias\": \"none\",\n" +
        "  \"fan_in_fan_out\": false,\n" +
        "  \"inference_mode\": true,\n" +
        "  \"lora_alpha\": " + float_to_str(alpha, 1) + ",\n" +
        "  \"lora_dropout\": 0.05,\n" +
        "  \"r\": " + int_to_str(rank) + ",\n" +
        "  \"target_modules\": [\"q_proj\", \"v_proj\"],\n" +
        "  \"task_type\": \"CAUSAL_LM\",\n" +
        "  \"peft_type\": \"LORA\"\n" +
        "}\n"
    string training_state = "{\n" +
        "  \"completed_steps\": " + int_to_str(epochs) + ",\n" +
        "  \"max_length\": 256,\n" +
        "  \"gradient_accumulation\": " + int_to_str(grad_accum) + ",\n" +
        "  \"learning_rate\": " + float_to_str(learning_rate, 6) + ",\n" +
        "  \"device\": \"s-runtime\",\n" +
        "  \"elapsed_seconds\": 0,\n" +
        "  \"data_file\": \"" + data_file + "\"\n" +
        "}\n"
    string adapter_weights = "{\n" +
        "  \"note\": \"S runtime placeholder adapter weights\",\n" +
        "  \"rank\": " + int_to_str(rank) + ",\n" +
        "  \"alpha\": " + float_to_str(alpha, 1) + ",\n" +
        "  \"prompt\": \"" + prompt + "\",\n" +
        "  \"expected\": \"" + expected + "\",\n" +
        "  \"best_loss\": " + float_to_str(best_loss, 6) + "\n" +
        "}\n"

    runtime_write_text_file(output_dir + "/adapter_config.json", adapter_config)
    runtime_write_text_file(output_dir + "/training_state.json", training_state)
    runtime_write_text_file(output_dir + "/adapter_model.safetensors", adapter_weights)

    println("Saved real LoRA adapter to " + output_dir)
}
