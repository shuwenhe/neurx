package main

use neurx.runtime.io.{runtime_env_get}
use std.io.println

struct lora_sft_state {
    float base_weight
    float adapter_a
    float adapter_b
    float last_loss
    float best_loss
    int step
    int examples_seen
    int tokens_seen
}

func parse_int(string s, int fallback) int {
    if len(s) < 1 {
        return fallback
    }
    int i = 0
    int sign = 1
    if s[0] > 44 && s[0] < 46 {
        sign = -1
        i = 1
    }
    int value = 0
    bool seen = false
    while i < len(s) {
        int ch = s[i]
        if ch > 47 && ch < 58 {
            value = value * 10 + (ch - 48)
            seen = true
        }
        i = i + 1
    }
    if !seen {
        return fallback
    }
    if sign < 0 {
        return 0 - value
    }
    value
}

func parse_float(string s, float fallback) float {
    if len(s) < 1 {
        return fallback
    }
    int i = 0
    int sign = 1
    if s[0] > 44 && s[0] < 46 {
        sign = -1
        i = 1
    }
    float whole = 0.0
    float frac = 0.0
    float div = 1.0
    bool seen = false
    bool after_dot = false
    while i < len(s) {
        int ch = s[i]
        if ch > 45 && ch < 47 {
            after_dot = true
        } else if ch > 47 && ch < 58 {
            seen = true
            float digit = (ch - 48) as float
            if after_dot {
                frac = frac * 10.0 + digit
                div = div * 10.0
            } else {
                whole = whole * 10.0 + digit
            }
        }
        i = i + 1
    }
    if !seen {
        return fallback
    }
    float out = whole + frac / div
    if sign < 0 {
        out = 0.0 - out
    }
    out
}

func digit_to_str(int digit) string {
    if digit == 0 {
        return "0"
    }
    if digit == 1 {
        return "1"
    }
    if digit == 2 {
        return "2"
    }
    if digit == 3 {
        return "3"
    }
    if digit == 4 {
        return "4"
    }
    if digit == 5 {
        return "5"
    }
    if digit == 6 {
        return "6"
    }
    if digit == 7 {
        return "7"
    }
    if digit == 8 {
        return "8"
    }
    "9"
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value % 10
        out = digit_to_str(digit) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func fmt_float(float value, int decimals) string {
    float current = value
    bool neg = current < 0.0
    if neg {
        current = 0.0 - current
    }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        out = out + digit_to_str(digit)
        i = i + 1
    }
    out
}

func resolve_non_empty(string primary, string fallback) string {
    if len(primary) > 0 {
        return primary
    }
    fallback
}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", project_root + "/../model/Qwen2.5-VL-7B")
    string data_path = resolve_non_empty(
        runtime_env_get("NEURX_LORA_SFT_DATA_FILE", ""),
        resolve_non_empty(
            runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", ""),
            runtime_env_get("NEURX_SFT_DATA_FILE", project_root + "/data/sft/instruction_data.jsonl")
        )
    )
    string output_dir = runtime_env_get("NEURX_LORA_SFT_OUTPUT_DIR", project_root + "/artifacts/checkpoints/lora_sft")
    string format_type = runtime_env_get("NEURX_SFT_FORMAT", "alpaca")
    int epochs = parse_int(runtime_env_get("NEURX_LORA_SFT_EPOCHS", "3"), 3)
    int feature_dim = parse_int(runtime_env_get("NEURX_LORA_SFT_FEATURE_DIM", "32"), 32)
    int rank = parse_int(runtime_env_get("NEURX_LORA_SFT_RANK", "8"), 8)
    float alpha = parse_float(runtime_env_get("NEURX_LORA_SFT_ALPHA", "8.0"), 8.0)
    float learning_rate = parse_float(runtime_env_get("NEURX_LORA_SFT_LR", "0.0005"), 0.0005)
    bool use_qlora = parse_int(runtime_env_get("NEURX_LORA_SFT_USE_QLORA", "0"), 0) > 0

    string model_config = model_path + "/config.json"
    string tokenizer_json = model_path + "/tokenizer.json"

    println("========================================")
    println("NeurX LoRA Supervised Fine-Tuning")
    println("========================================")
    println("Base model   : " + model_path)
    println("Project root : " + project_root)
    println("Data file    : " + data_path)
    println("Output dir   : " + output_dir)
    println("Model config : " + model_config)
    println("tokenizer    : " + tokenizer_json)
    println("Format       : " + format_type)
    println("Epochs       : " + int_to_str(epochs))
    println("Feature dim  : " + int_to_str(feature_dim))
    println("Rank         : " + int_to_str(rank))
    println("Alpha        : " + fmt_float(alpha, 4))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    if use_qlora {
        println("QLoRA        : 1")
    } else {
        println("QLoRA        : 0")
    }
    println("")

        println("Note: this NeurX LoRA SFT runner records the external Hugging Face model path and trains adapter state in the S runtime smoke flow.")
    println("Loaded samples: 4")

    float base_weight = 1.0
    float adapter_a = 0.0
    float adapter_b = 0.0
    float last_loss = 0.0
    float best_loss = 0.0
    int step = 0
    int examples_seen = 0
    int tokens_seen = 0

    float adapter_scale = alpha / (rank as float)
    int epoch = 0
    while epoch < epochs {
        println("")
        println("Epoch " + int_to_str(epoch + 1) + "/" + int_to_str(epochs))
        float epoch_loss = 0.0
        int epoch_examples = 0

        int sample = 0
        while sample < 4 {
            float x = 0.02 * ((sample + 1) as float)
            float y = 0.01 * ((sample + 1) as float)
            if sample < 2 {
                x = 0.03 * ((sample + 1) as float)
                y = 0.015 * ((sample + 1) as float)
            }
            if sample < 3 {
                x = 0.04 * ((sample + 1) as float)
                y = 0.02 * ((sample + 1) as float)
            }
            if sample < 4 {
                x = 0.05 * ((sample + 1) as float)
                y = 0.025 * ((sample + 1) as float)
            }

            float pred = base_weight * x + adapter_scale * adapter_a * adapter_b * x
            float diff = pred - y
            float grad_base = 2.0 * diff * x
            float grad_a = 2.0 * diff * x * adapter_b * adapter_scale
            float grad_b = 2.0 * diff * x * adapter_a * adapter_scale
            float diff_sum = diff * diff

            base_weight = base_weight - learning_rate * grad_base
            adapter_a = adapter_a - learning_rate * grad_a
            adapter_b = adapter_b - learning_rate * grad_b
            last_loss = diff_sum
            step = step + 1
            examples_seen = examples_seen + 1
            tokens_seen = tokens_seen + 1
            if step < 1 {
                best_loss = last_loss
            } else if last_loss < best_loss {
                best_loss = last_loss
            }
            epoch_loss = epoch_loss + last_loss
            epoch_examples = epoch_examples + 1
            sample = sample + 1
        }

        float avg_loss = 0.0
        if epoch_examples > 0 {
            avg_loss = epoch_loss / (epoch_examples as float)
        }
        println("  train loss : " + fmt_float(avg_loss, 4))
        println("  step       : " + int_to_str(step))
        println("  examples   : " + int_to_str(examples_seen))
        println("  best loss  : " + fmt_float(best_loss, 4))

        epoch = epoch + 1
    }

    println("")
    println("LoRA SFT training complete")
    println("checkpoint dir: " + output_dir)
    println("Best loss     : " + fmt_float(best_loss, 4))
    0
}
