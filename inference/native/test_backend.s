use std.conv.int_to_string
package neurx.inference.test_backend
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, resolve_model_path_from_env}
extern "intrinsic" func __host_slice(string text, int start, int end) string

func contains_keyword(string text, string keyword) bool {
    int text_len = len(text)
    int keyword_len = len(keyword)
    if keyword_len > text_len {
        return false
    }
    int i = 0
    while i <= text_len - keyword_len {
        bool match = true
        int j = 0
        while j < keyword_len {
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

func generate_response(string prompt, int max_tokens) string {
    string model_path = resolve_model_path_from_env()
    real_text_engine_state state = load_real_text_engine(model_path)
    if !state.ready {
        return "error: " + state.error_message
    }
    real_generation_result result = generate_response(state, prompt, max_tokens)
    if !result.ok {
        if len(result.error_message) > 0 {
            return "error: " + result.error_message
        }
        return "error: real model inference failed"
    }
    return result.text
}
extern "intrinsic" func __sys_read_string(int fd, int count) string

func main() {
    print("NeurX Medical AI Backend - Interactive Mode\n")
    print("Type medical queries (or /exit to quit)\n")
    print("\n")
    while true {
        print("You: ")
        string input = __sys_read_string(0, 512)
        if input == "/exit" || input == "exit" {
            print("Goodbye!\n")
            return
        }
        if len(input) == 0 {
            continue
        }
        string response = generate_response(input, 128)
        print("Assistant: " + response + "\n\n")
    }
}
