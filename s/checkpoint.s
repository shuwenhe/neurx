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

func split_lines(string text) []string {
    int n = len(text)
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < n {
        string ch = text[i]
        if ch == "\n" {
            string cleaned = trim(current)
            if cleaned != "" {
                lines.push(cleaned)
            }
            current = ""
        } else if ch != "\r" {
            current = current + ch
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
        if ch == "," {
            tokens.push(trim(current))
            current = ""
        } else {
            current = current + ch
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
    v == "1" || v == "true" || v == "yes" || v == "on"
}

func tensor_to_checkpoint_lines(int index, tensor value) []string {
    []string lines = []string{cap: 0}
    lines.push("param" + string(index) + ".requires_grad=" + string(value.requires_grad))
    lines.push("param" + string(index) + ".shape=" + join_ints(value.shape))
    lines.push("param" + string(index) + ".data=" + join_floats(value.data))
    lines
}

func checkpoint_to_text(checkpoint state) string {
    string out = "checkpoint_v1\n"
    out = out + "step=" + string(state.step) + "\n"
    out = out + "loss=" + string(state.loss) + "\n"
    out = out + "param_count=" + string(len(state.params)) + "\n"
    int i = 0
    while i < len(state.params) {
        []string lines = tensor_to_checkpoint_lines(i, state.params[i])
        int j = 0
        while j < len(lines) {
            out = out + lines[j] + "\n"
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
            step = int(line[len("step="):])
        } else if has_prefix(line, "loss=") {
            loss = float(line[len("loss="):])
        } else if has_prefix(line, "param_count=") {
            param_count = int(line[len("param_count="):])
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
                if line[j] == "=" {
                    eq_pos = j
                    j = len(line)
                }
                j = j + 1
            }
            if eq_pos >= 0 {
                string head = line[0:eq_pos]
                string flag = line[eq_pos + 1:len(line)]
                int dot_pos = -1
                j = 0
                while j < len(head) {
                    if head[j] == "." {
                        dot_pos = j
                        j = len(head)
                    }
                    j = j + 1
                }
                if dot_pos > len("param") {
                    string idx_text = head[len("param"):dot_pos]
                    int idx = int(idx_text)
                    string shape_key = "param" + string(idx) + ".shape="
                    string data_key = "param" + string(idx) + ".data="
                    bool requires_grad = parse_bool_flag(flag)
                    []int shape = []int{cap: 0}
                    []float data = []float{cap: 0}

                    int k = 0
                    while k < len(lines) {
                        string candidate = lines[k]
                        if has_prefix(candidate, shape_key) {
                            shape = parse_int_list(candidate[len(shape_key):len(candidate)])
                        }
                        if has_prefix(candidate, data_key) {
                            data = parse_float_list(candidate[len(data_key):len(candidate)])
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
    runtime_write_text_file(normalize_checkpoint_path(path), checkpoint_to_text(new_checkpoint(step, loss, params)))
}

func load_checkpoint(string path) checkpoint {
    string target = normalize_checkpoint_path(path)
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
        target = target[0:len(target) - 1]
    }
    if !has_prefix(target, "artifacts/") && !has_prefix(target, "build/") {
        target = "artifacts/checkpoints/" + target
    }
    if !has_suffix(target, ".neurx") && !has_suffix(target, ".txt") {
        target = target + ".neurx"
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
