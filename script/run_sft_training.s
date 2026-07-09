package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}
use std.io.println

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

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string data_path = runtime_env_get("NEURX_SFT_DATA_FILE", project_root + "/data/sft/instruction_data.jsonl")
    string output_dir = runtime_env_get("NEURX_SFT_OUTPUT_DIR", project_root + "/artifacts/checkpoints/sft")
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
    println("Batch size   : " + int_to_str(batch_size))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    println("")

    runtime_command_result mkdir_result = runtime_make_dirs(output_dir)
    if !mkdir_result.ok {
        println("Failed to create output dir: " + output_dir)
        return 1
    }

    []string samples = load_sft_samples(data_path)
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
    while epoch < epochs {
        println("")
        println("Epoch " + int_to_str(epoch + 1) + "/" + int_to_str(epochs))

        int sample_index = 0
        float epoch_loss = 0.0
        int epoch_examples = 0

        while sample_index < len(samples) {
            int batch_end = sample_index + batch_size
            if batch_end > len(samples) {
                batch_end = len(samples)
            }

            int item = sample_index
            while item < batch_end {
                string formatted = samples[item]
                int pos = 0
                float sample_loss = 0.0
                int pair_count = 0
                while pos + 1 < str_len(formatted) {
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
        while eval_i < len(samples) {
            string eval_text = samples[eval_i]
            if str_len(eval_text) >= 2 {
                int eval_pos = 0
                float eval_sample_loss = 0.0
                int eval_pairs = 0
                while eval_pos + 1 < str_len(eval_text) {
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
            "NeurX SFT Checkpoint\n" +
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
    []string samples = []string{cap: 4}
    samples[0] = format_sft_text("Explain gradient descent", "", "Gradient descent updates parameters by following the negative loss gradient.")
    samples[1] = format_sft_text("Write a short apology", "late delivery", "Sorry for the late delivery. I will fix it immediately.")
    samples[2] = format_sft_text("Summarize the task", "train a model", "The task is to train a model on the given data.")
    samples[3] = format_sft_text("Answer politely", "Can you help me?", "Yes, I can help you with that.")
    samples
}

func load_sft_samples(string data_path) []string {
    if !runtime_file_exists(data_path) {
        []string empty = []string{cap: 0}
        return empty
    }

    string raw = runtime_read_text_file(data_path)
    []string lines = split_lines(raw)
    []string samples = []string{cap: len(lines)}
    int sample_count = 0
    int i = 0
    while i < len(lines) {
        string line = trim(lines[i])
        if str_len(line) > 0 {
            string sample = parse_sample_line(line)
            if str_len(sample) > 0 {
                samples[sample_count] = sample
                sample_count = sample_count + 1
            }
        }
        i = i + 1
    }

    if sample_count == 0 {
        []string empty = []string{cap: 0}
        return empty
    }

    if sample_count == len(samples) {
        return samples
    }

    []string out = []string{cap: sample_count}
    int j = 0
    while j < sample_count {
        out[j] = samples[j]
        j = j + 1
    }
    out
}

func parse_sample_line(string line) string {
    if find_substring(line, "|||", 0) >= 0 {
        return parse_pipe_sample(line)
    }

    if find_substring(line, "\"instruction\"", 0) >= 0 || find_substring(line, "\"output\"", 0) >= 0 {
        string instruction = extract_json_string_field(line, "instruction")
        string input_text = extract_json_string_field(line, "input")
        string output_text = extract_json_string_field(line, "output")
        if str_len(output_text) == 0 {
            output_text = extract_json_string_field(line, "response")
        }
        return format_sft_text(instruction, input_text, output_text)
    }

    format_sft_text(line, "", line)
}

func parse_pipe_sample(string line) string {
    int first = find_substring(line, "|||", 0)
    int second = find_substring(line, "|||", first + 3)
    if first < 0 {
        return format_sft_text(line, "", line)
    }
    if second < 0 {
        return format_sft_text(trim(substring(line, 0, first)), "", trim(substring(line, first + 3, str_len(line))))
    }
    format_sft_text(trim(substring(line, 0, first)), trim(substring(line, first + 3, second)), trim(substring(line, second + 3, str_len(line))))
}

func format_sft_text(string instruction, string input_text, string output_text) string {
    string out = "### Instruction:\n" + instruction
    if str_len(input_text) > 0 {
        out = out + "\n\n### Input:\n" + input_text
    }
    out = out + "\n\n### Response:\n" + output_text
    out
}

func extract_json_string_field(string line, string key) string {
    string needle = "\"" + key + "\""
    int key_pos = find_substring(line, needle, 0)
    if key_pos < 0 {
        return ""
    }

    int colon_pos = find_substring(line, ":", key_pos + str_len(needle))
    if colon_pos < 0 {
        return ""
    }

    int first_quote = find_substring(line, "\"", colon_pos + 1)
    if first_quote < 0 {
        return ""
    }

    int i = first_quote + 1
    while i < str_len(line) {
        if line[i] == 34 && line[i - 1] != 92 {
            return substring(line, first_quote + 1, i)
        }
        i = i + 1
    }
    ""
}

func split_lines(string text) []string {
    int n = str_len(text)
    if n == 0 {
        []string empty = []string{cap: 0}
        return empty
    }

    []string lines = []string{cap: n}
    string current = ""
    int i = 0
    int count = 0
    while i < n {
        if text[i] == 10 {
            string cleaned = trim(current)
            if str_len(cleaned) > 0 {
                lines[count] = cleaned
                count = count + 1
            }
            current = ""
        } else if text[i] != 13 {
            current = current + string(text[i])
        }
        i = i + 1
    }

    string tail = trim(current)
    if str_len(tail) > 0 {
        lines[count] = tail
        count = count + 1
    }

    if count == 0 {
        []string empty = []string{cap: 0}
        return empty
    }
    if count == len(lines) {
        return lines
    }

    []string out = []string{cap: count}
    int j = 0
    while j < count {
        out[j] = lines[j]
        j = j + 1
    }
    out
}

func find_substring(string s, string pattern, int start) int {
    int limit = str_len(s) - str_len(pattern)
    int i = start
    while i <= limit {
        int j = 0
        bool matched = true
        while j < str_len(pattern) {
            if s[i + j] != pattern[j] {
                matched = false
                j = str_len(pattern)
            }
            j = j + 1
        }
        if matched {
            return i
        }
        i = i + 1
    }
    -1
}

func trim(string s) string {
    int start = 0
    while start < str_len(s) && is_space(s[start]) {
        start = start + 1
    }

    int end = str_len(s) - 1
    while end >= start && is_space(s[end]) {
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
    while i < end {
        out = out + string(s[i])
        i = i + 1
    }
    out
}

func str_len(string s) int {
    int n = 0
    while n < len(s) {
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
    while value > 0 {
        int digit = value
        int q = 0
        while digit >= 10 {
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

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if str_len(text) == 0 {
        return fallback
    }

    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    }

    int value = 0
    while i < str_len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
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
    while i < str_len(text) && text[i] >= 48 && text[i] <= 57 {
        whole = whole * 10.0 + ((text[i] - 48) as float)
        i = i + 1
    }

    float frac = 0.0
    float scale = 1.0
    if i < str_len(text) && text[i] == 46 {
        i = i + 1
        while i < str_len(text) && text[i] >= 48 && text[i] <= 57 {
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
