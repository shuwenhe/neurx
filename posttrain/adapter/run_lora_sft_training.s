package main

use std.io.println

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
        int digit = value - (value / 10) * 10
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

    string project_root = "/home/shuwen/shuwen/train/neurx"
    string model_path = "/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct"
    string data_path = "/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl"
    string output_dir = "/home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft"
    string format_type = "sft"
    int epochs = 3
    int feature_dim = 32
    int rank = 8
    float alpha = 16.0
    float learning_rate = 0.0005
    bool use_qlora = false

    string model_config = model_path + "/config.json"
    string tokenizer_json = model_path + "/tokenizer.json"

    println("========================================")
    println("NeurX LoRA Supervised Fine-Tuning")
    println("========================================")
    println("Base model   : Qwen2.5-0.5B-Instruct")
    println("Project root : " + project_root)
    println("Data file    : " + data_path)
    println("Output dir   : " + output_dir)
    println("Format       : " + format_type)
    println("Epochs       : 3")
    println("Feature dim  : 32")
    println("Rank         : 8")
    println("Alpha        : 16.0000")
    println("Learning rate: 0.000500")
    if use_qlora {
        println("QLoRA        : 1")
    } else {
        println("QLoRA        : 0")
    }
    println("")
    println("Note: This is a simplified LoRA SFT trainer running in S language runtime")
    println("For production training, integration with PyTorch/HuggingFace is recommended")
    println("Loaded samples: 4 (simulation)")
    println("")

    float base_weight = 1.0
    float adapter_a = 0.0
    float adapter_b = 0.0
    float last_loss = 0.0
    float best_loss = 10000.0
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
    println("LoRA SFT training simulation complete")
    println("checkpoint dir: " + output_dir)
    println("Best loss     : " + fmt_float(best_loss, 4))
    println("")

    println("✓ LoRA SFT training completed")

    0
}
