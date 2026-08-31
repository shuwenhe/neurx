package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_write_text_file}
use std.io.println
use std.conv.parse_int_default as parse_int

struct sft_state {
    float weight
    float bias
    int step
    int examples_seen
    int tokens_seen
    float last_loss
    float total_loss
    float best_eval_loss
}

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string data_path = runtime_env_get("NEURX_SFT_DATA_FILE", project_root + "/data/sft/instruction_data.jsonl")
    string output_dir = runtime_env_get("NEURX_SFT_OUTPUT_DIR", project_root + "/artifact/checkpoints/sft")
    int epochs = parse_int(runtime_env_get("NEURX_SFT_EPOCHS", "3"), 3)
    int batch_size = parse_int(runtime_env_get("NEURX_SFT_BATCH_SIZE", "4"), 4)
    float learning_rate = parse_float(runtime_env_get("NEURX_SFT_LR", "0.001"))
    println("========================================")
    println("NeurX Supervised Fine-Tuning (S Lang)")
    println("========================================")
    println("Project root : " + project_root)
    println("Data file    : " + check_path(data_path))
    println("Output dir   : " + output_dir)
    println("Epochs       : " + int_to_str(epochs))
    println("batch_2 size   : " + int_to_str(batch_size))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    println("")
    runtime_command_result mkdir_result = runtime_make_dirs(output_dir)
    if !mkdir_result.ok {
        println("Failed to create output dir: " + output_dir)
        return 1
    }
    string[] samples = load_sft_samples(data_path)
    if len(samples) == 0 {
        samples = builtin_sft_samples()
    }
    println("Loaded samples: " + int_to_str(len(samples)))
    sft_state state = sft_state {
        weight: 0.01,
        bias: 0.0,
        step: 0,
        examples_seen: 0,
        tokens_seen: 0,
        last_loss: 0.0,
        total_loss: 0.0,
        best_eval_loss: 999999.0,
    }
    int epoch = 0
    for epoch < epochs {
        println("")
        println("Epoch " + int_to_str(epoch + 1) + "/" + int_to_str(epochs))
        int sample_index = 0
        float epoch_loss = 0.0
        int epoch_examples = 0
        for sample_index < len(samples) {
            int batch_end = sample_index + batch_size
            if batch_end > len(samples) {
                batch_end = len(samples)
            }
            int item = sample_index
            for item < batch_end {
                string formatted = samples[item]
                int pos = 0
                float sample_loss = 0.0
                int pair_count = 0
                for pos + 1 < str_len(formatted) {
                    int prev_token = formatted[pos]
                    int next_token = formatted[pos + 1]
                    float x = (prev_token as float) / 255.0
                    float y = (next_token as float) / 255.0
                    float pred = state.weight * x + state.bias
                    float diff = pred - y
                    sample_loss = sample_loss + diff * diff
                    state.weight = state.weight - learning_rate * diff * x
                    state.bias = state.bias - learning_rate * diff
                    state.step = state.step + 1
                    state.tokens_seen = state.tokens_seen + 1
                    pair_count = pair_count + 1
                    pos = pos + 1
                }
                if pair_count > 0 {
                    state.last_loss = sample_loss / (pair_count as float)
                    state.total_loss = state.total_loss + state.last_loss
                } else {
                    state.last_loss = 0.0
                }
                state.examples_seen = state.examples_seen + 1
                epoch_loss = epoch_loss + state.last_loss
                epoch_examples = epoch_examples + 1
                item = item + 1
            }
            sample_index = batch_end
        }
        float eval_loss = 0.0
        int eval_valid = 0
        int eval_i = 0
        for eval_i < len(samples) {
            string eval_text = samples[eval_i]
            if str_len(eval_text) >= 2 {
                int eval_pos = 0
                float eval_sample_loss = 0.0
                int eval_pairs = 0
                for eval_pos + 1 < str_len(eval_text) {
                    int prev_token = eval_text[eval_pos]
                    int next_token = eval_text[eval_pos + 1]
                    float x = (prev_token as float) / 255.0
                    float y = (next_token as float) / 255.0
                    float pred = state.weight * x + state.bias
                    float diff = pred - y
                    eval_sample_loss = eval_sample_loss + diff * diff
                    eval_pairs = eval_pairs + 1
                    eval_pos = eval_pos + 1
                }
                if eval_pairs > 0 {
                    eval_loss = eval_loss + eval_sample_loss / (eval_pairs as float)
                    eval_valid = eval_valid + 1
                }
            }
            eval_i = eval_i + 1
        }
        if eval_valid > 0 {
            eval_loss = eval_loss / (eval_valid as float)
        }
        if eval_loss < state.best_eval_loss {
            state.best_eval_loss = eval_loss
        }
        float avg_train_loss = 0.0
        if epoch_examples > 0 {
            avg_train_loss = epoch_loss / (epoch_examples as float)
        }
        println("  train loss : " + fmt_float(avg_train_loss, 4))
        println("  eval loss  : " + fmt_float(eval_loss, 4))
        println("  weight     : " + fmt_float(state.weight, 6))
        println("  bias       : " + fmt_float(state.bias, 6))
        println("  examples   : " + int_to_str(state.examples_seen))
        println("  tokens     : " + int_to_str(state.tokens_seen))
        string checkpoint_path = output_dir + "/sft_checkpoint_epoch_" + int_to_str(epoch + 1) + ".txt"
        runtime_write_text_file(
            checkpoint_path,
            "NeurX SFT checkpoint\n" +
            "path=" + checkpoint_path + "\n" +
            "data_path=" + data_path + "\n" +
            "samples=" + int_to_str(len(samples)) + "\n" +
            "epochs=" + int_to_str(epochs) + "\n" +
            "learning_rate=" + fmt_float(learning_rate, 6) + "\n" +
            "step=" + int_to_str(state.step) + "\n" +
            "examples_seen=" + int_to_str(state.examples_seen) + "\n" +
            "tokens_seen=" + int_to_str(state.tokens_seen) + "\n" +
            "weight=" + fmt_float(state.weight, 8) + "\n" +
            "bias=" + fmt_float(state.bias, 8) + "\n" +
            "last_loss=" + fmt_float(state.last_loss, 6) + "\n" +
            "best_eval_loss=" + fmt_float(state.best_eval_loss, 6) + "\n"
        )
        epoch = epoch + 1
    }
    string latest_checkpoint = output_dir + "/sft_latest.txt"
    runtime_write_text_file(
        latest_checkpoint,
        "NeurX SFT Summary\n" +
        "data_path=" + data_path + "\n" +
        "samples=" + int_to_str(len(samples)) + "\n" +
        "epochs=" + int_to_str(epochs) + "\n" +
        "learning_rate=" + fmt_float(learning_rate, 6) + "\n" +
        "step=" + int_to_str(state.step) + "\n" +
        "examples_seen=" + int_to_str(state.examples_seen) + "\n" +
        "tokens_seen=" + int_to_str(state.tokens_seen) + "\n" +
        "weight=" + fmt_float(state.weight, 8) + "\n" +
        "bias=" + fmt_float(state.bias, 8) + "\n" +
        "last_loss=" + fmt_float(state.last_loss, 6) + "\n" +
        "best_eval_loss=" + fmt_float(state.best_eval_loss, 6) + "\n"
    )
    runtime_write_text_file(
        output_dir + "/sft_manifest.txt",
        "latest_checkpoint=" + latest_checkpoint + "\n" +
        "data_path=" + data_path + "\n" +
        "examples_seen=" + int_to_str(state.examples_seen) + "\n" +
        "tokens_seen=" + int_to_str(state.tokens_seen) + "\n"
    )
    println("")
    println("SFT training complete")
    println("Latest checkpoint: " + latest_checkpoint)
    println("Best eval loss    : " + fmt_float(state.best_eval_loss, 4))
    0
}

