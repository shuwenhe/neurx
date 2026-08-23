package neurx.inference.production_chat_enhanced
use std.conv.int_to_string
use neurx.inference.runtime.real_text_engine.{real_text_engine_state, real_generation_result, load_real_text_engine, generate_response, generate_response_stream, resolve_model_path_from_env}

extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __host_slice(string text, int start, int end) string

func trim(string s) string {
    int i = 0
    while i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    return __host_slice(s, i, j + 1)
}

func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}

func generate_assistant_response(real_text_engine_state state, string prompt) string {
    if !state.ready {
        return "error: " + state.error_message
    }
    real_generation_result result = generate_response(state, prompt, 128)
    if !result.ok {
        if len(result.error_message) > 0 {
            return "error: " + result.error_message
        }
        return "error: real model inference failed"
    }
    return result.text
}

func stream_assistant_token(string token) bool {
    if len(token) > 0 {
        print(token + " ")
    }
    true
}

func main() {
    string model_path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string device_type = trim(runtime_env_get("NEURX_INFER_DEVICE", "cpu"))
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant."
    )
    print("╔════════════════════════════════════════════════════════════════╗\n")
    print("║         NeurX Production Chat - Enhanced Inference            ║\n")
    print("║         Pure S Language Implementation                        ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n\n")
    print("Configuration:\n")
    print("  Model Path: " + model_path + "\n")
    print("  Device: " + device_type + "\n")
    print("  Inference Mode: Real model-backed generation\n")
    print("  Implementation: Pure S Language\n\n")
    print("System Prompt: " + system_prompt + "\n\n")
    print("Commands:\n")
    print("  Type your question and press Enter\n")
    print("  /exit or exit to quit\n")
    print("  /reset to clear conversation history\n\n")
    real_text_engine_state state = load_real_text_engine(model_path)
    if !state.ready {
        print("error: " + state.error_message + "\n")
        return 1
    }
    string conversation_history = ""
    int turn_count = 0
    while true {
        print("You: ")
        string user_input = read_user_line()
        if len(user_input) == 0 {
            continue
        }
        if user_input == "/exit" || user_input == "exit" || user_input == "quit" {
            print("\nGoodbye!\n")
            return 0
        }
        if user_input == "/reset" {
            conversation_history = ""
            turn_count = 0
            print("Conversation history cleared.\n\n")
            continue
        }
        turn_count = turn_count + 1
        print("Assistant: ")
        real_generation_result result = generate_response_stream(state, user_input, 128, stream_assistant_token)
        string response = result.text
        print("\n\n")
        conversation_history = conversation_history + "User: " + user_input + "\n"
        conversation_history = conversation_history + "Assistant: " + response + "\n"
    }
}

func runtime_env_get(string name, string default_value) string {
    default_value
}
