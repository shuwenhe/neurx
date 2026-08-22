use std.conv.int_to_string
package neurx.inference.file_backend
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

func runtime_run_command_output(string command) string {
    ""
}

func main() {
    print("NeurX Medical AI Backend - File IPC Mode\n")
    print("Listening on: /tmp/neurx_request.txt\n")
    print("Will write response to: /tmp/neurx_response.json\n\n")
    int sleep_count = 0
    while true {
        _ = runtime_run_command_output("sleep 0.1")
        sleep_count = sleep_count + 1
        if sleep_count % 10 == 0 {
            print("Backend waiting for requests (checked " + int_to_string(sleep_count) + " times)...\n")
        }
    }
}
