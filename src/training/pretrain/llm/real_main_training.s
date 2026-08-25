package neurx.pretrain.llm.real_main_training
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, runtime_write_text_file}
use neurx.pretrain.llm.real_training_loop.{run_training_loop}

struct real_training_config {
    string manifest_path
    string data_dir
    string output_dir
    int batch_size
    int seq_length
    int vocab_size
    int hidden_dim
    int max_steps
    float learning_rate
}

func default_training_config() real_training_config {
    project_root := runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    data_root := runtime_env_get("NEURX_PRETRAIN_DATA_DIR", project_root + "/dataset/pretrain")
    real_training_config {
        manifest_path: runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json"),
        data_dir: data_root,
        output_dir: runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/artifact/checkpoints/llm_training"),
        batch_size: clamp_int(str_to_int(runtime_env_get("NEURX_PRETRAIN_MICRO_BATCH", runtime_env_get("NEURX_LLM_BATCH_SIZE", "8")), 8), 1, 1024),
        seq_length: clamp_int(str_to_int(runtime_env_get("NEURX_PRETRAIN_SEQ_LEN", runtime_env_get("NEURX_LLM_SEQ_LEN", "16")), 16), 1, 4096),
        vocab_size: clamp_int(str_to_int(runtime_env_get("NEURX_LLM_VOCAB_SIZE", "50257"), 50257), 256, 262144),
        hidden_dim: clamp_int(str_to_int(runtime_env_get("NEURX_LLM_HIDDEN_SIZE", "4096"), 4096), 256, 32768),
        max_steps: clamp_int(str_to_int(runtime_env_get("NEURX_PRETRAIN_STEPS", runtime_env_get("NEURX_LLM_STEPS", "64")), 64), 1, 1000000),
        learning_rate: str_to_float(runtime_env_get("NEURX_PRETRAIN_LR", runtime_env_get("NEURX_LLM_LR", "0.00015")))
    }
}

func build_fallback_manifest(real_training_config config) string {
    string shard_dir = config.data_dir + "/shard"
    string fallback_manifest = config.output_dir + "/shard_manifest.txt"
    string shard_list = runtime_run_command_output("find '" + shard_dir + "' -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort")
    if len(trim(shard_list)) == 0 {
        println("No shard files found under: " + shard_dir)
        return ""
    }
    runtime_write_text_file(fallback_manifest, shard_list)
    println("Using shard list manifest: " + fallback_manifest)
    fallback_manifest
}

func run_real_training_loop(real_training_config config) int {
    string manifest_path = config.manifest_path
    if !runtime_file_exists(manifest_path) {
        println("Missing manifest: " + manifest_path)
        manifest_path = build_fallback_manifest(config)
        if len(trim(manifest_path)) == 0 {
            return 1
        }
    }
    state := run_training_loop(manifest_path, config.max_steps, config.batch_size, config.seq_length, config.vocab_size, config.hidden_dim, config.learning_rate)
    println("Final step: " + int_to_str(state.step, 0))
    println("Tokens seen: " + int_to_str(state.tokens_seen, 0))
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

func string_char(int c) string {
    string(c)
}
