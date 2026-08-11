package neurx.inference.hpc
use neurx.runtime.io.{runtime_env_get, trim}
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, resolve_model_path_from_env, int_to_string, float_to_string}
extern "intrinsic" func __sys_read_string(int fd, int count) string
func print_line(string text) {
    print(text)
    print("\n")
}
func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}
func parse_positive_int(string text, int fallback) int {
    if len(text) == 0 {
        return fallback
    }
    int value = 0
    int index = 0
    while index < len(text) {
        int ch = text[index]
        if ch < 48 || ch > 57 {
            return fallback
        }
        value = value * 10 + (ch - 48)
        index = index + 1
    }
    if value <= 0 {
        return fallback
    }
    value
}
func main() {
    string model_path = resolve_model_path_from_env()
    int max_new_tokens = parse_positive_int(runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", runtime_env_get("NEURX_MAX_TOKENS", "128")), 128)
    print_line("")
    print_line("╔════════════════════════════════════════════════════════════════╗")
    print_line("║       NeurX Production Chat (Pure S)                          ║")
    print_line("║          Real model-backed interactive inference              ║")
    print_line("╚════════════════════════════════════════════════════════════════╝")
    print_line("")
    print_line("Model Path: " + model_path)
    print_line("Max New Tokens: " + int_to_string(max_new_tokens))
    print_line("")
    real_text_engine_state state = load_real_text_engine(model_path)
    if !state.ready {
        print_line("error: " + state.error_message)
        return
    }
    print_line("Backend: " + state.backend)
    print_line("Model: " + state.model_name)
    print_line("")
    print_line("Type 'exit' to quit or 'reset' to clear the session.")
    print_line("")
    int turn_count = 0
    int total_prompt_tokens = 0
    int total_generated_tokens = 0
    float total_latency_ms = 0.0
    while true {
        print("You: ")
        string user_input = read_user_line()
        if len(user_input) == 0 {
            continue
        }
        if user_input == "exit" || user_input == "quit" {
            print_line("")
            print_line("Turns: " + int_to_string(turn_count))
            print_line("Prompt Tokens: " + int_to_string(total_prompt_tokens))
            print_line("Generated Tokens: " + int_to_string(total_generated_tokens))
            print_line("Total Latency: " + float_to_string(total_latency_ms) + " ms")
            return
        }
        if user_input == "reset" {
            turn_count = 0
            total_prompt_tokens = 0
            total_generated_tokens = 0
            total_latency_ms = 0.0
            print_line("Session reset.")
            continue
        }
        real_generation_result result = generate_response(state, user_input, max_new_tokens)
        turn_count = turn_count + 1
        total_prompt_tokens = total_prompt_tokens + result.prompt_tokens
        total_generated_tokens = total_generated_tokens + result.generated_tokens
        total_latency_ms = total_latency_ms + result.latency_ms
        print_line("")
        print_line("Assistant: " + result.text)
        print_line("Prompt Tokens: " + int_to_string(result.prompt_tokens))
        print_line("Generated Tokens: " + int_to_string(result.generated_tokens))
        print_line("Latency: " + float_to_string(result.latency_ms) + " ms")
        print_line("")
    }
}
