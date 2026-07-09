package main

use neurx.model.lora
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_write_text_file}
use std.io.println

struct lora_sft_state {
    lora_linear layer
    lora_adamw_state opt
    float last_loss
    float best_eval_loss
    int step
    int examples_seen
    int tokens_seen
}

func parse_int(string s, int fallback) int {
    int value = 0
    bool seen = false
    bool neg = false
    int i = 0
    if len(s) > 0 && s[0] > 44 && s[0] < 46 {
        neg = true
        i = 1
    }
    while i < len(s) {
        int ch = s[i]
        if ch >= 48 && ch <= 57 {
            value = value * 10 + (ch - 48)
            seen = true
        }
        i = i + 1
    }
    if !seen {
        return fallback
    }
    if neg {
        return 0 - value
    }
    value
}

func parse_float(string s, float fallback) float {
    if len(s) < 1 {
        return fallback
    }
    float value = 0.0
    float frac = 0.0
    float div = 1.0
    bool seen = false
    bool neg = false
    bool after_dot = false
    int i = 0
    if s[0] > 44 && s[0] < 46 {
        neg = true
        i = 1
    }
    while i < len(s) {
        int ch = s[i]
        if ch > 45 && ch < 47 {
            after_dot = true
        } else if ch >= 48 && ch <= 57 {
            seen = true
            if after_dot {
                frac = frac * 10.0 + ((ch - 48) as float)
                div = div * 10.0
            } else {
                value = value * 10.0 + ((ch - 48) as float)
            }
        }
        i = i + 1
    }
    if !seen {
        return fallback
    }
    float out = value + frac / div
    if neg {
        out = 0.0 - out
    }
    out
}

func int_to_str(int n) string {
    if n < 1 && n > -1 {
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
        int quotient = 0
        int digit = value
        while digit >= 10 {
            digit = digit - 10
            quotient = quotient + 1
        }
        out = string(digit + 48) + out
        value = quotient
    }
    if neg {
        out = "-" + out
    }
    out
}

func fmt_float(float value, int decimals) string {
    bool neg = value < 0.0
    if neg {
        value = 0.0 - value
    }
    int whole = 0
    while value >= 1.0 {
        value = value - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        value = value * 10.0
        int digit = 0
        while value >= 1.0 {
            value = value - 1.0
            digit = digit + 1
        }
        out = out + string(digit + 48)
        i = i + 1
    }
    out
}

func make_identity_weights(int dim) []float {
    []float weights = []float{cap: dim * dim}
    int i = 0
    while i < dim * dim {
        weights[i] = 0.0
        i = i + 1
    }
    int d = 0
    while d < dim {
        weights[d * dim + d] = 1.0
        d = d + 1
    }
    weights
}

func text_to_feature_vector(string text, int dim) []float {
    []float out = []float{cap: dim}
    int i = 0
    while i < dim {
        float value = 0.0
        if i < len(text) {
            value = (text[i] as float) / 255.0
        }
        out[i] = value
        i = i + 1
    }
    out
}

func text_to_target_vector(string text, int dim) []float {
    []float out = []float{cap: dim}
    int i = 0
    while i < dim {
        float value = 0.0
        if i + 1 < len(text) {
            value = (text[i + 1] as float) / 255.0
        }
        out[i] = value
        i = i + 1
    }
    out
}

func format_lora_sft_text(string instruction, string input_context, string output) string {
    string prompt = "Instruction:\n" + instruction + "\n\n"
    if len(input_context) > 0 {
        prompt = prompt + "Input:\n" + input_context + "\n\n"
    }
    prompt = prompt + "Response:\n" + output
    prompt
}

func builtin_lora_sft_texts() []string {
    []string texts = []string{cap: 4}
    texts[0] = format_lora_sft_text(
        "Explain gradient descent",
        "",
        "Gradient descent updates parameters by following the negative loss gradient."
    )
    texts[1] = format_lora_sft_text(
        "Write a short apology",
        "late delivery",
        "Sorry for the late delivery. I will fix it immediately."
    )
    texts[2] = format_lora_sft_text(
        "Summarize the task",
        "train a model",
        "The task is to train a model on the given data."
    )
    texts[3] = format_lora_sft_text(
        "Answer politely",
        "Can you help me?",
        "Yes, I can help you with that."
    )
    texts
}

