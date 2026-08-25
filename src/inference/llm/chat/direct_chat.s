package neurx.inference.direct_chat
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_read_string(int fd, int count) string

func contains_keyword(string text, string keyword) bool {
    int text_len = len(text)
    int keyword_len = len(keyword)
    if keyword_len > text_len {
        return false
    }
    int i = 0
    for i <= text_len - keyword_len {
        bool match = true
        int j = 0
        for j < keyword_len {
            string text_char = __host_slice(text, i + j, i + j + 1)
            string keyword_char = __host_slice(keyword, j, j + 1)
            if text_char != keyword_char {
                match = false
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    return false
}

func generate_response(string prompt) string {
    string model_path = neurx.inference.runtime.real_text_engine.resolve_model_path_from_env()
    real_text_engine_state state = neurx.inference.runtime.real_text_engine.load_real_text_engine(model_path)
    if !state.ready {
        return "error: " + state.error_message
    }
    real_generation_result result = neurx.inference.runtime.real_text_engine.generate_response(state, prompt, 128)
    if !result.ok {
        if len(result.error_message) > 0 {
            return "error: " + result.error_message
        }
        return "error: real model inference failed"
    }
    return result.text
}

func trim(string s) string {
    int i = 0
    for i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    for j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    return __host_slice(s, i, j + 1)
}

func main() {
    print("╔════════════════════════════════════════════════════════════════╗\n")
    print("║                                                                ║\n")
    print("║           NeurX Medical AI - Direct Mode (No HTTP)            ║\n")
    print("║                                                                ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n")
    print("\n")
    print("Model: /home/shuwen/shuwen/posttrain/model.safetensors\n")
    print("Backend: Pure S Language (Direct Mode)\n")
    print("Inference: Real model-backed generation\n")
    print("\n")
    print("Type medical questions (or /exit to quit)\n")
    print("════════════════════════════════════════════════════════════════\n\n")
    for true {
        print("You: ")
        string input = trim(__sys_read_string(0, 512))
        if input == "/exit" || input == "exit" {
            print("\nGoodbye!\n")
            return
        }
        if len(input) == 0 {
            continue
        }
        string response = generate_response(input)
        print("Assistant: " + response + "\n\n")
    }
}
