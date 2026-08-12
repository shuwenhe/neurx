package real_model_chat
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __host_write_text_file(string path, string content) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
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


func ends_with(string value, string suffix) bool {
    if len(suffix) > len(value) {
        return false
    }
    int offset = len(value) - len(suffix)
    int i = 0
    while i < len(suffix) {
        if __host_slice(value, offset + i, offset + i + 1) != __host_slice(suffix, i, i + 1) {
            return false
        }
        i = i + 1
    }
    true
}


func resolve_model_file(string configured_path) string {
    string path = trim(configured_path)
    if ends_with(path, ".safetensors") && runtime_file_exists(path) {
        return path
    }
    string candidate = path + "/model.safetensors"
    if runtime_file_exists(candidate) {
        return candidate
    }
    path
}


func last_index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int i = len(text) - len(needle)
    while i >= 0 {
        int j = 0
        while j < len(needle) && __host_slice(text, i + j, i + j + 1) == __host_slice(needle, j, j + 1) {
            j = j + 1
        }
        if j == len(needle) {
            return i
        }
        i = i - 1
    }
    -1
}


func slice_from(string text, int start) string {
    int offset = start
    if offset < 0 {
        offset = 0
    }
    __host_slice(text, offset, len(text))
}


func extract_response(string output) string {
    string marker = "Assistant: "
    int index = last_index_of(output, marker)
    if index < 0 {
        return ""
    }
    trim(slice_from(output, index + len(marker)))
}


func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}


func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string configured_model = runtime_env_get(
        "NEURX_CHAT_MODEL_PATH",
        "/home/shuwen/shuwen/posttrain"
    )
    string model_file = resolve_model_file(configured_model)
    string runner = runtime_env_get(
        "NEURX_CHAT_INFERENCE_RUNNER",
        root + "/artifacts/build/real_inference/real_inference"
    )
    string prompt_path = runtime_env_get(
        "NEURX_CHAT_PROMPT_PATH",
        "/tmp/neurx_chat_prompt.txt"
    )
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant."
    )
    if !runtime_file_exists(model_file) {
        print("error: model not found: " + model_file + "\n")
        return
    }
    if !runtime_file_exists(runner) {
        print("error: NeurX inference runner not found: " + runner + "\n")
        return
    }
    print("Model: " + model_file + "\n")
    print("Inference engine: " + runner + "\n")
    print("Type /exit to quit, /reset to clear history.\n\n")
    string history = "System: " + system_prompt + "\n"
    while true {
        print("You: ")
        string user_text = read_user_line()
        if len(user_text) == 0 {
            return
        }
        if user_text == "/exit" || user_text == "exit" || user_text == "quit" {
            return
        }
        if user_text == "/reset" {
            history = "System: " + system_prompt + "\n"
            print("History cleared.\n\n")
            continue
        }
        history = history + "User: " + user_text + "\nAssistant:"
        int write_status = __host_write_text_file(prompt_path, history)
        if write_status != 0 {
            print("error: failed to write prompt history\n")
            continue
        }
        string command = "NEURX_CHAT_MODEL_PATH=" + shell_escape(model_file) +
            " NEURX_CHAT_PROMPT_PATH=" + shell_escape(prompt_path) +
            " NEURX_CHAT_MAX_NEW_TOKENS=" + shell_escape(
                runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "128")
            ) + " " + shell_escape(runner)
        string output = runtime_run_command_output(command)
        string response = extract_response(output)
        if len(response) == 0 {
            print("error: NeurX inference returned no response\n\n")
            continue
        }
        print("Assistant: " + response + "\n\n")
        history = history + " " + response + "\n"
    }
}

