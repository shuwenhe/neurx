package real_inference_interactive
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}

extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __host_write_text_file(string path, string content) int
extern "intrinsic" func __sys_read_string(int fd, int count) string

func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}

func shell_escape(string value) string {
    string output = "'"
    int index = 0
    while index < len(value) {
        string character = __host_slice(value, index, index + 1)
        if character == "'" {
            output = output + "'\"'\"'"
        } else {
            output = output + character
        }
        index = index + 1
    }
    output + "'"
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    int current = value
    bool negative = false
    if current < 0 {
        negative = true
        current = 0 - current
    }
    string result = ""
    while current > 0 {
        int digit = current - (current / 10) * 10
        result = string(digit + 48) + result
        current = current / 10
    }
    if negative {
        result = "-" + result
    }
    return result
}

func index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int index = 0
    while index <= len(text) - len(needle) {
        int inner = 0
        while inner < len(needle) &&
              __host_slice(text, index + inner, index + inner + 1) == __host_slice(needle, inner, inner + 1) {
            inner = inner + 1
        }
        if inner == len(needle) {
            return index
        }
        index = index + 1
    }
    -1
}

func resolve_model_file(string configured_path) string {
    string path = trim(configured_path)
    if len(path) == 0 {
        return "/home/shuwen/shuwen/posttrain/model.safetensors"
    }
    if runtime_file_exists(path + "/model.safetensors") {
        return path + "/model.safetensors"
    }
    if runtime_file_exists(path + "/model.safetensors.index.json") {
        return path + "/model.safetensors"
    }
    if runtime_file_exists(path) {
        return path
    }
    return path
}

func extract_assistant_text(string output) string {
    string marker = "Assistant:"
    int pos = index_of(output, marker)
    if pos < 0 {
        return trim(output)
    }
    trim(__host_slice(output, pos + len(marker), len(output)))
}

func run_model(string runner, string model_file, string prompt_file, string prompt_text, string max_tokens) string {
    _ = __host_write_text_file(prompt_file, prompt_text)
    string command = "NEURX_CHAT_MODEL_PATH=" + shell_escape(model_file) +
        " NEURX_CHAT_PROMPT_PATH=" + shell_escape(prompt_file) +
        " NEURX_CHAT_MAX_NEW_TOKENS=" + shell_escape(max_tokens) +
        " " + shell_escape(runner)
    trim(runtime_run_command_output(command))
}

func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string configured_model = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain/model.safetensors")
    string model_file = resolve_model_file(configured_model)
    string runner = runtime_env_get("NEURX_CHAT_INFERENCE_RUNNER", root + "/artifacts/build/real_inference/real_inference")
    string prompt_file = runtime_env_get("NEURX_CHAT_PROMPT_PATH", "/tmp/neurx_real_inference_interactive_prompt.txt")
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful medical assistant. Give concise, factual, and safe answers."
    )
    string max_tokens = runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "128")

    if !runtime_file_exists(model_file) {
        print("error: model not found: " + model_file + "\n")
        return 1
    }
    if !runtime_file_exists(runner) {
        print("error: inference runner not found: " + runner + "\n")
        print("Run `make build-real-inference-s` first.\n")
        return 1
    }

    print("\n╔════════════════════════════════════════════════════════════╗\n")
    print("║  NeurX Real Inference Interactive                          ║\n")
    print("║  Direct Model Invocation (No HTTP Backend)                 ║\n")
    print("╚════════════════════════════════════════════════════════════╝\n\n")
    print("Model: " + model_file + "\n")
    print("Runner: " + runner + "\n")
    print("Max new tokens: " + max_tokens + "\n")
    print("Type /exit to quit, /reset to clear history.\n\n")

    string history = "System: " + system_prompt + "\n"
    while true {
        print("You: ")
        string user_text = read_user_line()
        if len(user_text) == 0 || user_text == "/exit" || user_text == "exit" || user_text == "quit" {
            return 0
        }
        if user_text == "/reset" {
            history = "System: " + system_prompt + "\n"
            print("History cleared.\n\n")
            continue
        }

        string prompt_text = history + "User: " + user_text + "\nAssistant:"
        string output = run_model(runner, model_file, prompt_file, prompt_text, max_tokens)
        if len(output) == 0 {
            print("error: model runner returned no output\n\n")
            continue
        }

        string assistant_text = extract_assistant_text(output)
        if len(assistant_text) == 0 {
            assistant_text = trim(output)
        }
        if len(assistant_text) == 0 {
            print("error: empty model response\n\n")
            continue
        }

        print("Assistant: " + assistant_text + "\n\n")
        history = history + "User: " + user_text + "\nAssistant: " + assistant_text + "\n"
    }
}
