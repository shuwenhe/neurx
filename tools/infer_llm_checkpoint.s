package neurx.tools.infer
use neurx.runtime.io.{runtime_env_get, runtime_read_text_file, runtime_file_exists, runtime_run_command_output}
func trim(string s) string {
    int i = 0
    while i < len(s) && (string(s[i]) == " " || string(s[i]) == "\t" || string(s[i]) == "\r" || string(s[i]) == "\n") {
        i = i + 1
    }
    int j = len(s) - 1
    while j >= 0 && (string(s[j]) == " " || string(s[j]) == "\t" || string(s[j]) == "\r" || string(s[j]) == "\n") {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    while k <= j {
        out = out + string(s[k])
        k = k + 1
    }
    out
}

func starts_with(string s, string p) bool {
    if len(p) > len(s) { return false }
    int i = 0
    while i < len(p) {
        if string(s[i]) != string(p[i]) {
            return false
        }
        i = i + 1
    }
    true
}

func substr(string s, int from, int to) string {
    string out = ""
    int i = from
    while i < to && i < len(s) {
        out = out + string(s[i])
        i = i + 1
    }
    out
}

func int_to_str(int n, int fallback) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    if neg {
        n = -n
    }
    string s = ""
    while n > 0 {
        s = string(n - (n / 10) * 10 + 48) + s
        n = n / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func fmt_float(float val, int decimals) string {
    if val == 0.0 {
        return "0.0"
    }
    bool neg = val < 0.0
    if neg {
        val = -val
    }
    int int_part = float_to_int(val)
    float frac = val - int_part * 1.0
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part, 0) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = float_to_int(frac)
        s = s + string(digit + 48)
        frac = frac - digit * 1.0
        i = i + 1
    }
    s
}

func pad_float(float val, int w, int d) string {
    string s = fmt_float(val, d)
    while len(s) < w {
        s = " " + s
    }
    s
}

func split_lines(string s) []string {
    int capacity = 1
    int j = 0
    while j < len(s) {
        if string(s[j]) == "\n" {
            capacity = capacity + 1
        }
        j = j + 1
    }
    []string out = []string{cap: capacity}
    string line = ""
    int idx = 0
    int i = 0
    while i < len(s) {
        if string(s[i]) == "\n" || string(s[i]) == "\r" {
            if len(line) > 0 {
                out[idx] = line
                idx = idx + 1
                line = ""
            }
            i = i + 1
            continue
        }
        line = line + string(s[i])
        i = i + 1
    }
    if len(line) > 0 {
        out[idx] = line
    }
    out
}

func parse_csv_floats(string s) []float {
    int capacity = 1
    int j = 0
    while j < len(s) {
        if string(s[j]) == "," {
            capacity = capacity + 1
        }
        j = j + 1
    }
    []float out = []float{cap: capacity}
    string cur = ""
    int idx = 0
    int i = 0
    while i < len(s) {
        if string(s[i]) == "," {
            if len(cur) > 0 {
                out[idx] = str_to_float(trim(cur))
                idx = idx + 1
                cur = ""
            }
        } else {
            cur = cur + string(s[i])
        }
        i = i + 1
    }
    if len(cur) > 0 {
        out[idx] = str_to_float(trim(cur))
    }
    out
}

func parse_csv_ints(string s) []int {
    int capacity = 1
    int j = 0
    while j < len(s) {
        if string(s[j]) == "," {
            capacity = capacity + 1
        }
        j = j + 1
    }
    []int out = []int{cap: capacity}
    string cur = ""
    int idx = 0
    int i = 0
    while i < len(s) {
        if string(s[i]) == "," {
            if len(cur) > 0 {
                out[idx] = str_to_int(trim(cur), 0)
                idx = idx + 1
                cur = ""
            }
        } else {
            cur = cur + string(s[i])
        }
        i = i + 1
    }
    if len(cur) > 0 {
        out[idx] = str_to_int(trim(cur), 0)
    }
    out
}

