package neurx.inference.true_model_inference

use neurx.inference.safetensors_real.{load_model_safetensors}
use neurx.inference.tokenizer_loader.{load_tokenizer, tokenize}
use step2_embedding.{embed_tokens}
use step3_transformer.{create_transformer_config, transformer_forward}
use step5_sampling_step6_decode.{create_sampling_config, generate, decode_tokens}

extern "intrinsic" func __host_slice(string text, int start, int end) string

func int_to_string(int val) string {
    if val == 0 { return "0" }
    string result = ""
    int current = val
    while current != 0 {
        int digit = current - (current / 10) * 10
        result = __host_slice("0123456789", digit, digit + 1) + result
        current = current / 10
    }
    result
}

func main() {
    string model_path = "/home/shuwen/shuwen/posttrain/model.safetensors"
    print("Starting NeurX real inference pipeline...\n")
    print("[1] Load safetensors header and validate model\n")
    string load_status = load_model_safetensors(model_path)
    print("safetensors: " + load_status + "\n\n")
    print("[2] Load tokenizer\n")
    tokenizer_state_2 := load_tokenizer("/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    if !tokenizer_state_2.is_loaded {
        print("Tokenizer load failed: " + tokenizer_state_2.error_message + "\n")
        return
    }
    string user_prompt = "糖尿病的治疗"
    print("User prompt: " + user_prompt + "\n")
    print("[3] Tokenize input\n")
    token_result := tokenize(tokenizer_state_2, user_prompt)
    if !token_result.success {
        print("Tokenization error: " + token_result.error + "\n")
        return
    }
    []int prompt_tokens = token_result.token_ids
    print("Tokenized: " + int_to_string(len(prompt_tokens)) + " tokens\n")
    print("[4] Embedding lookup\n")
    [][]float embeddings = embed_tokens(prompt_tokens)
    print("Embeddings shape: [" + int_to_string(len(embeddings)) + ", 896] (per token)\n")
    print("[5] Transformer forward\n")
    cfg := create_transformer_config()
    [][]float hidden = transformer_forward(embeddings)
    print("Transformer output shape: [" + int_to_string(len(hidden)) + ", " + int_to_string(cfg.hidden_size) + "]\n")
    // --- Numeric verification: compute mean/std for this output
    func compute_mean_std([][]float mat) (float, float) {
        int rows = len(mat)
        if rows == 0 { return 0.0, 0.0 }
        int cols = len(mat[0])
        float sum = 0.0
        int i = 0
        while i < rows {
            int j = 0
            while j < cols {
                sum = sum + mat[i][j]
                j = j + 1
            }
            i = i + 1
        }
        int N = rows * cols
        float mean = sum / float(N)
        float acc = 0.0
        i = 0
        while i < rows {
            int j = 0
            while j < cols {
                float d = mat[i][j] - mean
                acc = acc + d * d
                j = j + 1
            }
            i = i + 1
        }
        float var = acc / float(N)
        // sqrt via Newton iterations
        func sqrt_approx(float x) float {
            if x <= 0.0 { return 0.0 }
            float y = x
            int k = 0
            while k < 10 {
                y = 0.5 * (y + x / y)
                k = k + 1
            }
            y
        }
        float std = sqrt_approx(var)
        mean, std
    }

    float m, s
    m, s = compute_mean_std(hidden)
    print("[VERIFY] prompt -> transformer mean=" + int_to_string(int(m * 1000.0)) + " (x1e-3), std=" + int_to_string(int(s * 1000.0)) + " (x1e-3)\n")
    print("[6] Sampling / generate continuation\n")
    sampling_cfg := create_sampling_config()
    []int generated = generate(prompt_tokens, 32, sampling_cfg)
    print("Generated tokens: " + int_to_string(len(generated) - len(prompt_tokens)) + "\n")
    print("[7] Decode tokens to string\n")
    string output = decode_tokens(generated)
    print("Model output:\n" + output + "\n")
    print("Inference pipeline completed.\n")

    // Single-token random test
    print("\n[VERIFY] Running single-token numeric test...\n")
    []int single = []int{2048}
    [][]float emb_single = embed_tokens(single)
    [][]float out_single = transformer_forward(emb_single)
    float m2, s2
    m2, s2 = compute_mean_std(out_single)
    print("[VERIFY] single-token -> mean=" + int_to_string(int(m2 * 1000.0)) + " (x1e-3), std=" + int_to_string(int(s2 * 1000.0)) + " (x1e-3)\n")
}
