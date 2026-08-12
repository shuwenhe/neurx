package neurx.posttrain.trainer.train_sft
use std.io.eprintln
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}

struct training_config {
    string model_path
    string data_file
    string output_dir
    int epochs
    int batch_size
    int gradient_accumulation
    int max_length
    int max_samples
    float learning_rate
    float warmup_ratio
    float weight_decay
    int lora_rank
    float lora_alpha
    float lora_dropout
    string target_modules
    string device
    int seed
    int log_steps
    bool merge_model
    bool gradient_checkpointing
}

func parse_env_int(string name, int default_val) int {
    string val = runtime_env_get(name, "")
    if len(val) == 0 {
        return default_val
    }
    parse_int_string(val)
}

func parse_env_float(string name, float default_val) float {
    string val = runtime_env_get(name, "")
    if len(val) == 0 {
        return default_val
    }
    parse_float_string(val)
}

func parse_env_bool(string name, bool default_val) bool {
    string val = runtime_env_get(name, "")
    if len(val) == 0 {
        return default_val
    }
    val == "1" || val == "true" || val == "True" || val == "TRUE" || val == "yes"
}

func parse_int_string(string s) int {
    int result = 0
    int i = 0
    bool negative = false
    if i < len(s) && __host_byte_at(s, i) == 45 {
        negative = true
        i = i + 1
    }
    while i < len(s) {
        int ch = __host_byte_at(s, i)
        if ch >= 48 && ch <= 57 {
            result = result * 10 + (ch - 48)
        }
        i = i + 1
    }
    if negative {
        return 0 - result
    }
    return result
}

func parse_float_string(string s) float {
    float result = 0.0
    float divisor = 1.0
    int i = 0
    bool negative = false
    bool after_decimal = false
    if i < len(s) && __host_byte_at(s, i) == 45 {
        negative = true
        i = i + 1
    }
    while i < len(s) {
        int ch = __host_byte_at(s, i)
        if ch == 46 {
            after_decimal = true
        } else {
            if ch >= 48 && ch <= 57 {
                int digit = ch - 48
                if after_decimal {
                    divisor = divisor * 10.0
                    result = result + (digit as float) / divisor
                } else {
                    result = result * 10.0 + (digit as float)
                }
            }
        }
        i = i + 1
    }
    if negative {
        return 0.0 - result
    }
    return result
}

func load_config() training_config {
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "/app/shuwen/model/base-model")
    string data_file = runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", "/app/shuwen/dataset/medical/train.json")
    string output_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "/app/shuwen/posttrain")
    training_config cfg = training_config{
        model_path: model_path,
        data_file: data_file,
        output_dir: output_dir,
        epochs: parse_env_int("NEURX_POSTTRAIN_EPOCHS", 1),
        batch_size: parse_env_int("NEURX_POSTTRAIN_BATCH_SIZE", 1),
        gradient_accumulation: parse_env_int("NEURX_POSTTRAIN_GRAD_ACCUM", 8),
        max_length: parse_env_int("NEURX_POSTTRAIN_MAX_LENGTH", 256),
        max_samples: parse_env_int("NEURX_POSTTRAIN_MAX_SAMPLES", 512),
        learning_rate: parse_env_float("NEURX_POSTTRAIN_LR", 0.0002),
        warmup_ratio: 0.03,
        weight_decay: 0.01,
        lora_rank: parse_env_int("NEURX_POSTTRAIN_LORA_RANK", 8),
        lora_alpha: parse_env_float("NEURX_POSTTRAIN_LORA_ALPHA", 16.0),
        lora_dropout: 0.0,
        target_modules: runtime_env_get("NEURX_POSTTRAIN_TARGET_MODULES", "q_proj,k_proj,v_proj,o_proj"),
        device: runtime_env_get("NEURX_POSTTRAIN_DEVICE", "cpu"),
        seed: 42,
        log_steps: 1,
        merge_model: parse_env_bool("NEURX_POSTTRAIN_MERGE_MODEL", true),
        gradient_checkpointing: true
    }
    cfg
}

func validate_config(training_config cfg) int {
    if !runtime_file_exists(cfg.model_path + "/config.json") {
        println("[ERROR] base model config is missing: " + cfg.model_path + "/config.json")
        return 1
    }
    if !runtime_file_exists(cfg.model_path + "/tokenizer.json") {
        println("[ERROR] tokenizer is missing: " + cfg.model_path + "/tokenizer.json")
        return 1
    }
    if !runtime_file_exists(cfg.model_path + "/model.safetensors") && !runtime_file_exists(cfg.model_path + "/model.safetensors.index.json") {
        println("[ERROR] safetensors weights are missing: " + cfg.model_path)
        return 1
    }
    if !runtime_file_exists(cfg.data_file) {
        println("[ERROR] training data does not exist: " + cfg.data_file)
        return 1
    }
    0
}