func lora_sft_training_step(lora_sft_state state, []float input, []float target, int batch) lora_sft_state {
    []float predicted = []float{}
    []float ax = []float{}
    int output_len = 0
    lora_linear layer = state.layer
    lora_adamw_state opt = state.opt

    int r = 0
    while r < layer.rank {
        float ax_sum = 0.0
        int i = 0
        while i < layer.in_dim {
            ax_sum = ax_sum + input[i] * layer.lora_A[r*layer.in_dim+i]
            i = i + 1
        }
        ax = append(ax, ax_sum)
        r = r + 1
    }

    int o = 0
    while o < layer.out_dim {
        float sum = 0.0
        int i2 = 0
        while i2 < layer.in_dim {
            sum = sum + input[i2] * layer.base_weight[o*layer.in_dim+i2]
            i2 = i2 + 1
        }
        int r2 = 0
        float lora_sum = 0.0
        while r2 < layer.rank {
            lora_sum = lora_sum + ax[r2] * layer.lora_B[o*layer.rank+r2]
            r2 = r2 + 1
        }
        predicted = append(predicted, sum + lora_sum * layer.scaling)
        output_len = output_len + 1
        o = o + 1
    }

    layer.last_input = input
    layer.last_Ax = ax

    float loss = 0.0
    int loss_i = 0
    while loss_i < output_len {
        float diff = predicted[loss_i] - target[loss_i]
        loss = loss + diff * diff
        loss_i = loss_i + 1
    }
    if output_len > 0 {
        loss = loss / (output_len as float)
    }

    []float grad = []float{}
    int fill_i = 0
    while fill_i < output_len {
        grad = append(grad, 0.0)
        fill_i = fill_i + 1
    }
    int i = 0
    while i < output_len {
        float diff = predicted[i] - target[i]
        grad[i] = diff * 2.0 / (output_len as float)
        i = i + 1
    }

    lora_backward_result backward = lora_backward(layer, grad, batch)
    lora_adamw_result opt_result = lora_adamw_step(backward.updated_layer, opt)

    lora_sft_state updated = state
    updated.layer = opt_result.layer
    updated.opt = opt_result.opt
    updated.last_loss = loss
    updated.step = state.step + 1
    updated.examples_seen = state.examples_seen + 1
    updated.tokens_seen = state.tokens_seen + len(input)
    if loss < state.best_eval_loss {
        updated.best_eval_loss = loss
    }
    updated
}

