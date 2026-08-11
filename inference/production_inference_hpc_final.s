package neurx.inference.hpc
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, trim}
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, resolve_model_path_from_env, read_prompt_from_env, int_to_string, float_to_string}
func print_line(string text) {
    print(text)
    print("\n")
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
    string prompt = read_prompt_from_env()
    int max_new_tokens = parse_positive_int(runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", runtime_env_get("NEURX_MAX_TOKENS", "128")), 128)
    print_line("")
    print_line("╔════════════════════════════════════════════════════════════════╗")
    print_line("║       NeurX Production Inference Engine (Pure S)              ║")
    print_line("║          Real model-backed CPU execution path                  ║")
    print_line("╚════════════════════════════════════════════════════════════════╝")
    print_line("")
    print_line("Model Path: " + model_path)
    print_line("Prompt: " + prompt)
    print_line("Max New Tokens: " + int_to_string(max_new_tokens))
    print_line("")
    if !runtime_file_exists(model_path) && !runtime_file_exists(model_path + "/model.safetensors") {
        print_line("error: model path not found: " + model_path)
        return
    }
    real_text_engine_state state = load_real_text_engine(model_path)
    if !state.ready {
        print_line("error: " + state.error_message)
        return
    }
    real_generation_result result = generate_response(state, prompt, max_new_tokens)
    print_line("Backend: " + state.backend)
    print_line("Model: " + state.model_name)
    print_line("Prompt Tokens: " + int_to_string(result.prompt_tokens))
    print_line("Generated Tokens: " + int_to_string(result.generated_tokens))
    print_line("Estimated Latency: " + float_to_string(result.latency_ms) + " ms")
    print_line("")
    print_line("Response:")
    print_line(result.text)
    print_line("")
    string status = "fallback"
    if result.ok {
        status = "ok"
    }
    print_line("Status: " + status)
}
