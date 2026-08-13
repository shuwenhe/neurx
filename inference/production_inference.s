package neurx.inference.production_inference
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, resolve_model_path_from_env, read_prompt_from_env, int_to_string, float_to_string}
func main() {
    string model_path = resolve_model_path_from_env()
    string prompt = read_prompt_from_env()
    int max_new_tokens = 128
    string env_max = runtime_env_get("NEURX_MAX_TOKENS", "")
    if len(env_max) > 0 {
        int parsed = 0
        int index = 0
        bool valid = true
        while index < len(env_max) {
            int ch = env_max[index]
            if ch < 48 || ch > 57 {
                valid = false
                break
            }
            parsed = parsed * 10 + (ch - 48)
            index = index + 1
        }
        if valid && parsed > 0 {
            max_new_tokens = parsed
        }
    }
    print("================================================\n")
    print("NeurX Production Inference (Pure S)\n")
    print("================================================\n")
    print("Model: " + model_path + "\n")
    print("Prompt: " + prompt + "\n")
    print("Max New Tokens: " + int_to_string(max_new_tokens) + "\n")
    if !runtime_file_exists(model_path) && !runtime_file_exists(model_path + "/model.safetensors") {
        print("error: model path not found: " + model_path + "\n")
        return
    }
    real_text_engine_state state = load_real_text_engine(model_path)
    if !state.ready {
        print("error: " + state.error_message + "\n")
        return
    }
    real_generation_result result = generate_response(state, prompt, max_new_tokens)
    print("Backend: " + state.backend + "\n")
    print("Prompt Tokens: " + int_to_string(result.prompt_tokens) + "\n")
    print("Generated Tokens: " + int_to_string(result.generated_tokens) + "\n")
    print("Latency: " + float_to_string(result.latency_ms) + " ms\n")
    print("Response:\n")
    print(result.text + "\n")
}
