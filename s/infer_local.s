package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}

struct tensor {
    []float data
    int size
}

struct checkpoint_header {
    int step
    float loss
    int param_count
    int weight_rows
    int weight_cols
    int bias_size
}

func mod(int a, int b) int {
    if b == 0 {
        return 0
    }
    a - (a / b) * b
}

func float(int x) float {
    0.0 + x
}

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
        s = string(mod(n, 10) + 48) + s
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

func substring(string s, int start, int end) string {
    string out = ""
    int i = start
    while i < end {
        out = out + string(s[i])
        i = i + 1
    }
    out
}

func trim(string s) string {
    int begin = 0
    while begin < len(s) {
        string ch = string(s[begin])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            begin = begin + 1
        } else {
            break
        }
    }

    int finish = len(s)
    while finish > begin {
        string ch = string(s[finish - 1])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            finish = finish - 1
        } else {
            break
        }
    }
    substring(s, begin, finish)
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    while i < len(s) {
        string ch = string(s[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}

func digit_value(string ch) int {
    if ch == "0" {
        return 0
    }
    if ch == "1" {
        return 1
    }
    if ch == "2" {
        return 2
    }
    if ch == "3" {
        return 3
    }
    if ch == "4" {
        return 4
    }
    if ch == "5" {
        return 5
    }
    if ch == "6" {
        return 6
    }
    if ch == "7" {
        return 7
    }
    if ch == "8" {
        return 8
    }
    if ch == "9" {
        return 9
    }
    -1
}

func parse_int_str(string s) int {
    string text = trim(s)
    if text == "" {
        return 0
    }
    int sign = 1
    int i = 0
    if string(text[0]) == "-" {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        int digit = digit_value(string(text[i]))
        if digit < 0 {
            return 0
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func parse_float_str(string s) float {
    string text = trim(s)
    if text == "" {
        return 0.0
    }
    bool neg = false
    int i = 0
    if string(text[0]) == "-" {
        neg = true
        i = 1
    }
    float whole = 0.0
    while i < len(text) && string(text[i]) != "." {
        int digit = digit_value(string(text[i]))
        if digit < 0 {
            return 0.0
        }
        whole = whole * 10.0 + float(digit)
        i = i + 1
    }
    float frac = 0.0
    float scale = 1.0
    if i < len(text) && string(text[i]) == "." {
        i = i + 1
        while i < len(text) {
            int digit = digit_value(string(text[i]))
            if digit < 0 {
                return 0.0
            }
            scale = scale * 10.0
            frac = frac + float(digit) / scale
            i = i + 1
        }
    }
    float out = whole + frac
    if neg {
        out = -out
    }
    out
}

func parse_pair_left(string text) int {
    string trimmed = trim(text)
    int comma = -1
    int i = 0
    while i < len(trimmed) {
        if string(trimmed[i]) == "," {
            comma = i
            i = len(trimmed)
        }
        i = i + 1
    }
    if comma < 0 {
        return parse_int_str(trimmed)
    }
    parse_int_str(substring(trimmed, 0, comma))
}

func parse_pair_right(string text) int {
    string trimmed = trim(text)
    int comma = -1
    int i = 0
    while i < len(trimmed) {
        if string(trimmed[i]) == "," {
            comma = i
            i = len(trimmed)
        }
        i = i + 1
    }
    if comma < 0 {
        return 0
    }
    parse_int_str(substring(trimmed, comma + 1, len(trimmed)))
}

func parse_csv_floats_fixed(string text, int expected_count) tensor {
    []float data = []float{cap: expected_count}
    string current = ""
    int i = 0
    int out_i = 0
    while i < len(text) && out_i < expected_count {
        string ch = string(text[i])
        if ch == "," {
            data[out_i] = parse_float_str(current)
            out_i = out_i + 1
            current = ""
        } else {
            current = current + ch
        }
        i = i + 1
    }
    if out_i < expected_count {
        data[out_i] = parse_float_str(current)
        out_i = out_i + 1
    }
    tensor { data: data, size: out_i }
}

func read_line_command(string checkpoint_path, string line_no) string {
    trim(runtime_run_command_output("sed -n '" + line_no + "p' " + shell_escape(checkpoint_path)))
}

func load_checkpoint_header_from_file(string checkpoint_path) checkpoint_header {
    string step_line = read_line_command(checkpoint_path, "2")
    string loss_line = read_line_command(checkpoint_path, "3")
    string count_line = read_line_command(checkpoint_path, "4")
    string weight_shape_line = read_line_command(checkpoint_path, "6")
    string bias_shape_line = read_line_command(checkpoint_path, "9")

    string weight_shape = substring(weight_shape_line, 13, len(weight_shape_line))
    int weight_rows = parse_pair_left(weight_shape)
    int weight_cols = parse_pair_right(weight_shape)
    int bias_size = parse_int_str(substring(bias_shape_line, 13, len(bias_shape_line)))

    checkpoint_header {
        step: parse_int_str(substring(step_line, 5, len(step_line))),
        loss: parse_float_str(substring(loss_line, 5, len(loss_line))),
        param_count: parse_int_str(substring(count_line, 12, len(count_line))),
        weight_rows: weight_rows,
        weight_cols: weight_cols,
        bias_size: bias_size,
    }
}

func load_bias_from_file(string checkpoint_path, int bias_size) tensor {
    string line = read_line_command(checkpoint_path, "10")
    parse_csv_floats_fixed(substring(line, 12, len(line)), bias_size)
}

func load_weight_row_from_file(string checkpoint_path, int row_id, int vocab_size) tensor {
    int start_index = row_id * vocab_size + 1
    int end_index = start_index + vocab_size - 1
    string field_range = int_to_str(start_index) + "-" + int_to_str(end_index)
    string command = "awk -F= '/^param0.data=/{print $2}' " + shell_escape(checkpoint_path) + " | cut -d',' -f" + field_range
    parse_csv_floats_fixed(trim(runtime_run_command_output(command)), vocab_size)
}

func ascii_code(string text, int idx) int {
    string ch = string(text[idx])
    if ch == " " {
        return 32
    }
    if ch == "a" {
        return 97
    }
    if ch == "b" {
        return 98
    }
    if ch == "c" {
        return 99
    }
    if ch == "d" {
        return 100
    }
    if ch == "e" {
        return 101
    }
    if ch == "f" {
        return 102
    }
    if ch == "g" {
        return 103
    }
    if ch == "h" {
        return 104
    }
    if ch == "i" {
        return 105
    }
    if ch == "j" {
        return 106
    }
    if ch == "k" {
        return 107
    }
    if ch == "l" {
        return 108
    }
    if ch == "m" {
        return 109
    }
    if ch == "n" {
        return 110
    }
    if ch == "o" {
        return 111
    }
    if ch == "p" {
        return 112
    }
    if ch == "q" {
        return 113
    }
    if ch == "r" {
        return 114
    }
    if ch == "s" {
        return 115
    }
    if ch == "t" {
        return 116
    }
    if ch == "u" {
        return 117
    }
    if ch == "v" {
        return 118
    }
    if ch == "w" {
        return 119
    }
    if ch == "x" {
        return 120
    }
    if ch == "y" {
        return 121
    }
    if ch == "z" {
        return 122
    }
    32
}

func argmax_next_token(tensor weight_row, tensor bias, int vocab_size) int {
    float best_logit = weight_row.data[0] + bias.data[0]
    int best_id = 0
    int c = 1
    while c < vocab_size {
        float logit = weight_row.data[c] + bias.data[c]
        if logit > best_logit {
            best_logit = logit
            best_id = c
        }
        c = c + 1
    }
    best_id
}

func generate_text_from_checkpoint(string checkpoint_path, int vocab_size, tensor bias, string seed, int max_new_chars) string {
    string output = seed
    int current_id = 32
    if len(seed) > 0 {
        current_id = mod(ascii_code(seed, len(seed) - 1), vocab_size)
    }

    int n = 0
    while n < max_new_chars {
        tensor weight_row = load_weight_row_from_file(checkpoint_path, current_id, vocab_size)
        if weight_row.size < vocab_size {
            return output
        }
        int next_id = argmax_next_token(weight_row, bias, vocab_size)
        output = output + string(next_id)
        current_id = next_id
        n = n + 1
    }
    output
}

func main() {
    string checkpoint_path = runtime_env_get("NEURX_INFER_CHECKPOINT_PATH", "artifacts/checkpoints/llm_s_pretrain/final_model.neurx")
    string validate_only = runtime_env_get("NEURX_INFER_VALIDATE_ONLY", "")

    if !runtime_file_exists(checkpoint_path) {
        println("Checkpoint file not found: " + checkpoint_path)
        return
    }

    checkpoint_header header = load_checkpoint_header_from_file(checkpoint_path)

    if validate_only == "1" {
        println("================================================")
        println("NeurX checkpoint validation")
        println("================================================")
        println("Checkpoint path: " + checkpoint_path)
        println("Step: " + int_to_str(header.step))
        println("Loss: " + fmt_float(header.loss, 4))
        println("Param count: " + int_to_str(header.param_count))
        println("Weight shape: " + int_to_str(header.weight_rows) + "x" + int_to_str(header.weight_cols))
        println("Bias shape: " + int_to_str(header.bias_size))
        println("================================================")
        return
    }

    tensor bias = load_bias_from_file(checkpoint_path, header.bias_size)
    if bias.size < header.bias_size {
        println("Could not load bias vector from checkpoint: " + checkpoint_path)
        return
    }

    string seed = runtime_env_get("NEURX_INFER_SEED", "neurx ")
    int max_new_chars = parse_int_str(runtime_env_get("NEURX_INFER_MAX_NEW_CHARS", "120"))
    if max_new_chars <= 0 {
        max_new_chars = 120
    }

    println("================================================")
    println("NeurX checkpoint inference")
    println("================================================")
    println("Checkpoint path: " + checkpoint_path)
    println("Step: " + int_to_str(header.step))
    println("Loss: " + fmt_float(header.loss, 4))
    println("Param count: " + int_to_str(header.param_count))
    println("Weight shape: " + int_to_str(header.weight_rows) + "x" + int_to_str(header.weight_cols))
    println("Bias shape: " + int_to_str(header.bias_size))
    println("Seed: " + seed)
    println("Generated:")
    println(generate_text_from_checkpoint(checkpoint_path, header.weight_cols, bias, seed, max_new_chars))
    println("================================================")
}
