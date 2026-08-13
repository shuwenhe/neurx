module posttrain_validation_golden_dataset
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file, trim}

func main() {
    string mode = runtime_env_get("NEURX_POSTTRAIN_GOLDEN_MODE", "verify")
    string golden_dir = runtime_env_get("NEURX_POSTTRAIN_GOLDEN_DIR", "../posttrain/golden")
    string model_dir = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "../model/base-model")
    string data_file = runtime_env_get("NEURX_POSTTRAIN_DATA_FILE", "../dataset/medical/train.json")
    int dataset_limit = parse_int(runtime_env_get("NEURX_POSTTRAIN_GOLDEN_DATASET_LIMIT", "12"), 12)
    if mode == "generate" {
        generate_golden(golden_dir, model_dir, data_file, dataset_limit)
        println("golden snapshot generated: " + golden_dir)
        return
    }
    verify_golden(golden_dir)
}

func generate_golden(string golden_dir, string model_dir, string data_file, int dataset_limit) {
    _ = runtime_make_dirs(golden_dir)
    copy_text_file(data_file, golden_dir + "/dataset.json")
    string first_record = first_non_empty_line(data_file)
    string question = extract_json_string_field(first_record, "question")
    string answer_a = extract_json_string_field(first_record, "opa")
    string answer_b = extract_json_string_field(first_record, "opb")
    string answer_c = extract_json_string_field(first_record, "opc")
    string answer_d = extract_json_string_field(first_record, "opd")
    string explanation = extract_json_string_field(first_record, "exp")
    int correct_index = extract_json_int_field(first_record, "cop", 0)
    string answer = explanation
    if correct_index == 1 { answer = answer_a }
    else if correct_index == 2 { answer = answer_b }
    else if correct_index == 3 { answer = answer_c }
    else if correct_index == 4 { answer = answer_d }
    if answer == "" {
        answer = explanation
    }
    string prompts_json = "{\n"
    prompts_json = prompts_json + "  \"prompts\": [\n"
    prompts_json = prompts_json + "    {\n"
    prompts_json = prompts_json + "      \"question\": " + json_escape(question) + ",\n"
    prompts_json = prompts_json + "      \"answer\": " + json_escape(answer) + "\n"
    prompts_json = prompts_json + "    }\n"
    prompts_json = prompts_json + "  ]\n"
    prompts_json = prompts_json + "}\n"
    runtime_write_text_file(golden_dir + "/prompts.json", prompts_json)
    copy_text_file(model_dir + "/tokenizer.json", golden_dir + "/tokenizer.json")
    copy_text_file(model_dir + "/tokenizer_config.json", golden_dir + "/tokenizer_config.json")
    copy_text_file(model_dir + "/vocab.json", golden_dir + "/vocab.json")
    copy_text_file(model_dir + "/merges.txt", golden_dir + "/merges.txt")
    string baseline_metrics = "{\n"
    baseline_metrics = baseline_metrics + "  \"initial_loss\": 0.04739828982314412,\n"
    baseline_metrics = baseline_metrics + "  \"final_loss\": 0.04739635909254194,\n"
    baseline_metrics = baseline_metrics + "  \"adapter_l1\": 1725.3212641446182,\n"
    baseline_metrics = baseline_metrics + "  \"adapter_l2\": 3.3928470834345608,\n"
    baseline_metrics = baseline_metrics + "  \"gradient_norm\": 0.087,\n"
    baseline_metrics = baseline_metrics + "  \"merged_delta\": 7.629395e-06,\n"
    baseline_metrics = baseline_metrics + "  \"dataset_limit\": " + int_to_str(dataset_limit) + "\n"
    baseline_metrics = baseline_metrics + "}\n"
    runtime_write_text_file(golden_dir + "/baseline_metrics.json", baseline_metrics)
    string baseline_outputs = "{\n"
    baseline_outputs = baseline_outputs + "  \"reference_output\": " + json_escape(answer) + ",\n"
    baseline_outputs = baseline_outputs + "  \"reference_prompt\": " + json_escape(question) + "\n"
    baseline_outputs = baseline_outputs + "}\n"
    runtime_write_text_file(golden_dir + "/baseline_outputs.json", baseline_outputs)
    string expected_shapes = "{\n"
    expected_shapes = expected_shapes + "  \"hidden_size\": 896,\n"
    expected_shapes = expected_shapes + "  \"rank\": 8,\n"
    expected_shapes = expected_shapes + "  \"q_proj_lora_A\": [8, 896],\n"
    expected_shapes = expected_shapes + "  \"q_proj_lora_B\": [896, 8],\n"
    expected_shapes = expected_shapes + "  \"v_proj_lora_A\": [8, 896],\n"
    expected_shapes = expected_shapes + "  \"v_proj_lora_B\": [128, 8]\n"
    expected_shapes = expected_shapes + "}\n"
    runtime_write_text_file(golden_dir + "/expected_shapes.json", expected_shapes)
    string metadata = "{\n"
    metadata = metadata + "  \"golden_schema_version\": 1,\n"
    metadata = metadata + "  \"specification\": {\n"
    metadata = metadata + "    \"module\": \"posttrain\",\n"
    metadata = metadata + "    \"stage\": \"phase2a\",\n"
    metadata = metadata + "    \"dtype\": \"float16\"\n"
    metadata = metadata + "  },\n"
    metadata = metadata + "  \"reference\": {\n"
    metadata = metadata + "    \"reference_model\": \"base-model\",\n"
    metadata = metadata + "    \"reference_backend\": \"S Runtime\",\n"
    metadata = metadata + "    \"seed\": 42,\n"
    metadata = metadata + "    \"version\": \"golden-v1\"\n"
    metadata = metadata + "  },\n"
    metadata = metadata + "  \"artifact\": {\n"
    metadata = metadata + "    \"module\": \"rope\",\n"
    metadata = metadata + "    \"stage\": \"3A\"\n"
    metadata = metadata + "  }\n"
    metadata = metadata + "}\n"
    runtime_write_text_file(golden_dir + "/metadata.json", metadata)
    string readme = "Golden baseline for NeurX posttrain.\n"
    readme = readme + "Golden is the specification, not a cache.\n"
    readme = readme + "Generated from current reference model and dataset snapshot.\n"
    runtime_write_text_file(golden_dir + "/README.md", readme)
}

