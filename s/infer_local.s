package main

use neurx.checkpoint.{load_checkpoint, checkpoint_params, checkpoint_param_count, checkpoint_step, checkpoint_loss}
use neurx.tensor.tensor

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    if neg {
        n = -n
    }
    string s = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        s = string(digit + 48) + s
        n = n / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func fmt_float(float val, int decimals) string {
    bool neg = val < 0.0
    if neg {
        val = -val
    }
    int whole = 0
    while val >= 1.0 {
        val = val - 1.0
        whole = whole + 1
    }
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        val = val * 10.0
        int digit = 0
        while val >= 1.0 {
            val = val - 1.0
            digit = digit + 1
        }
        s = s + string(digit + 48)
        i = i + 1
    }
    s
}

func ascii_code(string text, int idx) int {
    int(string(text[idx]))
}

func argmax_next_token(tensor weights, tensor bias, int prev_id, int vocab_size) int {
    int base = 0
    if len(weights.data) >= vocab_size * vocab_size {
        base = prev_id * vocab_size
        if base + vocab_size > len(weights.data) {
            base = 0
        }
    }

    float best_logit = weights.data[base] + bias.data[0]
    int best_id = 0
    int c = 1
    while c < vocab_size {
        float logit = weights.data[base + c] + bias.data[c]
        if logit > best_logit {
            best_logit = logit
            best_id = c
        }
        c = c + 1
    }
    best_id
}

func generate_text(tensor weights, tensor bias, string seed, int max_new_chars) string {
    int vocab_size = 256
    if len(weights.shape) >= 2 {
        vocab_size = weights.shape[1]
    }
    if len(weights.data) > 0 && len(weights.data) < vocab_size {
        vocab_size = len(weights.data)
    }
    if len(bias.data) > 0 && len(bias.data) < vocab_size {
        vocab_size = len(bias.data)
    }
    if vocab_size < 2 {
        vocab_size = 2
    }

    string output = seed
    int current_id = 32
    if len(seed) > 0 {
        current_id = ascii_code(seed, len(seed) - 1) - (ascii_code(seed, len(seed) - 1) / vocab_size) * vocab_size
    }

    int n = 0
    while n < max_new_chars {
        int next_id = argmax_next_token(weights, bias, current_id, vocab_size)
        output = output + string(next_id)
        current_id = next_id
        n = n + 1
    }
    output
}

func first_tensor([]tensor params) tensor {
    params[0]
}

func second_tensor([]tensor params) tensor {
    params[1]
}

func main() {
    string checkpoint_path = "artifacts/checkpoints/llm_s_pretrain"
    checkpoint ck = load_checkpoint(checkpoint_path)
    []tensor params = checkpoint_params(ck)
    int pcount = checkpoint_param_count(ck)

    println("================================================")
    println("NeurX checkpoint inference")
    println("================================================")
    println("Checkpoint path: " + checkpoint_path)
    println("Step: " + int_to_str(checkpoint_step(ck)))
    println("Loss: " + fmt_float(checkpoint_loss(ck), 4))
    println("Param count: " + int_to_str(pcount))
    println("Serialized weight items: " + int_to_str(len(params[0].data)))
    println("Serialized bias items: " + int_to_str(len(params[1].data)))
    println("")

    if pcount < 2 {
        println("Checkpoint does not contain model weights yet.")
        println("Expected at least 2 tensors: weights and bias.")
        return
    }

    string seed = "neurx "
    string generated = generate_text(first_tensor(params), second_tensor(params), seed, 120)

    println("Seed: " + seed)
    println("Generated:")
    println(generated)
    println("================================================")
}