func str_to_int(string s, int fallback) int {
    if len(s) == 0 { return fallback }
    int sign = 1
    int i = 0
    if s[0] == 45 { sign = -1; i = 1 }
    int value = 0
    while i < len(s) {
        int digit = s[i] - 48
        if digit < 0 || digit > 9 { return fallback }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func str_to_float(string s) float {
    if len(s) == 0 { return 0.0 }
    bool neg = false
    int i = 0
    if s[0] == 45 { neg = true; i = 1 }
    float int_part = 0.0
    while i < len(s) && s[i] >= 48 && s[i] <= 57 {
        int_part = int_part * 10.0 + (s[i] - 48) * 1.0
        i = i + 1
    }
    float frac = 0.0
    float div = 1.0
    if i < len(s) && s[i] == 46 {
        i = i + 1
        while i < len(s) && s[i] >= 48 && s[i] <= 57 {
            frac = frac * 10.0 + (s[i] - 48) * 1.0
            div = div * 10.0
            i = i + 1
        }
    }
    float val = int_part + frac / div
    if neg { val = -val }
    val
}

func float_to_int(float x) int {
    int n = 0
    float y = x
    if y < 0.0 {
        while y < 0.0 {
            y = y + 1.0
            n = n - 1
        }
    }
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}

func shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = string(value[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}

func read_line(string path, int line_no) string {
    string cmd = "sed -n '" + int_to_str(line_no, 0) + "p' " + shell_escape(path)
    trim(runtime_run_command_output(cmd))
}

func resolve_checkpoint_path(string input_path) string {
    string checkpoint_path = input_path
    if runtime_file_exists(input_path + "/latest_checkpoint.txt") {
        checkpoint_path = trim(runtime_read_text_file(input_path + "/latest_checkpoint.txt"))
    }
    if checkpoint_path == "" {
        checkpoint_path = input_path
    }
    checkpoint_path
}

func extract_weight_row_csv(string checkpoint_path, int row_id, int vocab_size) string {
    int start = row_id * vocab_size + 1
    int end = start + vocab_size - 1
    string cmd = "awk -F= '/^param0.data=/{print $2}' " + shell_escape(checkpoint_path) + " | cut -d',' -f" + int_to_str(start, 0) + "-" + int_to_str(end, 0)
    trim(runtime_run_command_output(cmd))
}

func csv_first_int(string s) int {
    string cur = ""
    int i = 0
    while i < len(s) {
        if string(s[i]) == "," {
            break
        }
        cur = cur + string(s[i])
        i = i + 1
    }
    str_to_int(trim(cur), 0)
}

func csv_second_int(string s) int {
    string cur = ""
    int i = 0
    bool seen_first = false
    while i < len(s) {
        if string(s[i]) == "," {
            seen_first = true
            i = i + 1
            break
        }
        i = i + 1
    }
    while i < len(s) {
        cur = cur + string(s[i])
        i = i + 1
    }
    if !seen_first {
        return 0
    }
    str_to_int(trim(cur), 0)
}

func argmax_next_row([]float weights_row, []float bias, int vocab_size) int {
    int best_id = 0
    float best_logit = weights_row[0] + bias[0]
    int i = 1
    while i < vocab_size {
        float logit = weights_row[i] + bias[i]
        if logit > best_logit {
            best_logit = logit
            best_id = i
        }
        i = i + 1
    }
    best_id
}

func main() int {
    string checkpoint_arg = trim(runtime_env_get("NEURX_INFER_CHECKPOINT", "artifacts/checkpoints/llm_s_pretrain"))
    string seed = runtime_env_get("NEURX_INFER_SEED", "neurx ")
    int max_new = str_to_int(runtime_env_get("NEURX_INFER_MAX_NEW_CHARS", "120"), 120)
    string checkpoint_path = resolve_checkpoint_path(checkpoint_arg)
    if !runtime_file_exists(checkpoint_path) {
        println("checkpoint not found: " + checkpoint_path)
        return 1
    }
    string step_line = read_line(checkpoint_path, 2)
    string loss_line = read_line(checkpoint_path, 3)
    string count_line = read_line(checkpoint_path, 4)
    string weight_shape_line = read_line(checkpoint_path, 6)
    string bias_shape_line = read_line(checkpoint_path, 9)
    string bias_data_line = read_line(checkpoint_path, 10)
    int step = str_to_int(substr(step_line, 5, len(step_line)), 0)
    float loss = str_to_float(substr(loss_line, 5, len(loss_line)))
    int param_count = str_to_int(substr(count_line, 12, len(count_line)), 0)
    string weight_shape_text = substr(weight_shape_line, 13, len(weight_shape_line))
    string bias_shape_text = substr(bias_shape_line, 13, len(bias_shape_line))
    int weight_rows = csv_first_int(weight_shape_text)
    int weight_cols = csv_second_int(weight_shape_text)
    int bias_size = csv_first_int(bias_shape_text)
    []float bias = parse_csv_floats(substr(bias_data_line, 12, len(bias_data_line)))
    int vocab = 256
    if bias_size > 0 {
        vocab = bias_size
    }
    if weight_cols > 0 {
        vocab = weight_cols
    }
    if vocab < 2 {
        vocab = 2
    }
    println("================================================")
    println("NeurX S local checkpoint inference")
    println("================================================")
    println("checkpoint path: " + checkpoint_path)
    println("Step: " + int_to_str(step, 0))
    println("Loss: " + pad_float(loss, 8, 6))
    println("param count: " + int_to_str(param_count, 0))
    if weight_rows > 0 && weight_cols > 0 {
        println("Weight shape: " + int_to_str(weight_rows, 0) + "x" + int_to_str(weight_cols, 0))
    }
    if bias_size > 0 {
        println("Bias shape: " + int_to_str(bias_size, 0))
    }
    println("Seed: " + seed)
    println("Generated:")
    string output = seed
    int prev_id = 32
    if len(seed) > 0 {
        prev_id = seed[len(seed) - 1] - (seed[len(seed) - 1] / vocab) * vocab
    }
    int cached_row_id = -1
    []float cached_row = []float{cap: 0}
    int token = 0
    while token < max_new {
        if cached_row_id != prev_id {
            string row_csv = extract_weight_row_csv(checkpoint_path, prev_id, vocab)
            cached_row = parse_csv_floats(row_csv)
            cached_row_id = prev_id
        }
        if len(cached_row) < vocab {
            println(output)
            println("================================================")
            return 0
        }
        int next_id = argmax_next_row(cached_row, bias, vocab)
        output = output + string(next_id)
        prev_id = next_id
        token = token + 1
    }
    println(output)
    println("================================================")
    0
}