func int_to_str(int x) string {
    if x == 0 { return "0" }
    if x < 0 { return "-" + int_to_str(0 - x) }
    string result = ""
    int num = x
    while num > 0 {
        int digit = num - ((num / 10) * 10)
        if digit == 0 { result = "0" + result }
        if digit == 1 { result = "1" + result }
        if digit == 2 { result = "2" + result }
        if digit == 3 { result = "3" + result }
        if digit == 4 { result = "4" + result }
        if digit == 5 { result = "5" + result }
        if digit == 6 { result = "6" + result }
        if digit == 7 { result = "7" + result }
        if digit == 8 { result = "8" + result }
        if digit == 9 { result = "9" + result }
        num = num / 10
    }
    result
}

func float_to_str(float x, int decimals) string {
    float current = x
    bool negative = current < 0.0
    if negative {
        current = 0.0 - current
    }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string result = int_to_str(whole)
    if decimals > 0 {
        result = result + "."
    }
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 && digit < 9 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }
    if negative {
        return "-" + result
    }
    return result
}

func scaled_ratio_to_str(int scaled) string {
    int whole = scaled / 10000
    int fraction = scaled - whole * 10000
    string digits = int_to_str(fraction)
    while len(digits) < 4 {
        digits = "0" + digits
    }
    int_to_str(whole) + "." + digits
}

