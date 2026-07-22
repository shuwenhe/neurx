package neurx.checkpoint

use neurx.tensor.tensor
use neurx.tensor.new
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file, runtime_write_text_file}

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}

func has_prefix(string value, string prefix) bool {
    int value_len = len(value)
    int prefix_len = len(prefix)
    if value_len < prefix_len {
        return false
    }
    int i = 0
    while i < prefix_len {
        if value[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func has_suffix(string value, string suffix) bool {
    int value_len = len(value)
    int suffix_len = len(suffix)
    if value_len < suffix_len {
        return false
    }
    int offset = value_len - suffix_len
    int i = 0
    while i < suffix_len {
        if value[offset + i] != suffix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func last_path_separator_index(string path) int {
    int i = len(path) - 1
    while i >= 0 {

        int ch = int(string(path[i]))
        if ch == 47 {
            return i
        }
        i = i - 1
    }
    -1
}

func path_dirname(string path) string {
    int idx = last_path_separator_index(path)
    if idx < 0 {
        return ""
    }
    neurx.strings.substring(path, 0, idx)
}

func path_basename(string path) string {
    int idx = last_path_separator_index(path)
    if idx < 0 {
        return path
    }
    neurx.strings.substring(path, idx + 1, len(path))
}

func path_join(string left, string right) string {
    string base = trim(left)
    string tail = trim(right)
    if neurx.strings.strings_eq(base, "") {
        return tail
    }
    if neurx.strings.strings_eq(tail, "") {
        return base
    }
    bool suffix_check = has_suffix(base, "/")
    if suffix_check {
        return neurx.strings.concat2(base, tail)
    }
    neurx.strings.concat3(base, "/", tail)
}

func strip_checkpoint_file_tail(string path) string {
    string current = trim(path)
    if current == "" {
        return ""
    }
    string leaf = path_basename(current)
    if has_suffix(leaf, ".neurx") || has_suffix(leaf, ".txt") {
        current = path_dirname(current)
    }
    leaf = path_basename(current)
    if leaf == "latest" {
        current = path_dirname(current)
    }
    leaf = path_basename(current)
    if has_prefix(leaf, "step_") {
        current = path_dirname(current)
    }
    current
}

func checkpoint_manifest_path(string checkpoint_path) string {
    string root = strip_checkpoint_file_tail(checkpoint_path)
    if root == "" {
        return ""
    }
    path_join(root, "latest_checkpoint.txt")
}

func resolve_checkpoint_path(string path) string {
    string target = trim(path)
    if target == "" {
        target = "latest"
    }

    while has_suffix(target, "/") {
        target = neurx.strings.substring(target, 0, len(target) - 1)
    }

    if runtime_file_exists(target) {
        return target
    }
    if !has_suffix(target, ".neurx") && runtime_file_exists(target + ".neurx") {
        return target + ".neurx"
    }
    if !has_suffix(target, ".txt") && runtime_file_exists(target + ".txt") {
        return target + ".txt"
    }

    string manifest = checkpoint_manifest_path(target)
    if manifest != "" && runtime_file_exists(manifest) {
        string resolved = trim(runtime_read_text_file(manifest))
        if resolved != "" && runtime_file_exists(resolved) {
            return resolved
        }
        if resolved != "" && !has_suffix(resolved, ".neurx") && runtime_file_exists(resolved + ".neurx") {
            return resolved + ".neurx"
        }
    }

    if !has_prefix(target, "artifacts/") && !has_prefix(target, "build/") {
        string relative_target = path_join("artifacts/checkpoints", target)
        if runtime_file_exists(relative_target) {
            return relative_target
        }
        if !has_suffix(relative_target, ".neurx") && runtime_file_exists(relative_target + ".neurx") {
            return relative_target + ".neurx"
        }
        string relative_manifest = checkpoint_manifest_path(relative_target)
        if relative_manifest != "" && runtime_file_exists(relative_manifest) {
            string resolved_relative = trim(runtime_read_text_file(relative_manifest))
            if resolved_relative != "" && runtime_file_exists(resolved_relative) {
                return resolved_relative
            }
        }
    }

    target
}

func split_lines(string text) []string {
    int n = len(text)
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < n {
        string ch = text[i]
        int chi = int(string(ch))

        if chi == 10 {
            string cleaned = trim(current)
            if cleaned != "" {
                lines.push(cleaned)
            }
            current = ""
        } else if chi != 13 {
            current = neurx.strings.concat2(current, ch)
        }
        i = i + 1
    }
    string tail = trim(current)
    if tail != "" {
        lines.push(tail)
    }
    lines
}

func csv_tokens(string text) []string {
    int n = len(text)
    []string tokens = []string{cap: 0}
    string current = ""
    int i = 0
    while i < n {
        string ch = text[i]
        int chi = int(string(ch))

        if chi == 44 {
            tokens.push(trim(current))
            current = ""
        } else {
            current = neurx.strings.concat2(current, ch)
        }
        i = i + 1
    }
    if trim(current) != "" {
        tokens.push(trim(current))
    }
    tokens
}

func join_ints([]int values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + string(values[i])
        i = i + 1
    }
    out
}

func join_floats([]float values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + string(values[i])
        i = i + 1
    }
    out
}

func parse_int_list(string value) []int {
    []string parts = csv_tokens(value)
    []int out = []int{cap: 0}
    int i = 0
    while i < len(parts) {
        string token = trim(parts[i])
        if token != "" {
            out.push(int(token))
        }
        i = i + 1
    }
    out
}

func parse_float_list(string value) []float {
    []string parts = csv_tokens(value)
    []float out = []float{cap: 0}
    int i = 0
    while i < len(parts) {
        string token = trim(parts[i])
        if token != "" {
            out.push(float(token))
        }
        i = i + 1
    }
    out
}

func parse_bool_flag(string value) bool {
    string v = lower(trim(value))
    bool r1 = neurx.strings.strings_eq(v, "1")
    bool r2 = neurx.strings.strings_eq(v, "true")
    bool r3 = neurx.strings.strings_eq(v, "yes")
    bool r4 = neurx.strings.strings_eq(v, "on")
    r1 || r2 || r3 || r4
}

func tensor_to_checkpoint_lines(int index, tensor value) []string {
    []string lines = []string{cap: 0}
    string idx_str = string(index)
    string line1 = neurx.strings.concat5("param", idx_str, ".requires_grad=", string(value.requires_grad), "")
    string line2 = neurx.strings.concat5("param", idx_str, ".shape=", join_ints(value.shape), "")
    string line3 = neurx.strings.concat5("param", idx_str, ".data=", join_floats(value.data), "")
    lines.push(line1)
    lines.push(line2)
    lines.push(line3)
    lines
}

func tensor_to_checkpoint_lines_from_params([]tensor params, int index) []string {

    []float empty_data = []float{cap: 0}
    []int empty_shape = []int{cap: 0}
    tensor t = new(empty_data, empty_shape, false)
    if index < len(params) {

        int k = 0
        while k < len(params) {
            if k == index {
                t = params[k]
                k = len(params)
            }
            k = k + 1
        }
    }
    tensor_to_checkpoint_lines(index, t)
}

func checkpoint_to_text(checkpoint state) string {
    string out = "checkpoint_v1\n"
    string step_line = neurx.strings.concat4("step=", string(state.step), "\n", "")
    string loss_line = neurx.strings.concat4("loss=", string(state.loss), "\n", "")
    string count_line = neurx.strings.concat4("param_count=", string(len(state.params)), "\n", "")
    out = neurx.strings.concat2(out, step_line)
    out = neurx.strings.concat2(out, loss_line)
    out = neurx.strings.concat2(out, count_line)
    int i = 0
    while i < len(state.params) {
        []string lines = tensor_to_checkpoint_lines_from_params(state.params, i)
        int j = 0
        while j < len(lines) {
            string line_j = neurx.string_at(lines, j)
            out = neurx.strings.concat3(out, line_j, "\n")
            j = j + 1
        }
        i = i + 1
    }
    out
}

func parse_checkpoint_lines([]string lines) checkpoint {
    if len(lines) == 0 {
        return new_checkpoint(0, 0.0, [])
    }
    if lines[0] != "checkpoint_v1" {
        return new_checkpoint(0, 0.0, [])
    }

    int step = 0
    float loss = 0.0
    int param_count = 0
    int i = 1
    while i < len(lines) {
        string line = lines[i]
        if has_prefix(line, "step=") {
            step = int(neurx.strings.substring(line, len("step="), len(line)))
        } else if has_prefix(line, "loss=") {
            loss = float(neurx.strings.substring(line, len("loss="), len(line)))
        } else if has_prefix(line, "param_count=") {
            param_count = int(neurx.strings.substring(line, len("param_count="), len(line)))
        }
        i = i + 1
    }

    []tensor params = []tensor{cap: 0}
    i = 1
    while i < len(lines) {
        string line = lines[i]
        if has_prefix(line, "param") {
            int eq_pos = -1
            int j = 0
            while j < len(line) {

                if int(string(line[j])) == 61 {
                    eq_pos = j
                    j = len(line)
                }
                j = j + 1
            }
            if eq_pos >= 0 {
                string head = neurx.strings.substring(line, 0, eq_pos)
                string flag = neurx.strings.substring(line, eq_pos + 1, len(line))
                int dot_pos = -1
                j = 0
                while j < len(head) {

                    if int(string(head[j])) == 46 {
                        dot_pos = j
                        j = len(head)
                    }
                    j = j + 1
                }
                if dot_pos > len("param") {
                    string idx_text = neurx.strings.substring(head, len("param"), dot_pos)
                    int idx = int(idx_text)
                    string shape_key = neurx.strings.concat4("param", string(idx), ".shape=", "")
                    string data_key = neurx.strings.concat4("param", string(idx), ".data=", "")
                    bool requires_grad = parse_bool_flag(flag)
                    []int shape = []int{cap: 0}
                    []float data = []float{cap: 0}

                    int k = 0
                    while k < len(lines) {
                        string candidate = lines[k]
                        if has_prefix(candidate, shape_key) {
                            shape = parse_int_list(neurx.strings.substring(candidate, len(shape_key), len(candidate)))
                        }
                        if has_prefix(candidate, data_key) {
                            data = parse_float_list(neurx.strings.substring(candidate, len(data_key), len(candidate)))
                        }
                        k = k + 1
                    }

                    params.push(new(data, shape, requires_grad))
                }
            }
        }
        i = i + 1
    }

    new_checkpoint(step, loss, params)
}

func copy_params([]tensor params) []tensor {
    int n = len(params)
    []tensor out = []tensor{cap: n}
    int i = 0
    while i < n {
        out[i] = copy_tensor(params[i])
        i = i + 1
    }
    out
}

struct checkpoint {
    int step
    float loss
    []tensor params
}

func new_checkpoint(int step, float loss, []tensor params) checkpoint {
    checkpoint {
        step: step,
        loss: loss,
        params: params,
    }
}

func checkpoint_state_dict(checkpoint state) checkpoint {
    checkpoint {
        step: state.step,
        loss: state.loss,
        params: copy_params(state.params),
    }
}

func checkpoint_load_state_dict(checkpoint state, checkpoint other) checkpoint {
    checkpoint {
        step: other.step,
        loss: other.loss,
        params: copy_params(other.params),
    }
}

func save_checkpoint(string path, int step, float loss, []tensor params) () {
    string target = normalize_checkpoint_path(path)
    runtime_write_text_file(target, checkpoint_to_text(new_checkpoint(step, loss, params)))

    string manifest = checkpoint_manifest_path(target)
    if manifest != "" {
        runtime_write_text_file(manifest, target)
    }
}

func load_checkpoint(string path) checkpoint {
    string target = resolve_checkpoint_path(path)
    if !runtime_file_exists(target) {
        return new_checkpoint(0, 0.0, [])
    }
    string content = runtime_read_text_file(target)
    parse_checkpoint_lines(split_lines(content))
}

func normalize_checkpoint_path(string path) string {
    string target = trim(path)
    if target == "" {
        target = "latest"
    }
    while has_suffix(target, "/") {
        target = neurx.strings.substring(target, 0, len(target) - 1)
    }
    if has_prefix(target, "/") {
        return target
    }
    if !has_prefix(target, "artifacts/") && !has_prefix(target, "build/") {
        target = neurx.strings.concat2("artifacts/checkpoints/", target)
    }
    if !has_suffix(target, ".neurx") && !has_suffix(target, ".txt") && !has_suffix(path_basename(target), "latest") {
        target = neurx.strings.concat2(target, ".neurx")
    }
    target
}

func checkpoint_step(checkpoint state) int {
    state.step
}

func checkpoint_loss(checkpoint state) float {
    state.loss
}

func checkpoint_params(checkpoint state) []tensor {
    state.params
}

func checkpoint_param_count(checkpoint state) int {
    len(state.params)
}
