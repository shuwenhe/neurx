module posttrain_evaluation_eval_lora
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}
extern "intrinsic" func __host_slice(string text, int start, int end) string
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
    string cmd = "grep -m 1 -v '^[[:space:]]*$' " + shell_escape(path)
    trim(runtime_run_command_output(cmd))
}
func extract_json_string_field(string json_text, string field_name) string {
    string cmd = "printf %s " + shell_escape(json_text) +
        " | sed -n 's/.*\"" + field_name + "\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' | head -1"
    trim(runtime_run_command_output(cmd))
}
func extract_json_int_field(string json_text, string field_name, int default_value) int {
    string text = extract_json_string_field(json_text, field_name)
    if len(text) == 0 {
        return default_value
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
            return default_value
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}
func first_record_json(string data_file) string {
    string line = first_non_empty_line(data_file)
    if len(line) == 0 {
        return ""
    }
    line
}
func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string model_dir = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string data_file = runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", "/home/shuwen/shuwen/dataset/medical/train.json")
    string runner = runtime_env_get(
        "NEURX_POSTTRAIN_EVAL_RUNNER",
        root + "/artifacts/build/real_inference/real_inference"
    )
    string max_tokens_text = runtime_env_get("NEURX_POSTTRAIN_EVAL_MAX_NEW_TOKENS", "64")
    string model_file = model_dir
    if runtime_file_exists(model_dir + "/model.safetensors") {
        model_file = model_dir + "/model.safetensors"
    }
    println("========================================")
    println("NeurX LoRA SFT Evaluation (S)")
    println("========================================")
    println("model  : " + model_file)
    println("Data   : " + data_file)
    println("runner : " + runner)
    println("Max new tokens: " + max_tokens_text)
    println("")
    if !runtime_file_exists(model_file) {
        println("error: model not found: " + model_file)
        return
    }
    if !runtime_file_exists(data_file) {
        println("error: data file not found: " + data_file)
        return
    }
    if !runtime_file_exists(runner) {
        println("error: inference runner not found: " + runner)
        println("Run `make build-real-inference-s` first.")
        return
    }
    string first_json = first_record_json(data_file)
    if len(first_json) == 0 {
        println("error: dataset is empty")
        return
    }
    string question = extract_json_string_field(first_json, "question")
    string answer_a = extract_json_string_field(first_json, "opa")
    string answer_b = extract_json_string_field(first_json, "opb")
    string answer_c = extract_json_string_field(first_json, "opc")
    string answer_d = extract_json_string_field(first_json, "opd")
    int correct_index = extract_json_int_field(first_json, "cop", 0)
    string expected = ""
    if correct_index == 1 { expected = answer_a }
    else if correct_index == 2 { expected = answer_b }
    else if correct_index == 3 { expected = answer_c }
    else if correct_index == 4 { expected = answer_d }
    string prompt = question
    if len(answer_a) > 0 { prompt = prompt + "\nA. " + answer_a }
    if len(answer_b) > 0 { prompt = prompt + "\nB. " + answer_b }
    if len(answer_c) > 0 { prompt = prompt + "\nC. " + answer_c }
    if len(answer_d) > 0 { prompt = prompt + "\nD. " + answer_d }
    string prompt_file = "/tmp/neurx_posttrain_eval_prompt.txt"
    string prompt_text = "System: You are a helpful medical assistant.\nUser: " + prompt + "\nAssistant:"
    string write_cmd = "printf %s " + shell_escape(prompt_text) + " > " + shell_escape(prompt_file) + " && printf ok"
    string write_result = trim(runtime_run_command_output(write_cmd))
    if write_result != "ok" {
        println("error: failed to write prompt file")
        return
    }
    println("Prompt:")
    println(prompt)
    println("")
    println("Expected:")
    println(expected)
    println("")
    string infer_cmd = "NEURX_CHAT_MODEL_PATH=" + shell_escape(model_file) +
        " NEURX_CHAT_PROMPT_PATH=" + shell_escape(prompt_file) +
        " " + shell_escape(runner)
    string output = runtime_run_command_output(infer_cmd)
    string response = trim(output)
    println("Generated:")
    println(response)
    println("")
    println("Done.")
}
