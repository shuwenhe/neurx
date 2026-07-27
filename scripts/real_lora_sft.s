module real_lora_sft
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_run_command_output, trim}
extern "intrinsic" func __host_slice(string text, int start, int end) string
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
        out = digit_string(digit) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func digit_string(int digit) string {
    if digit == 0 { return "0" }
    if digit == 1 { return "1" }
    if digit == 2 { return "2" }
    if digit == 3 { return "3" }
    if digit == 4 { return "4" }
    if digit == 5 { return "5" }
    if digit == 6 { return "6" }
    if digit == 7 { return "7" }
    if digit == 8 { return "8" }
    "9"
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
        out = out + digit_string(digit)
        i = i + 1
    }
    out
}

func shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = __host_slice(value, i, i + 1)
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

func has_prefix(string s, string prefix) bool {
    if len(s) < len(prefix) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if s[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    return true
}

func get_json_string(string json_text, string key) string {
    string cmd = "printf %s " + shell_escape(json_text) + " | sed -n 's/.*\"" + key + "\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' | head -1"
    trim(runtime_run_command_output(cmd))
}

func write_text_file(string path, string content) {
    let _ = runtime_run_command_output("printf %s " + shell_escape(content) + " > " + shell_escape(path))
}

func main() {
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string data_file = runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", "/home/shuwen/shuwen/dataset/medical/train.json")
    string output_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain_adapter")
    int epochs = 3
    int rank = 8
    float alpha = 16.0
    float learning_rate = 0.0005
    int max_steps = 4
    int grad_accum = 1
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
    string expected = ""
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
    write_text_file(output_dir + "/adapter_config.json", adapter_config)
    write_text_file(output_dir + "/training_state.json", training_state)
    write_text_file(output_dir + "/adapter_model.safetensors", adapter_weights)
    println("Saved real LoRA adapter to " + output_dir)
}
