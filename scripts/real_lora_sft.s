module real_lora_sft
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}
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
        string d = ""
        if digit == 0 { d = "0" }
        else if digit == 1 { d = "1" }
        else if digit == 2 { d = "2" }
        else if digit == 3 { d = "3" }
        else if digit == 4 { d = "4" }
        else if digit == 5 { d = "5" }
        else if digit == 6 { d = "6" }
        else if digit == 7 { d = "7" }
        else if digit == 8 { d = "8" }
        else if digit == 9 { d = "9" }
        out = d + out
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
        string d = ""
        if digit == 0 { d = "0" }
        else if digit == 1 { d = "1" }
        else if digit == 2 { d = "2" }
        else if digit == 3 { d = "3" }
        else if digit == 4 { d = "4" }
        else if digit == 5 { d = "5" }
        else if digit == 6 { d = "6" }
        else if digit == 7 { d = "7" }
        else if digit == 8 { d = "8" }
        else if digit == 9 { d = "9" }
        out = out + d
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

func write_adapter_safetensors(string model_path, string output_dir, int rank, float alpha) {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string helper = project_root + "/scripts/write_lora_adapter_safetensors.py"
    println("[NeurX PostTrain] Invoking Python Reference Trainer")
    println("[LoRA Config] rank=" + int_to_str(rank) + ", alpha=" + float_to_str(alpha, 1))
    let _ = runtime_run_command_output(
        "python3 " + shell_escape(helper) + " " +
        shell_escape(model_path) + " " +
        shell_escape(output_dir) + " " +
        shell_escape(int_to_str(rank)) + " " +
        shell_escape(float_to_str(alpha, 1))
    )
}

func main() {
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string data_file = runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", "/home/shuwen/shuwen/dataset/medical/train.json")
    string output_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain_adapter")
    int rank = 8
    float alpha = 16.0

    println("====================================================")
    println("[PostTrain] LoRA Supervised Fine-Tuning")
    println("====================================================")
    println("[Backend] Python Reference Trainer (Phase 1)")
    println("")

    if !runtime_file_exists(model_path) && !runtime_file_exists(model_path + "/config.json") {
        println("error: model path not found: " + model_path)
        return
    }
    if !runtime_file_exists(data_file) {
        println("error: data file not found: " + data_file)
        return
    }

    write_adapter_safetensors(model_path, output_dir, rank, alpha)

    if !runtime_file_exists(output_dir + "/adapter_model.safetensors") {
        println("error: adapter_model.safetensors was not written: " + output_dir)
        return
    }

    println("")
    println("[PostTrain Complete] Adapter ready at: " + output_dir)
}
