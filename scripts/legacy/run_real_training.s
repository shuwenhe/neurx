package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use neurx.pretrain.llm.real_training_loop.{run_training_loop}

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let manifest = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    let output_dir = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/artifacts/checkpoints/llm_training")
    let batch_size = clamp_int(str_to_int(runtime_env_get("NEURX_PRETRAIN_MICRO_BATCH", runtime_env_get("NEURX_LLM_BATCH_SIZE", "8")), 8), 1, 1024)
    let seq_len = clamp_int(str_to_int(runtime_env_get("NEURX_PRETRAIN_SEQ_LEN", runtime_env_get("NEURX_LLM_SEQ_LEN", "16")), 16), 1, 4096)
    let steps = clamp_int(str_to_int(runtime_env_get("NEURX_PRETRAIN_STEPS", runtime_env_get("NEURX_LLM_STEPS", "64")), 64), 1, 1000000)
    let vocab_size = clamp_int(str_to_int(runtime_env_get("NEURX_LLM_VOCAB_SIZE", "50257"), 50257), 256, 262144)
    let hidden_dim = clamp_int(str_to_int(runtime_env_get("NEURX_LLM_HIDDEN_SIZE", "4096"), 4096), 256, 32768)
    let learning_rate = str_to_float(runtime_env_get("NEURX_PRETRAIN_LR", runtime_env_get("NEURX_LLM_LR", "0.00015")))
    println("═══════════════════════════════════════════════════════════")
    println("🚀 NeurX Real Training entry")
    println("═══════════════════════════════════════════════════════════")
    println("")
    println("Project root : " + project_root)
    println("manifest     : " + manifest)
    println("Output dir   : " + output_dir)
    println("batch_2 size   : " + int_to_str(batch_size, 0))
    println("Seq len      : " + int_to_str(seq_len, 0))
    println("Steps        : " + int_to_str(steps, 0))
    println("Vocab size   : " + int_to_str(vocab_size, 0))
    println("Hidden dim   : " + int_to_str(hidden_dim, 0))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    println("")
    if !runtime_file_exists(manifest) {
        println("Missing manifest: " + manifest)
        return 1
    }
    let final_state = run_training_loop(manifest, steps, batch_size, seq_len, vocab_size, hidden_dim, learning_rate)
    println("")
    println("═══════════════════════════════════════════════════════════")
    println("Training finished")
    println("Final step    : " + int_to_str(final_state.step, 0))
    println("Tokens seen   : " + int_to_str(final_state.tokens_seen, 0))
    if final_state.step > 0 {
        println("Avg loss      : " + fmt_float(final_state.total_loss / (final_state.step as float), 6))
    } else {
        println("Avg loss      : 0.0")
    }
    println("Output dir    : " + output_dir)
    println("═══════════════════════════════════════════════════════════")
    0
}

func str_to_int(string s, int fallback) int {
    string text = trim(s)
    if len(text) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func str_to_float(string s) float {
    string text = trim(s)
    if len(text) == 0 {
        return 0.0
    }
    bool neg = false
    int i = 0
    if text[0] == 45 {
        neg = true
        i = 1
    }
    float whole = 0.0
    while i < len(text) && text[i] >= 48 && text[i] <= 57 {
        whole = whole * 10.0 + (text[i] - 48) * 1.0
        i = i + 1
    }
    float frac = 0.0
    float scale = 1.0
    if i < len(text) && text[i] == 46 {
        i = i + 1
        while i < len(text) && text[i] >= 48 && text[i] <= 57 {
            frac = frac * 10.0 + (text[i] - 48) * 1.0
            scale = scale * 10.0
            i = i + 1
        }
    }
    float value = whole + frac / scale
    if neg {
        value = 0.0 - value
    }
    value
}

func clamp_int(int value, int min_value, int max_value) int {
    if value < min_value {
        return min_value
    }
    if value > max_value {
        return max_value
    }
    value
}

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
    string out = ""
    int k = i
    while k <= j {
        out = out + string_char(s[k])
        k = k + 1
    }
    out
}

func int_to_str(int n, int fallback) string {
    int value = n
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    if neg {
        value = -value
    }
    string s = ""
    while value > 0 {
        s = string_char(value - (value / 10) * 10 + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func fmt_float(float val, int decimals) string {
    float value = val
    if value == 0.0 {
        return "0.0"
    }
    bool neg = value < 0.0
    if neg {
        value = 0.0 - value
    }
    int int_part = 0
    float whole = value
    while whole >= 1.0 {
        whole = whole - 1.0
        int_part = int_part + 1
    }
    float frac = value - int_part
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part, 0) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = 0
        float tmp = frac
        while tmp >= 1.0 {
            tmp = tmp - 1.0
            digit = digit + 1
        }
        s = s + string_char(digit + 48)
        frac = frac - digit
        i = i + 1
    }
    s
}

func string_char(int c) string {
    string(c)
}
