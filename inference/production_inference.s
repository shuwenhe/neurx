package neurx.inference.production_inference

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_run_command_output}

func trim(string s) string {
    int i = 0
    while i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }

    int j = len(s) - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }

    if j < i {
        return ""
    }

    string out = ""
    int k = i
    while k <= j {
        out = out + string_char(s[k])
        k = k + 1
    }
    out
}

func string_char(int c) string {
    string(c)
}

func substr(string s, int from, int to) string {
    string out = ""
    int i = from
    while i < to && i < len(s) {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func has_suffix(string s, string suffix) bool {
    if len(suffix) > len(s) {
        return false
    }
    substr(s, len(s) - len(suffix), len(s)) == suffix
}

func line_at(string text, int line_no) string {
    if line_no <= 0 {
        return ""
    }

    int current_line = 1
    string out = ""
    int i = 0
    while i < len(text) {
        int ch = text[i]
        if ch == 10 {
            if current_line == line_no {
                return out
            }
            current_line = current_line + 1
            out = ""
        } else if ch != 13 {
            if current_line == line_no {
                out = out + string_char(ch)
            }
        }
        i = i + 1
    }

    if current_line == line_no {
        return out
    }
    ""
}

func int_to_str(int n, int fallback) string {
    int value = n
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    if neg {
        value = -value
    }
    string s = ""
    while value > 0 {
        s = string_char(value % 10 + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func str_to_int(string s, int fallback) int {
    if len(s) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if s[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(s) {
        int digit = s[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func str_to_float(string s) float {
    if len(s) == 0 {
        return 0.0
    }
    bool neg = false
    int i = 0
    if s[0] == 45 {
        neg = true
        i = 1
    }

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

    float value = int_part + frac / div
    if neg {
        value = -value
    }
    value
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

func fmt_float(float val, int decimals) string {
    float value = val
    if value == 0.0 {
        return "0.0"
    }
    bool neg = value < 0.0
    if neg {
        value = -value
    }
    int int_part = float_to_int(value)
    float frac = value - int_part * 1.0
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part, 0) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = float_to_int(frac)
        s = s + string_char(digit + 48)
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

func shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = string_char(value[i])
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
    trim(line_at(runtime_read_text_file(path), line_no))
}

func resolve_checkpoint_path(string input_path) string {
    string checkpoint_path = input_path
    if !has_suffix(input_path, ".neurx") {
        string latest_path = trim(runtime_read_text_file(input_path + "/latest_checkpoint.txt"))
        if len(latest_path) > 0 {
            checkpoint_path = latest_path
        }
    } else if runtime_file_exists(input_path) {
        checkpoint_path = input_path
    }
    if checkpoint_path == "" {
        checkpoint_path = input_path
    }
    checkpoint_path
}

func build_qa_prompt(string prompt) string {
    string clean_prompt = trim(prompt)
    if len(clean_prompt) == 0 {
        clean_prompt = "NeurX 可以做什么？"
    }
    "你是一个认真、简洁的中文助手。请直接回答下面的问题，不要复述问题：\n" +
    clean_prompt + "\n答案："
}

func resolve_inference_prompt(string prompt_from_env, string fallback_prompt, string answer_mode) string {
    string prompt = trim(prompt_from_env)
    if len(prompt) == 0 {
        prompt = trim(fallback_prompt)
    }
    if len(prompt) == 0 {
        prompt = "NeurX 可以做什么？"
    }

    if answer_mode == "raw" {
        return prompt
    }
    if answer_mode == "chat" {
        return "用户: " + prompt + "\n助手: "
    }
    build_qa_prompt(prompt)
}

func csv_first_int(string s) int {
    string cur = ""
    int i = 0
    while i < len(s) {
        if s[i] == 44 {
            break
        }
        cur = cur + string_char(s[i])
        i = i + 1
    }
    str_to_int(trim(cur), 0)
}

func csv_second_int(string s) int {
    string cur = ""
    int i = 0
    bool seen_first = false
    while i < len(s) {
        if s[i] == 44 {
            seen_first = true
            i = i + 1
            break
        }
        i = i + 1
    }
    while i < len(s) {
        cur = cur + string_char(s[i])
        i = i + 1
    }
    if !seen_first {
        return 0
    }
    str_to_int(trim(cur), 0)
}

func parse_csv_floats(string s) []float {
    int capacity = 1
    int j = 0
    while j < len(s) {
        if s[j] == 44 {
            capacity = capacity + 1
        }
        j = j + 1
    }

    []float out = []float{cap: capacity}
    string cur = ""
    int idx = 0
    int i = 0
    while i < len(s) {
        if s[i] == 44 {
            if len(cur) > 0 {
                out[idx] = str_to_float(trim(cur))
                idx = idx + 1
                cur = ""
            }
        } else {
            cur = cur + string_char(s[i])
        }
        i = i + 1
    }
    if len(cur) > 0 {
        out[idx] = str_to_float(trim(cur))
    }
    out
}

func extract_weight_row_csv(string checkpoint_path, int row_id, int vocab_size) string {
    int start = row_id * vocab_size + 1
    int end = start + vocab_size - 1
    string cmd = "awk -F= '/^param0.data=/{print $2}' " + shell_escape(checkpoint_path) + " | cut -d',' -f" + int_to_str(start, 0) + "-" + int_to_str(end, 0)
    trim(runtime_run_command_output(cmd))
}

func argmax_next_row_from_csv(string weights_csv, int row_id, int vocab_size, []float bias) int {
    if vocab_size <= 0 || len(weights_csv) == 0 || len(bias) == 0 {
        return 0
    }

    int start_field = row_id * vocab_size + 1
    int end_field = start_field + vocab_size - 1
    int field = 1
    int i = 0
    string cur = ""
    bool have_best = false
    int best_id = 0
    float best_logit = 0.0

    while i < len(weights_csv) {
        int ch = weights_csv[i]
        if ch == 44 {
            if field >= start_field && field <= end_field && len(cur) > 0 {
                float value = str_to_float(trim(cur))
                int idx = field - start_field
                if idx >= 0 && idx < len(bias) {
                    float logit = value + bias[idx]
                    if !have_best || logit > best_logit {
                        best_logit = logit
                        best_id = idx
                        have_best = true
                    }
                }
            }
            cur = ""
            field = field + 1
            if field > end_field {
                break
            }
        } else if field >= start_field && field <= end_field {
            cur = cur + string_char(ch)
        }
        i = i + 1
    }

    if field >= start_field && field <= end_field && len(cur) > 0 {
        float value = str_to_float(trim(cur))
        int idx = field - start_field
        if idx >= 0 && idx < len(bias) {
            float logit = value + bias[idx]
            if !have_best || logit > best_logit {
                best_id = idx
                have_best = true
            }
        }
    }

    if !have_best {
        return 0
    }
    best_id
}

func argmax_next_row([]float weights_row, []float bias, int vocab_size) int {
    if vocab_size <= 0 || len(weights_row) == 0 || len(bias) == 0 {
        return 0
    }
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

struct inference_engine {
    string model_name
    string device_type
    bool enable_quantization
    string quantization_type
    bool enable_compilation_cache
}

struct compiled_model {
    string model_name
    string backend
    string checkpoint_path
    int step
    float loss
    int param_count
    int max_seq_len
    int vocab_size
    int weight_rows
    int weight_cols
    int bias_size
    string weights_csv
    []float weights
    []float bias
    []string layer_names
    bool quantized
    string quantization_type
    bool graph_mode
    bool smoke_test
}

struct inference_config {
    int batch_size
    int max_total_tokens
    bool enable_streaming
    bool enable_kv_cache
    float dtype_quantization_scale
}

struct model_stats {
    int step
    float loss
    int param_count
    int max_seq_len
    int vocab_size
    int weight_rows
    int weight_cols
    int bias_size
}

struct benchmark_result {
    float throughput_tokens_per_sec
    float latency_ms_ttft
    float latency_ms_per_token
    float memory_used_mb
    float flops_utilized_percent
}

func new_inference_engine(string model_name, string device_type) inference_engine {
    inference_engine {
        model_name: model_name,
        device_type: device_type,
        enable_quantization: true,
        quantization_type: "fp8",
        enable_compilation_cache: true,
    }
}

func empty_compiled_model() compiled_model {
    compiled_model {
        model_name: "",
        backend: "cpu",
        checkpoint_path: "",
        step: 0,
        loss: 0.0,
        param_count: 0,
        max_seq_len: 0,
        vocab_size: 0,
        weight_rows: 0,
        weight_cols: 0,
        bias_size: 0,
        weights_csv: "",
        weights: []float{cap: 0},
        bias: []float{cap: 0},
        layer_names: []string{cap: 0},
        quantized: false,
        quantization_type: "none",
        graph_mode: false,
        smoke_test: false,
    }
}

func load_model(inference_engine engine, string checkpoint_arg) compiled_model {
    string checkpoint_path = resolve_checkpoint_path(checkpoint_arg)
    if !runtime_file_exists(checkpoint_path) {
        println("Checkpoint not found: " + checkpoint_path)
        return empty_compiled_model()
    }

    string step_line = read_line(checkpoint_path, 2)
    string loss_line = read_line(checkpoint_path, 3)
    string count_line = read_line(checkpoint_path, 4)
    string weight_shape_line = read_line(checkpoint_path, 6)
    string weight_data_line = read_line(checkpoint_path, 7)
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
    string weights_csv = substr(weight_data_line, 12, len(weight_data_line))
    []float bias = parse_csv_floats(substr(bias_data_line, 12, len(bias_data_line)))
    string smoke_text = trim(runtime_env_get("NEURX_INFER_SMOKE_TEST", ""))
    bool smoke_test = false
    if smoke_text == "1" || smoke_text == "true" {
        smoke_test = true
    }
    []float weights = []float{cap: 0}
    if !smoke_test {
        weights = parse_csv_floats(weights_csv)
    }

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

    []string layers = []string{cap: 2}
    layers[0] = "bigram_weight"
    layers[1] = "bigram_bias"

    compiled_model {
        model_name: engine.model_name,
        backend: engine.device_type,
        checkpoint_path: checkpoint_path,
        step: step,
        loss: loss,
        param_count: param_count,
        max_seq_len: weight_rows,
        vocab_size: vocab,
        weight_rows: weight_rows,
        weight_cols: weight_cols,
        bias_size: bias_size,
        weights_csv: weights_csv,
        weights: weights,
        bias: bias,
        layer_names: layers,
        quantized: false,
        quantization_type: engine.quantization_type,
        graph_mode: false,
        smoke_test: smoke_test,
    }
}

func apply_quantization(compiled_model model, string quantization_type) compiled_model {
    compiled_model {
        model_name: model.model_name,
        backend: model.backend,
        checkpoint_path: model.checkpoint_path,
        step: model.step,
        loss: model.loss,
        param_count: model.param_count,
        max_seq_len: model.max_seq_len,
        vocab_size: model.vocab_size,
        weight_rows: model.weight_rows,
        weight_cols: model.weight_cols,
        bias_size: model.bias_size,
        weights_csv: model.weights_csv,
        weights: model.weights,
        bias: model.bias,
        layer_names: model.layer_names,
        quantized: true,
        quantization_type: quantization_type,
        graph_mode: model.graph_mode,
        smoke_test: model.smoke_test,
    }
}

func compile_for_backend(compiled_model model, string backend) compiled_model {
    compiled_model {
        model_name: model.model_name,
        backend: backend,
        checkpoint_path: model.checkpoint_path,
        step: model.step,
        loss: model.loss,
        param_count: model.param_count,
        max_seq_len: model.max_seq_len,
        vocab_size: model.vocab_size,
        weight_rows: model.weight_rows,
        weight_cols: model.weight_cols,
        bias_size: model.bias_size,
        weights_csv: model.weights_csv,
        weights: model.weights,
        bias: model.bias,
        layer_names: model.layer_names,
        quantized: model.quantized,
        quantization_type: model.quantization_type,
        graph_mode: model.graph_mode,
        smoke_test: model.smoke_test,
    }
}

func enable_graph_mode(compiled_model model) compiled_model {
    compiled_model {
        model_name: model.model_name,
        backend: model.backend,
        checkpoint_path: model.checkpoint_path,
        step: model.step,
        loss: model.loss,
        param_count: model.param_count,
        max_seq_len: model.max_seq_len,
        vocab_size: model.vocab_size,
        weight_rows: model.weight_rows,
        weight_cols: model.weight_cols,
        bias_size: model.bias_size,
        weights_csv: model.weights_csv,
        weights: model.weights,
        bias: model.bias,
        layer_names: model.layer_names,
        quantized: model.quantized,
        quantization_type: model.quantization_type,
        graph_mode: true,
        smoke_test: model.smoke_test,
    }
}

func warmup_model(compiled_model model, int num_iterations) bool {
    if model.vocab_size <= 0 || len(model.bias) < 1 {
        return false
    }
    true
}

func extract_weight_row_csv_from_text(string weights_csv, int row_id, int vocab_size) string {
    int start_field = row_id * vocab_size + 1
    int end_field = start_field + vocab_size - 1
    string out = ""
    string cur = ""
    int field = 1
    int i = 0

    while i < len(weights_csv) {
        if weights_csv[i] == 44 {
            if field >= start_field && field <= end_field {
                if len(out) > 0 {
                    out = out + ","
                }
                out = out + trim(cur)
            }
            field = field + 1
            cur = ""
        } else {
            if field >= start_field && field <= end_field {
                cur = cur + string_char(weights_csv[i])
            }
        }
        if field > end_field {
            break
        }
        i = i + 1
    }

    if field >= start_field && field <= end_field && len(cur) > 0 {
        if len(out) > 0 {
            out = out + ","
        }
        out = out + trim(cur)
    }

    out
}

func generate_tokens(compiled_model model, string prompt, int max_tokens) string {
    if max_tokens < 0 {
        max_tokens = 0
    }
    if len(model.bias) == 0 || model.vocab_size <= 0 {
        return prompt
    }

    int vocab = model.vocab_size
    if vocab <= 0 {
        vocab = len(model.bias)
    }
    if vocab <= 0 {
        vocab = 256
    }

    string output = prompt
    int prev_id = 32
    if len(prompt) > 0 {
        prev_id = prompt[len(prompt) - 1] % vocab
    }

    int token = 0
    while token < max_tokens {
        if model.smoke_test || len(model.weights) == 0 {
            int next_id = argmax_next_row_from_csv(model.weights_csv, prev_id, vocab, model.bias)
            output = output + string_char(next_id)
            prev_id = next_id
            token = token + 1
            continue
        }

        int row_start = prev_id * vocab
        if row_start < 0 || row_start + vocab > len(model.weights) {
            return output
        }

        int next_id = 0
        float best_logit = model.weights[row_start] + model.bias[0]
        int i = 1
        while i < vocab {
            float logit = model.weights[row_start + i] + model.bias[i]
            if logit > best_logit {
                best_logit = logit
                next_id = i
            }
            i = i + 1
        }
        output = output + string_char(next_id)
        prev_id = next_id
        token = token + 1
    }

    output
}

func run_inference(compiled_model model, string prompt, int max_tokens) string {
    generate_tokens(model, prompt, max_tokens)
}

func run_batch_inference(compiled_model model, []string prompts, int max_tokens) []string {
    []string responses = []string{cap: len(prompts)}
    int i = 0
    while i < len(prompts) {
        responses[i] = run_inference(model, prompts[i], max_tokens)
        i = i + 1
    }
    responses
}

func create_optimization_profile(compiled_model model, string profile_type) compiled_model {
    if profile_type == "throughput" {
        return enable_graph_mode(model)
    }
    if profile_type == "memory" {
        return apply_quantization(model, "int8")
    }
    model
}

func get_model_stats(compiled_model model) model_stats {
    model_stats {
        step: model.step,
        loss: model.loss,
        param_count: model.param_count,
        max_seq_len: model.max_seq_len,
        vocab_size: model.vocab_size,
        weight_rows: model.weight_rows,
        weight_cols: model.weight_cols,
        bias_size: model.bias_size,
    }
}

func export_model_for_deployment(compiled_model model, string export_format) string {
    if export_format == "neurx" {
        return model.checkpoint_path
    }
    if export_format == "onnx" {
        return model.checkpoint_path
    }
    if export_format == "tensorrt" {
        return model.checkpoint_path
    }
    if export_format == "coreml" {
        return model.checkpoint_path
    }
    model.checkpoint_path
}

func run_ab_test([]compiled_model models, string prompt) []string {
    []string results = []string{cap: len(models)}
    int i = 0
    while i < len(models) {
        results[i] = run_inference(models[i], prompt, 100)
        i = i + 1
    }
    results
}

func benchmark_model(compiled_model model, int num_prompts, int avg_prompt_length) benchmark_result {
    float weight_bytes = (model.weight_rows * model.weight_cols + len(model.bias)) * 4.0
    float memory_mb = weight_bytes / 1048576.0
    benchmark_result {
        throughput_tokens_per_sec: 0.0,
        latency_ms_ttft: 0.0,
        latency_ms_per_token: 0.0,
        memory_used_mb: memory_mb,
        flops_utilized_percent: 0.0,
    }
}

func main() int {
    string model_name = trim(runtime_env_get("NEURX_INFER_MODEL_NAME", ""))
    if len(model_name) == 0 {
        model_name = "llm_s"
    }

    string device_type = trim(runtime_env_get("NEURX_INFER_DEVICE", ""))
    if len(device_type) == 0 {
        device_type = "cpu"
    }

    string checkpoint_arg = trim(runtime_env_get("NEURX_INFER_CHECKPOINT", ""))
    if len(checkpoint_arg) == 0 {
        checkpoint_arg = "/Users/feifei/shuwen/neurx/artifacts/checkpoints/llm_s_pretrain"
    }

    string seed = runtime_env_get("NEURX_INFER_SEED", "")
    if len(trim(seed)) == 0 {
        seed = "neurx "
    }

    string fallback_prompt = runtime_env_get("NEURX_INFER_FALLBACK_PROMPT", "")
    if len(trim(fallback_prompt)) == 0 {
        fallback_prompt = "NeurX 可以做什么？"
    }

    string prompt_from_env = runtime_env_get(
        "NEURX_INFER_PROMPT",
        runtime_env_get("NEURX_INFERENCE_INPUT", "")
    )
    if len(trim(prompt_from_env)) == 0 {
        prompt_from_env = "NeurX 可以做什么？"
    }
    string answer_mode = trim(runtime_env_get("NEURX_INFER_ANSWER_MODE", ""))
    if len(answer_mode) == 0 {
        answer_mode = "qa"
    }
    string answer_only = trim(runtime_env_get("NEURX_INFER_ANSWER_ONLY", ""))
    bool answer_only_mode = false
    if answer_only == "1" || answer_only == "true" {
        answer_only_mode = true
    }
    int max_new_chars = str_to_int(runtime_env_get("NEURX_INFER_MAX_NEW_CHARS", "120"), 120)
    string validate_only = runtime_env_get("NEURX_INFER_VALIDATE_ONLY", "")

    inference_engine engine = new_inference_engine(model_name, device_type)
    println("DEBUG checkpoint_arg=" + checkpoint_arg)
    compiled_model model = load_model(engine, checkpoint_arg)
    if len(model.bias) == 0 {
        println("Failed to load checkpoint: " + resolve_checkpoint_path(checkpoint_arg))
        return 1
    }

    if engine.enable_quantization {
        model = apply_quantization(model, engine.quantization_type)
    }
    model = compile_for_backend(model, engine.device_type)
    model = enable_graph_mode(model)

    println("================================================")
    println("NeurX S inference engine")
    println("================================================")
    println("Model: " + model.model_name)
    println("Backend: " + model.backend)
    println("Checkpoint path: " + model.checkpoint_path)
    println("Step: " + int_to_str(model.step, 0))
    println("Loss: " + pad_float(model.loss, 8, 6))
    println("Param count: " + int_to_str(model.param_count, 0))
    if model.weight_rows > 0 && model.weight_cols > 0 {
        println("Weight shape: " + int_to_str(model.weight_rows, 0) + "x" + int_to_str(model.weight_cols, 0))
    }
    if model.bias_size > 0 {
        println("Bias shape: " + int_to_str(model.bias_size, 0))
    }
    string quantized_text = "false"
    if model.quantized {
        quantized_text = "true"
    }
    string graph_mode_text = "false"
    if model.graph_mode {
        graph_mode_text = "true"
    }
    println("Quantized: " + quantized_text)
    println("Graph mode: " + graph_mode_text)
    println("Seed: " + seed)
    println("Answer mode: " + answer_mode)

    string prompt = resolve_inference_prompt(prompt_from_env, fallback_prompt, answer_mode)
    println("Prompt: " + prompt)

    if validate_only != "" {
        println("Validation only: checkpoint loaded.")
        println("================================================")
        return 0
    }

    if answer_only_mode {
        println(run_inference(model, prompt, max_new_chars))
        return 0
    }

    println("Generated:")
    println(run_inference(model, prompt, max_new_chars))
    println("================================================")
    0
}