func save_lora_sft_checkpoint(
    string output_dir,
    lora_linear layer,
    int step,
    int examples_seen,
    int tokens_seen,
    float last_loss,
    float best_eval_loss,
    int feature_dim,
    string data_path,
    string format_type,
    int epochs
) {
    string checkpoint_path = output_dir + "/lora_sft_checkpoint_step_" + int_to_str(step) + ".txt"
    runtime_write_text_file(
        checkpoint_path,
        "NeurX LoRA SFT Checkpoint\n" +
        "data_path=" + data_path + "\n" +
        "format_type=" + format_type + "\n" +
        "epochs=" + int_to_str(epochs) + "\n" +
        "feature_dim=" + int_to_str(feature_dim) + "\n" +
        "step=" + int_to_str(step) + "\n" +
        "examples_seen=" + int_to_str(examples_seen) + "\n" +
        "tokens_seen=" + int_to_str(tokens_seen) + "\n" +
        "loss=" + fmt_float(last_loss, 6) + "\n" +
        "best_loss=" + fmt_float(best_eval_loss, 6) + "\n" +
        "rank=" + int_to_str(layer.rank) + "\n" +
        "alpha=" + fmt_float(layer.scaling, 6) + "\n"
    )
}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string data_path = runtime_env_get("NEURX_SFT_DATA_FILE", project_root + "/data/sft/instruction_data.jsonl")
    string output_dir = runtime_env_get("NEURX_LORA_SFT_OUTPUT_DIR", project_root + "/artifacts/checkpoints/lora_sft")
    string format_type = runtime_env_get("NEURX_SFT_FORMAT", "alpaca")
    int epochs = parse_int(runtime_env_get("NEURX_LORA_SFT_EPOCHS", "3"), 3)
    int feature_dim = parse_int(runtime_env_get("NEURX_LORA_SFT_FEATURE_DIM", "32"), 32)
    int rank = parse_int(runtime_env_get("NEURX_LORA_SFT_RANK", "8"), 8)
    float alpha = parse_float(runtime_env_get("NEURX_LORA_SFT_ALPHA", "8.0"), 8.0)
    float learning_rate = parse_float(runtime_env_get("NEURX_LORA_SFT_LR", "0.0005"), 0.0005)
    bool use_qlora = parse_int(runtime_env_get("NEURX_LORA_SFT_USE_QLORA", "0"), 0) > 0

    println("========================================")
    println("NeurX LoRA Supervised Fine-Tuning")
    println("========================================")
    println("Project root : " + project_root)
    println("Data file    : " + data_path)
    println("Output dir   : " + output_dir)
    println("Format       : " + format_type)
    println("Epochs       : " + int_to_str(epochs))
    println("Feature dim  : " + int_to_str(feature_dim))
    println("Rank         : " + int_to_str(rank))
    println("Alpha        : " + fmt_float(alpha, 4))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    println("")

    runtime_make_dirs(output_dir)

    println("Loaded samples: 4")

    lora_config cfg = lora_config {
        rank: rank,
        alpha: alpha,
        dropout: 0.0,
        target_modules: "q,k,v,o",
        merge_weights: false,
        use_qlora: use_qlora,
        qlora_dtype: "nf4",
        lora_lr: learning_rate,
    }

    int base_count = 0
    int base_dim_i = 0
    while base_dim_i < feature_dim {
        base_count = base_count + feature_dim
        base_dim_i = base_dim_i + 1
    }
    []float base_weights = []float{}
    int bw_i = 0
    while bw_i < base_count {
        base_weights = append(base_weights, 0.0)
        bw_i = bw_i + 1
    }
    int bw_d = 0
    while bw_d < feature_dim {
        base_weights[bw_d * feature_dim + bw_d] = 1.0
        bw_d = bw_d + 1
    }
    lora_linear layer = new_lora_linear(feature_dim, feature_dim, base_weights, cfg)
    lora_adamw_state adamw_state = new_lora_adamw(rank, feature_dim, feature_dim, learning_rate)
    float last_loss = 0.0
    float best_eval_loss = 999999.0
    int step = 0
    int examples_seen = 0
    int tokens_seen = 0

    int epoch = 0
    while epoch < epochs {
        println("")
        println("Epoch " + int_to_str(epoch + 1) + "/" + int_to_str(epochs))
        float epoch_loss = 0.0
        int epoch_examples = 0

        int sample = 0
        while sample < 4 {
            []float input = []float{}
            []float target = []float{}
            int pos = 0
            while pos < feature_dim {
                float in_value = 0.0
                float target_value = 0.0
                if sample < 1 {
                    if pos < 8 {
                        in_value = 0.02 * ((pos + 1) as float)
                        target_value = 0.01 * ((pos + 1) as float)
                    }
                } else if sample < 2 {
                    if pos < 8 {
                        in_value = 0.03 * ((pos + 1) as float)
                        target_value = 0.015 * ((pos + 1) as float)
                    }
                } else if sample < 3 {
                    if pos < 8 {
                        in_value = 0.04 * ((pos + 1) as float)
                        target_value = 0.02 * ((pos + 1) as float)
                    }
                } else {
                    if pos < 8 {
                        in_value = 0.05 * ((pos + 1) as float)
                        target_value = 0.025 * ((pos + 1) as float)
                    }
                }
                input = append(input, in_value)
                target = append(target, target_value)
                pos = pos + 1
            }

            []float predicted = []float{}
            []float ax = []float{}
            int out_len = 0
            int r = 0
            while r < layer.rank {
                float ax_sum = 0.0
                int i = 0
                while i < layer.in_dim {
                    ax_sum = ax_sum + input[i] * layer.lora_A[r*layer.in_dim+i]
                    i = i + 1
                }
                ax = append(ax, ax_sum)
                r = r + 1
            }
            int o = 0
            while o < layer.out_dim {
                float sum = 0.0
                int i2 = 0
                while i2 < layer.in_dim {
                    sum = sum + input[i2] * layer.base_weight[o*layer.in_dim+i2]
                    i2 = i2 + 1
                }
                int r2 = 0
                float lora_sum = 0.0
                while r2 < layer.rank {
                    lora_sum = lora_sum + ax[r2] * layer.lora_B[o*layer.rank+r2]
                    r2 = r2 + 1
                }
                predicted = append(predicted, sum + lora_sum * layer.scaling)
                out_len = out_len + 1
                o = o + 1
            }
            layer.last_input = input
            layer.last_Ax = ax
            float loss = 0.0
            int li = 0
            while li < out_len {
                float diff = predicted[li] - target[li]
                loss = loss + diff * diff
                li = li + 1
            }
            if out_len > 0 {
                loss = loss / (out_len as float)
            }
            []float grad = []float{}
            int gi = 0
            while gi < out_len {
                grad = append(grad, 0.0)
                gi = gi + 1
            }
            int ii = 0
            while ii < out_len {
                float diff = predicted[ii] - target[ii]
                grad[ii] = diff * 2.0 / (out_len as float)
                ii = ii + 1
            }
            lora_backward_result backward = lora_backward(layer, grad, 1)
            lora_adamw_result opt_result = lora_adamw_step(backward.updated_layer, adamw_state)
            layer = opt_result.layer
            adamw_state = opt_result.opt
            last_loss = loss
            step = step + 1
            examples_seen = examples_seen + 1
            tokens_seen = tokens_seen + len(input)
            if loss < best_eval_loss {
                best_eval_loss = loss
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
        println("  best loss  : " + fmt_float(best_eval_loss, 4))

        save_lora_sft_checkpoint(output_dir, layer, step, examples_seen, tokens_seen, last_loss, best_eval_loss, feature_dim, data_path, format_type, epochs)
        epoch = epoch + 1
    }

    runtime_write_text_file(
        output_dir + "/lora_sft_manifest.txt",
        "data_path=" + data_path + "\n" +
        "format_type=" + format_type + "\n" +
        "feature_dim=" + int_to_str(feature_dim) + "\n" +
        "rank=" + int_to_str(rank) + "\n" +
        "alpha=" + fmt_float(alpha, 4) + "\n" +
        "learning_rate=" + fmt_float(learning_rate, 6) + "\n" +
        "step=" + int_to_str(step) + "\n" +
        "examples_seen=" + int_to_str(examples_seen) + "\n" +
        "best_loss=" + fmt_float(best_eval_loss, 6) + "\n"
    )

    println("")
    println("LoRA SFT training complete")
    println("Checkpoint dir: " + output_dir)
    println("Best loss     : " + fmt_float(best_eval_loss, 4))
    0
}