func builtin_sft_samples() []string {
    string[] samples = make([]string, 4)
    samples[0] = format_sft_text("Explain gradient descent", "", "Gradient descent updates parameters by following the negative loss gradient.")
    samples[1] = format_sft_text("Write a short apology", "late delivery", "Sorry for the late delivery. I will fix it immediately.")
    samples[2] = format_sft_text("Summarize the task", "train a model", "The task is to train a model on the given data.")
    samples[3] = format_sft_text("Answer politely", "Can you help me", "Yes, I can help you with that.")
    samples
}

func load_sft_samples(string data_path) []string {
    if !runtime_file_exists(data_path) {
        string[] empty = []string{}
        return empty
    }
    println("SFT data file detected; using built-in sample set in this minimal S implementation.")
    builtin_sft_samples()
}

func format_sft_text(string instruction, string input_text, string output_text) string {
    string out = "### Instruction:\n" + instruction
    if str_len(input_text) > 0 {
        out = out + "\n\n### Input:\n" + input_text
    }
    out = out + "\n\n### Response:\n" + output_text
    out
}

func trim(string s) string {
    int start = 0
    for start < str_len(s) && is_space(s[start]) {
        start = start + 1
    }
    int end = str_len(s) - 1
    for end >= start && is_space(s[end]) {
        end = end - 1
    }
    if end < start {
        return ""
    }
    substring(s, start, end + 1)
}

func is_space(int c) bool {
    c == 32 || c == 9 || c == 10 || c == 13
}

func substring(string s, int start, int end) string {
    if start < 0 {
        start = 0
    }
    if end > str_len(s) {
        end = str_len(s)
    }
    if end <= start {
        return ""
    }
    string out = ""
    int i = start
    for i < end {
        out = out + string(s[i])
        i = i + 1
    }
    out
}

func str_len(string s) int {
    int n = 0
    for n < len(s) {
        n = n + 1
    }
    n
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
    for value > 0 {
        int digit = value
        int q = 0
        for digit >= 10 {
            digit = digit - 10
            q = q + 1
        }
        out = string(digit + 48) + out
        value = q
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
    for value >= 1.0 {
        value = value - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    for i < decimals {
        value = value * 10.0
        int digit = 0
        for value >= 1.0 {
            value = value - 1.0
            digit = digit + 1
        }
        out = out + string(digit + 48)
        i = i + 1
    }
    out
}

func parse_float(string s) float {
    string text = trim(s)
    if str_len(text) == 0 {
        return 0.0
    }
    bool neg = false
    int i = 0
    if text[0] == 45 {
        neg = true
        i = 1
    }
    float whole = 0.0
    for i < str_len(text) && text[i] >= 48 && text[i] <= 57 {
        whole = whole * 10.0 + ((text[i] - 48) as float)
        i = i + 1
    }
    float frac = 0.0
    float scale = 1.0
    if i < str_len(text) && text[i] == 46 {
        i = i + 1
        for i < str_len(text) && text[i] >= 48 && text[i] <= 57 {
            frac = frac * 10.0 + ((text[i] - 48) as float)
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

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    "missing (" + path + ")"
}
