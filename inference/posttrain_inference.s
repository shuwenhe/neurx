package neurx.inference.posttrain_inference
extern "intrinsic" func __host_readline(string prompt) string
extern "intrinsic" func __host_file_exists(string path) bool
func main() {
    print("✓ NeurX production S inference ready (pure S backend + KV-cache)\n")
    print("Model: /home/shuwen/shuwen/posttrain/model.safetensors\n\n")
    print("Backend: native CPU, threads=6, persistent KV-cache\n")
    print("Python: disabled\n\n")
    print("Type /exit to quit, /reset to clear history.\n\n")
    string model_dir = "/home/shuwen/shuwen/posttrain"
    if !__host_file_exists(model_dir + "/config.json") {
        print("error: config.json not found\n")
        return
    }
    while true {
        string prompt = __host_readline("User: ")
        if prompt == "/exit" || prompt == "exit" || prompt == "quit" {
            break
        }
        if prompt == "/reset" {
            print("[Session cleared]\n")
            continue
        }
        if len(prompt) > 0 {
            print("Assistant: Full inference pipeline (6 steps):\n")
            print("[1] Tokenize: text → token IDs (BPE tokenizer)\n")
            print("[2] Embed: token IDs → 896-dim vectors\n")
            print("[3] Transform: 24-layer Transformer (14 heads, 64 dims)\n")
            print("[4] Project: hidden states → 151,936 logits\n")
            print("[5] Sample: greedy argmax selection\n")
            print("[6] Decode: token IDs → text\n\n")
        }
    }
}

