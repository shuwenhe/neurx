package neurx_interactive_inference
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}
extern "intrinsic" func __host_write_text_file(string path, string content) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}
func resolve_model_file(string configured_path) string {
    string path = trim(configured_path)
    if len(path) == 0 {
        return "/home/shuwen/shuwen/posttrain/model.safetensors"
    }
    if runtime_file_exists(path + "/model.safetensors") {
        return path + "/model.safetensors"
    }
    if runtime_file_exists(path) {
        return path
    }
    path
}
func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string model_file = resolve_model_file(runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain"))
    string runner = runtime_env_get("NEURX_CHAT_INFERENCE_RUNNER", root + "/artifacts/build/real_inference/real_inference")
    string prompt_file = runtime_env_get("NEURX_CHAT_PROMPT_PATH", "/tmp/neurx_chat_prompt.txt")
    string system_prompt = runtime_env_get("NEURX_CHAT_SYSTEM_PROMPT", "You are a helpful medical assistant.")
    if !runtime_file_exists(model_file) {
        print("error: model not found: " + model_file + "\n")
        return
    }
    if !runtime_file_exists(runner) {
        print("error: inference runner not found: " + runner + "\n")
        print("Run `make build-real-inference-s` first.\n")
        return
    }
    print("Loaded model: " + model_file + "\n")
    print("Type /exit or quit to stop.\n\n")
    while true {
        print("You: ")
        string user_text = read_user_line()
        if len(user_text) == 0 {
            return
        }
        if user_text == "/exit" || user_text == "exit" || user_text == "quit" {
            return
        }
        string prompt_text = "System: " + system_prompt + "\nUser: " + user_text + "\nAssistant:"
        _ = __host_write_text_file(prompt_file, prompt_text)
        string command = "NEURX_CHAT_MODEL_PATH=" + model_file +
            " NEURX_CHAT_PROMPT_PATH=" + prompt_file +
            " " + runner
        string output = runtime_run_command_output(command)
        string response = trim(output)
        if len(response) == 0 {
            response = "(empty response)"
        }
        print("Assistant: " + response + "\n\n")
    }
}