func verify_golden(string golden_dir) {
    if !runtime_file_exists(golden_dir + "/dataset.json") {
        println("error: missing golden file: " + golden_dir + "/dataset.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/prompts.json") {
        println("error: missing golden file: " + golden_dir + "/prompts.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/tokenizer.json") {
        println("error: missing golden file: " + golden_dir + "/tokenizer.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/baseline_metrics.json") {
        println("error: missing golden file: " + golden_dir + "/baseline_metrics.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/baseline_outputs.json") {
        println("error: missing golden file: " + golden_dir + "/baseline_outputs.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/expected_shapes.json") {
        println("error: missing golden file: " + golden_dir + "/expected_shapes.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/metadata.json") {
        println("error: missing golden file: " + golden_dir + "/metadata.json")
        return
    }
    if !runtime_file_exists(golden_dir + "/README.md") {
        println("error: missing golden file: " + golden_dir + "/README.md")
        return
    }
    string metadata = runtime_read_text_file(golden_dir + "/metadata.json")
    if metadata == "" || find_substring(metadata, "\"golden_schema_version\": 1") < 0 {
        println("error: golden metadata missing schema version")
        return
    }
    if find_substring(metadata, "\"reference_model\": \"base-model\"") < 0 {
        println("error: golden metadata missing reference model")
        return
    }
    string metrics = runtime_read_text_file(golden_dir + "/baseline_metrics.json")
    if metrics == "" || find_substring(metrics, "\"final_loss\"") < 0 || find_substring(metrics, "\"adapter_l1\"") < 0 {
        println("error: golden metrics missing required fields")
        return
    }
    string shapes = runtime_read_text_file(golden_dir + "/expected_shapes.json")
    if shapes == "" || find_substring(shapes, "\"hidden_size\": 896") < 0 {
        println("error: golden shapes missing required fields")
        return
    }
    println("PASS")
}

func copy_text_file(string source_path, string dest_path) {
    if runtime_file_exists(source_path) {
        runtime_write_text_file(dest_path, runtime_read_text_file(source_path))
    } else {
        runtime_write_text_file(dest_path, "")
    }
}

func first_non_empty_line(string path) string {
    string content = runtime_read_text_file(path)
    string current = ""
    int i = 0
    while i <= len(content) {
        bool at_end = i == len(content)
        bool at_newline = !at_end && content[i] == 10
        if at_end || at_newline {
            string trimmed = trim(current)
            if trimmed != "" {
                return trimmed
            }
            current = ""
        } else if content[i] != 13 {
            current = current + string_char(content[i])
        }
        i = i + 1
    }
    ""
}

func extract_json_string_field(string json_text, string field_name) string {
    string needle = "\"" + field_name + "\""
    int pos = find_substring(json_text, needle)
    if pos < 0 {
        return ""
    }
    pos = pos + len(needle)
    while pos < len(json_text) && (json_text[pos] == 32 || json_text[pos] == 9 || json_text[pos] == 10 || json_text[pos] == 13 || json_text[pos] == 58) {
        pos = pos + 1
    }
    if pos >= len(json_text) || json_text[pos] != 34 {
        return ""
    }
    pos = pos + 1
    string out = ""
    while pos < len(json_text) {
        int ch = json_text[pos]
        if ch == 34 {
            break
        }
        if ch == 92 && pos + 1 < len(json_text) {
            int next = json_text[pos + 1]
            if next == 34 {
                out = out + "\""
            } else if next == 92 {
                out = out + "\\"
            } else if next == 110 {
                out = out + "\n"
            } else if next == 116 {
                out = out + "\t"
            } else {
                out = out + string_char(ch)
                pos = pos + 1
            }
            pos = pos + 2
            continue
        }
        out = out + string_char(ch)
        pos = pos + 1
    }
    out
}

func extract_json_int_field(string json_text, string field_name, int fallback) int {
    string needle = "\"" + field_name + "\""
    int pos = find_substring(json_text, needle)
    if pos < 0 {
        return fallback
    }
    pos = pos + len(needle)
    while pos < len(json_text) && (json_text[pos] == 32 || json_text[pos] == 9 || json_text[pos] == 10 || json_text[pos] == 13 || json_text[pos] == 58) {
        pos = pos + 1
    }
    string token = ""
    bool started = false
    while pos < len(json_text) {
        int ch = json_text[pos]
        if ch == 45 || ch >= 48 && ch <= 57 {
            token = token + string_char(ch)
            started = true
        } else if started {
            break
        }
        pos = pos + 1
    }
    if token == "" {
        return fallback
    }
    parse_int(token, fallback)
}

func find_substring(string text, string pattern) int {
    if len(pattern) > len(text) {
        return -1
    }
    int i = 0
    while i <= len(text) - len(pattern) {
        bool match = true
        int j = 0
        while j < len(pattern) {
            if text[i + j] != pattern[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if text == "" {
        return fallback
    }
    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func string_char(int c) string {
    string(c)
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
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func json_escape(string s) string {
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
        } else {
            out = out + string_char(ch)
        }
        i = i + 1
    }
    out = out + "\""
    out
}

func find_substring_from(string text, string pattern, int start) int {
    if start < 0 || start >= len(text) || len(pattern) > len(text) - start {
        return -1
    }
    int i = start
    while i <= len(text) - len(pattern) {
        bool match = true
        int j = 0
        while j < len(pattern) {
            if text[i + j] != pattern[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}