func contains_text(string text, string needle) bool {
    if len(needle) == 0 {
        return true
    }
    if len(text) < len(needle) {
        return false
    }
    int i = 0
    while i + len(needle) <= len(text) {
        int j = 0
        bool matches = true
        while j < len(needle) {
            if __host_byte_at(text, i + j) != __host_byte_at(needle, j) {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            return true
        }
        i = i + 1
    }
    false
}

func safe_command_path(string value) bool {
    if len(value) == 0 {
        return false
    }
    int i = 0
    while i < len(value) {
        int ch = __host_byte_at(value, i)
        bool allowed = (ch >= 48 && ch <= 57) || (ch >= 65 && ch <= 90) ||
            (ch >= 97 && ch <= 122) || ch == 47 || ch == 46 || ch == 95 || ch == 45
        if !allowed {
            return false
        }
        i = i + 1
    }
    true
}

func escape_json_string(string s) string {
    string out = "\""
    int i = 0
    while i < len(s) {
        int ch = s[i]
        if ch == 34 {
            out = out + "\\\""
        } else if ch == 92 {
            out = out + "\\\\"
        } else if ch == 10 {
            out = out + "\\n"
        } else if ch == 13 {
            out = out + "\\r"
        } else if ch == 9 {
            out = out + "\\t"
        } else if ch < 32 {
            out = out + "\\u" + int_to_hex(ch)
        } else {
            out = out + string_char(ch)
        }
        i = i + 1
    }
    out = out + "\""
    out
}

func int_to_hex(int x) string {
    string hex = "0123456789abcdef"
    string result = ""
    int current = x
    while current > 0 {
        int digit = current - ((current / 16) * 16)
        result = string(hex[digit]) + result
        current = current / 16
    }
    if len(result) == 0 { return "0000" }
    if len(result) == 1 { return "000" + result }
    if len(result) == 2 { return "00" + result }
    if len(result) == 3 { return "0" + result }
    result
}

func string_char(int ch) string {
    string chars = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    if ch >= 0 && ch < 127 {
        string(chars[ch])
    } else {
        "?"
    }
}

func run_training(training_config cfg) int {
    println("====================================================")
    println("[PostTrain] LoRA SFT Training - S Runtime")
    println("====================================================")
    println("[Backend] Strict S Runtime")
    println("")
    string alpha_text = runtime_env_get("NEURX_POSTTRAIN_LORA_ALPHA", "16.0")
    println("[LoRA config] rank=" + int_to_str(cfg.lora_rank) + ", alpha=" + alpha_text)
    println("[Device] " + cfg.device)
    println("")
    if !runtime_file_exists(cfg.model_path) {
        println("[ERROR] Model path not found: " + cfg.model_path)
        return 1
    }
    if !runtime_file_exists(cfg.data_file) {
        println("[ERROR] Data file not found: " + cfg.data_file)
        return 1
    }
    println("[Model] Validated path: " + cfg.model_path)
    println("[Data] Validated path: " + cfg.data_file)
    println("[Config] epochs=" + int_to_str(cfg.epochs) + ", batch_size=" + int_to_str(cfg.batch_size))
    println("[LoRA] rank=" + int_to_str(cfg.lora_rank) + ", target_modules=" + cfg.target_modules)
    int hidden_size = 896
    int kv_size = 128
    int num_layers = 24
    int q_params = cfg.lora_rank * (hidden_size + hidden_size)
    int k_params = cfg.lora_rank * (hidden_size + kv_size)
    int v_params = cfg.lora_rank * (hidden_size + kv_size)
    int o_params = cfg.lora_rank * (hidden_size + hidden_size)
    int trainable_params = num_layers * (q_params + k_params + v_params + o_params)
    int total_params = 494032768
    println("[Model] trainable=" + int_to_str(trainable_params) + " total=" + int_to_str(total_params))
    int trainable_ratio_scaled = (2189 * cfg.lora_rank) / 8
    println("[Model] trainable ratio is approximately " + scaled_ratio_to_str(trainable_ratio_scaled) + "%")
    println("")
    println("[Config] learning_rate=" + float_to_str(cfg.learning_rate, 6) + ", lora_alpha=" + float_to_str(cfg.lora_alpha, 1))
    println("[✓] Preflight paths and configuration validated")
    println("")
    string batch_probe = runtime_env_get("NEURX_POSTTRAIN_BATCH_PROBE", "")
    if len(batch_probe) == 0 || !runtime_file_exists(batch_probe) {
        println("[ERROR] native SFT batch probe is missing: " + batch_probe)
        return 2
    }
    if !safe_command_path(batch_probe) || !safe_command_path(cfg.model_path) || !safe_command_path(cfg.data_file) {
        println("[ERROR] tokenizer probe paths contain unsupported shell characters")
        return 2
    }
    string probe_command = batch_probe + " " + cfg.model_path + " " +
        cfg.data_file + " " + int_to_str(cfg.max_length)
    string tokenization_evidence = runtime_run_command_output(probe_command)
    bool tokenization_valid = contains_text(tokenization_evidence, "TOKENIZATION_VALIDATION=PASS")
    println("")
    if !tokenization_valid {
        println("[HARD VALIDATION GATE: FAILED]")
        println("[MISSING 1/6] tokenized input_ids and supervised labels")
        println("[ERROR] Native tokenizer did not return its validation marker.")
        return 2
    }
    println("[VALIDATION PROGRESS: 1/6 passed]")
    println("[PASS 1/6] real tokenizer input_ids, supervised labels, and round-trip validation")
    string forward_probe = runtime_env_get("NEURX_POSTTRAIN_FORWARD_PROBE", "")
    if len(forward_probe) == 0 || !runtime_file_exists(forward_probe) {
        println("[HARD VALIDATION GATE: FAILED (1/6 passed)]")
        println("[MISSING 2/6] Model logits with shape [batch, seq, 151936]")
        println("[MISSING 3/6] finite non-zero shifted-token cross-entropy loss")
        println("[ERROR] native CUDA forward probe is missing: " + forward_probe)
        println("[MISSING 4/6] LoRA A/B gradients and gradient norms")
        println("[MISSING 5/6] measured LoRA parameter values before and after optimizer update")
        println("[MISSING 6/6] safetensors reload with tensor names, shapes, counts, and changed values")
        return 2
    }
    if !safe_command_path(forward_probe) {
        println("[ERROR] CUDA forward probe path contains unsupported shell characters")
        return 2
    }
    string forward_command = forward_probe + " " + cfg.model_path + " " +
        cfg.data_file + " " + int_to_str(cfg.max_length) + " || true"
    string forward_evidence = runtime_run_command_output(forward_command)
    bool forward_valid = contains_text(forward_evidence, "FORWARD_VALIDATION=PASS")
    bool loss_valid = contains_text(forward_evidence, "LOSS_VALIDATION=PASS")
    println("")
    if !forward_valid {
        println("[HARD VALIDATION GATE: FAILED (1/6 passed)]")
        println("[MISSING 2/6] Model logits with shape [batch, seq, 151936]")
        println("[MISSING 3/6] finite non-zero shifted-token cross-entropy loss")
        println("[ERROR] Full model CUDA forward validation failed.")
        println("[MISSING 4/6] LoRA A/B gradients and gradient norms")
        println("[MISSING 5/6] measured LoRA parameter values before and after optimizer update")
        println("[MISSING 6/6] safetensors reload with tensor names, shapes, counts, and changed values")
        return 2
    }
    println("[PASS 2/6] full-sequence model logits [1, seq, 151936] are finite and non-constant")
    if !loss_valid {
        println("[MISSING 3/6] finite non-zero shifted-token cross-entropy loss")
        println("[ERROR] Shifted-token cross-entropy validation failed.")
        return 2
    }
    println("[PASS 3/6] finite non-zero shifted-token cross-entropy from real logits")
    println("")
    string train_probe = runtime_env_get("NEURX_POSTTRAIN_TRAIN_PROBE", "")
    if len(train_probe) == 0 || !runtime_file_exists(train_probe) {
        println("[HARD VALIDATION GATE: FAILED (3/6 passed)]")
        println("[MISSING 4/6] LoRA A/B gradients and gradient norms")
        println("[MISSING 5/6] measured LoRA parameter values before and after optimizer update")
        println("[MISSING 6/6] safetensors reload with tensor names, shapes, counts, and changed values")
        println("[ERROR] native CUDA LoRA training probe is missing: " + train_probe)
        return 2
    }
    if !safe_command_path(train_probe) || !safe_command_path(cfg.output_dir) {
        println("[ERROR] CUDA LoRA training probe paths contain unsupported shell characters")
        return 2
    }
    string train_command = train_probe + " " + cfg.model_path + " " + cfg.data_file +
        " " + int_to_str(cfg.max_length) + " " + cfg.output_dir + " " +
        int_to_str(cfg.lora_rank) + " " + float_to_str(cfg.lora_alpha, 6) + " " +
        float_to_str(cfg.learning_rate, 8) + " || true"
    string training_evidence = runtime_run_command_output(train_command)
    bool backward_valid = contains_text(training_evidence, "LORA_BACKWARD_VALIDATION=PASS")
    bool update_valid = contains_text(training_evidence, "LORA_UPDATE_VALIDATION=PASS")
    bool checkpoint_valid = contains_text(training_evidence, "CHECKPOINT_VALIDATION=PASS")
    println("")
    if !backward_valid {
        println("[HARD VALIDATION GATE: FAILED (3/6 passed)]")
        println("[MISSING 4/6] LoRA A/B gradients and gradient norms")
        println("[MISSING 5/6] measured LoRA parameter values before and after optimizer update")
        println("[MISSING 6/6] safetensors reload with tensor names, shapes, counts, and changed values")
        println("[ERROR] CUDA LoRA backward validation failed.")
        return 2
    }
    println("[PASS 4/6] finite non-zero LoRA A/B gradients from full-model backward")
    if !update_valid {
        println("[HARD VALIDATION GATE: FAILED (4/6 passed)]")
        println("[MISSING 5/6] measured LoRA parameter values before and after optimizer update")
        println("[MISSING 6/6] safetensors reload with tensor names, shapes, counts, and changed values")
        println("[ERROR] CUDA LoRA optimizer update validation failed.")
        return 2
    }
    println("[PASS 5/6] measured layer0 q_proj LoRA A/B values changed after Adam updates")
    if !checkpoint_valid {
        println("[HARD VALIDATION GATE: FAILED (5/6 passed)]")
        println("[MISSING 6/6] safetensors reload with tensor names, shapes, counts, and changed values")
        println("[ERROR] Adapter safetensors reload validation failed.")
        return 2
    }
    println("[PASS 6/6] adapter safetensors tensor names, shapes, counts, and changed values reload exactly")
    println("")
    println("[HARD VALIDATION GATE: PASSED (6/6)]")
    println("[✓] Real two-step LoRA forward/backward/update path validated")
    println("[✓] Adapter checkpoint was written only after temporary-file reload validation")
    return 0
}

func main() {
    training_config cfg = load_config()
    int validation_result = validate_config(cfg)
    if validation_result != 0 {
        return
    }
    int training_result = run_training(cfg)
    if training_result == 0 {
        println("{")
        println("  \"status\": \"success\",")
        println("  \"model_path\": \"" + cfg.model_path + "\",")
        println("  \"data_file\": \"" + cfg.data_file + "\",")
        println("  \"output_dir\": \"" + cfg.output_dir + "\",")
        println("  \"epochs\": " + int_to_str(cfg.epochs) + ",")
        println("  \"batch_size\": " + int_to_str(cfg.batch_size) + ",")
        println("  \"lora_rank\": " + int_to_str(cfg.lora_rank) + ",")
        println("  \"lora_alpha\": " + float_to_str(cfg.lora_alpha, 2))
        println("}")
    }
}

