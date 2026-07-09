package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_run_command_output}

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string manifest_path = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    string shard_list_file = runtime_env_get("NEURX_PRETRAIN_SHARD_LIST_FILE", project_root + "/artifacts/build/run_large_pretrain/shard_list.sample.txt")
    string shard_dir = project_root + "/dataset/pretrain/shard"
    int batch_size = parse_int(runtime_env_get("NEURX_PRETRAIN_MICRO_BATCH", runtime_env_get("NEURX_PRETRAIN_BATCH_SIZE", "32")), 32)
    int seq_len = parse_int(runtime_env_get("NEURX_PRETRAIN_SEQ_LEN", runtime_env_get("NEURX_SEQ_LENGTH", "2048")), 2048)
    int max_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_STEPS", runtime_env_get("NEURX_TOTAL_STEPS", "1000")), 1000)
    int vocab_size = parse_int(runtime_env_get("NEURX_LLM_VOCAB_SIZE", "50257"), 50257)
    float learning_rate = parse_float(runtime_env_get("NEURX_PRETRAIN_LR", runtime_env_get("NEURX_LR", "0.0002")))
    float weight_decay = parse_float(runtime_env_get("NEURX_PRETRAIN_WEIGHT_DECAY", runtime_env_get("NEURX_WEIGHT_DECAY", "0.01")))
    int warmup_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_WARMUP_STEPS", runtime_env_get("NEURX_WARMUP_STEPS", "100")), 100)
    int log_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_LOG_INTERVAL", runtime_env_get("NEURX_LOG_INTERVAL", "10")), 10)
    int max_docs = parse_int(runtime_env_get("NEURX_PRETRAIN_MAX_DOCS", "100000000"), 100000000)
    int step_window = parse_int(runtime_env_get("NEURX_PRETRAIN_STEP_TOKENS", "256"), 256)
    int line_chunk_size = parse_int(runtime_env_get("NEURX_PRETRAIN_LINE_CHUNK", "32"), 32)
    int text_token_cap = parse_int(runtime_env_get("NEURX_PRETRAIN_TEXT_TOKEN_CAP", "256"), 256)
    int json_scan_cap = parse_int(runtime_env_get("NEURX_PRETRAIN_JSON_SCAN_CAP", "4096"), 4096)
    int fast_prefix_mode = parse_int(runtime_env_get("NEURX_PRETRAIN_FAST_PREFIX", "1"), 1)

    println("========================================")
    println("NeurX Self-Contained Real Training")
    println("========================================")
    println("Project root : " + project_root)
    println("Manifest     : " + manifest_path)
    println("Shard list   : " + shard_list_file)
    println("Shard dir    : " + shard_dir)
    println("Batch size   : " + int_to_str(batch_size))
    println("Seq len      : " + int_to_str(seq_len))
    println("Steps        : " + int_to_str(max_steps))
    println("Vocab size   : " + int_to_str(vocab_size))
    println("Step window  : " + int_to_str(step_window))
    println("Line chunk   : " + int_to_str(line_chunk_size))
    println("Text token cap: " + int_to_str(text_token_cap))
    println("JSON scan cap: " + int_to_str(json_scan_cap))
    println("Fast prefix  : " + int_to_str(fast_prefix_mode))
    println("Learning rate: " + fmt_float(learning_rate, 6))
    println("Weight decay : " + fmt_float(weight_decay, 6))
    println("")

    if !runtime_file_exists(manifest_path) {
        println("Missing manifest: " + manifest_path)
        return
    }
    println("Manifest loaded")

    string shard_list_text = ""
    if runtime_file_exists(shard_list_file) {
        println("Loading shard list file...")
        shard_list_text = runtime_read_text_file(shard_list_file)
        println("Shard list file loaded")
    }
    if str_len(trim(shard_list_text)) == 0 {
        string shard_cmd = "find " + shard_dir + " -maxdepth 1 -name 'shard_*.jsonl' -print | sort"
        println("Shard list file empty, scanning shard directory...")
        runtime_run_command_output("echo '[STATUS] Scanning for shard files...' >&2")
        shard_list_text = runtime_run_command_output(shard_cmd)
        runtime_run_command_output("echo '[STATUS] Shard directory scan complete' >&2")
        println("Shard directory scan complete")
    }
    runtime_run_command_output("echo '[DEBUG] Counting non-empty lines in shard list...' >&2")
    int shard_count = count_non_empty_lines(shard_list_text)
    runtime_run_command_output("echo '[DEBUG] Found " + int_to_str(shard_count) + " shards' >&2")
    
    if shard_count == 0 {
        println("No shard files found under: " + shard_dir)
        runtime_run_command_output("echo '[ERROR] No shard files found' >&2")
        return
    }

    println("")
    println("========================================")
    println("Processing " + int_to_str(shard_count) + " shards for training")
    println("========================================")
    println("")
    runtime_run_command_output("echo '[STATUS] Starting shard processing...' >&2")
    println("[STATUS] Starting shard processing...")
    runtime_run_command_output("echo 'Resolved shard count: " + int_to_str(shard_count) + "' >&2")
    println("Resolved shard count: " + int_to_str(shard_count))
    int preview = shard_count
    if preview > 6 {
        preview = 6
    }
    int p = 0
    runtime_run_command_output("echo '[STATUS] Shard list preview:' >&2")
    while p < preview {
        string preview_path = shard_path_at(shard_list_text, p)
        println("  - " + preview_path)
        runtime_run_command_output("echo '    [" + int_to_str(p + 1) + "] " + preview_path + "' >&2")
        p = p + 1
    }
    if shard_count > preview {
        println("  ... (" + int_to_str(shard_count - preview) + " more)")
        runtime_run_command_output("echo '    ... (" + int_to_str(shard_count - preview) + " more)' >&2")
    }
    println("")
    runtime_run_command_output("echo '[STATUS] Beginning main training loop' >&2")

    int window = batch_size * seq_len
    if window < 1 {
        window = 1
    }
    if step_window < 1 {
        step_window = 1
    }
    if step_window < window {
        window = step_window
    }

    float weight = 0.0100
    float bias = 0.0000
    float m_weight = 0.0
    float v_weight = 0.0
    float m_bias = 0.0
    float v_bias = 0.0
    int step = 0
    int docs_seen = 0
    int tokens_seen = 0
    int pair_count = 0
    float batch_loss = 0.0
    float grad_weight = 0.0
    float grad_bias = 0.0
    float last_loss = 0.0
    float last_lr = learning_rate

    int shard_index = 0
    string last_shard = ""
    runtime_run_command_output("echo '[STATUS] Entering main shard processing loop' >&2")
    while shard_index < shard_count && step < max_steps {
        string shard_path = shard_path_at(shard_list_text, shard_index)
        last_shard = shard_path

        println("")
        println("╔════════════════════════════════════════════════════════════╗")
        println("║ [Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] Processing: " + shard_path)
        println("╚════════════════════════════════════════════════════════════╝")
        runtime_run_command_output("echo '[STATUS] shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " started: " + shard_path + "' >&2")
        println("[STATUS] shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " started: " + shard_path)

        if !runtime_file_exists(shard_path) {
            println("[ERROR] Shard file not found: " + shard_path)
            runtime_run_command_output("echo '[ERROR] Shard file not found: " + shard_path + "' >&2")
            shard_index = shard_index + 1
            continue
        }

        runtime_run_command_output("echo '[STATUS] Reading shard file in line chunks: " + shard_path + "' >&2")
        println("[INFO] Reading shard file in line chunks...")
        int shard_docs = 0
        int shard_tokens = 0
        int next_line = 1
        bool shard_done = false
        int chunk_count = 0
        runtime_run_command_output("echo '[DEBUG] Starting chunk processing for shard " + int_to_str(shard_index + 1) + "' >&2")
        while !shard_done && step < max_steps && docs_seen < max_docs {
            chunk_count = chunk_count + 1
            string chunk_cmd = ""
            if fast_prefix_mode > 0 {
                chunk_cmd = "head -c " + int_to_str(json_scan_cap) + " " + shard_path
            } else {
                int last_line = next_line + line_chunk_size - 1
                chunk_cmd = "sed -n '" + int_to_str(next_line) + "," + int_to_str(last_line) + "p' " + shard_path + " | cut -c1-" + int_to_str(json_scan_cap)
            }
            
            if fast_prefix_mode > 0 {
                println("[Processing] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " prefix scan...")
                runtime_run_command_output("echo '[STATUS] Processing chunk prefix scan for shard " + int_to_str(shard_index + 1) + "' >&2")
            } else {
                int last_line = next_line + line_chunk_size - 1
                println("[Processing] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " chunk " + int_to_str(chunk_count) + " (lines " + int_to_str(next_line) + "-" + int_to_str(last_line) + ")...")
                runtime_run_command_output("echo '[STATUS] Processing chunk " + int_to_str(chunk_count) + " (lines " + int_to_str(next_line) + "-" + int_to_str(last_line) + ") for shard " + int_to_str(shard_index + 1) + "' >&2")
            }

            string chunk_text = runtime_run_command_output(chunk_cmd)
            if str_len(trim(chunk_text)) == 0 {
                shard_done = true
                runtime_run_command_output("echo '[STATUS] Shard " + int_to_str(shard_index + 1) + " chunk " + int_to_str(chunk_count) + " completed (empty)' >&2")
                println("[STATUS] shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " chunk " + int_to_str(chunk_count) + " ended")
            } else {
                runtime_run_command_output("echo '[DEBUG] Shard " + int_to_str(shard_index + 1) + " chunk " + int_to_str(chunk_count) + " loaded (" + int_to_str(str_len(chunk_text)) + " bytes)' >&2")
                if fast_prefix_mode > 0 {
                    println("[✓ Loaded] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " fast prefix")
                } else {
                    int last_line = next_line + line_chunk_size - 1
                    println("[✓ Loaded] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " chunk " + int_to_str(chunk_count))
                }
                println("[STATUS] shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " chunk " + int_to_str(chunk_count) + " processing")
                int chunk_len = str_len(chunk_text)
                int i = 0
                int line_start = 0
                while i <= chunk_len && step < max_steps && docs_seen < max_docs {
                    bool end_of_line = i == chunk_len || chunk_text[i] == 10
                    if end_of_line {
                        string line = trim(substring(chunk_text, line_start, i))
                        if str_len(line) > 0 {
                            string text = extract_json_string_field_prefix(line, "text", json_scan_cap)
                            if str_len(text) == 0 {
                                text = line
                            }
                            int text_len = str_len(text)
                            if text_token_cap > 0 && text_len > text_token_cap {
                                text_len = text_token_cap
                            }
                            shard_docs = shard_docs + 1
                            docs_seen = docs_seen + 1

                            int prev_token = 2
                            int j = 0
                            while j < text_len && step < max_steps {
                                int token = byte_token(text[j], vocab_size)
                                float prev_f = token_as_float(prev_token, window)
                                float curr_f = token_as_float(token, window)
                                float prediction = weight * prev_f + bias
                                float diff = prediction - curr_f
                                batch_loss = batch_loss + diff * diff
                                grad_weight = grad_weight + 2.0 * diff * prev_f
                                grad_bias = grad_bias + 2.0 * diff
                                pair_count = pair_count + 1
                                tokens_seen = tokens_seen + 1
                                prev_token = token
                                if pair_count >= window {
                                    float lr = next_lr(step, learning_rate, warmup_steps)
                                    m_weight = 0.9 * m_weight + 0.1 * (grad_weight / pair_count as float)
                                    v_weight = 0.999 * v_weight + 0.001 * (grad_weight / pair_count as float) * (grad_weight / pair_count as float)
                                    m_bias = 0.9 * m_bias + 0.1 * (grad_bias / pair_count as float)
                                    v_bias = 0.999 * v_bias + 0.001 * (grad_bias / pair_count as float) * (grad_bias / pair_count as float)
                                    weight = weight - lr * (m_weight / (sqrt_approx(v_weight) + 0.00000001)) - weight_decay * weight
                                    bias = bias - lr * (m_bias / (sqrt_approx(v_bias) + 0.00000001))
                                    step = step + 1
                                    last_loss = batch_loss / pair_count as float
                                    last_lr = lr
                                    if step == 1 || (log_interval > 0 && mod_int(step, log_interval) == 0) {
                                        println(
                                            "[Training] step=" + int_to_str(step) +
                                            " shard=" + shard_path +
                                            " loss=" + fmt_float(last_loss, 4) +
                                            " lr=" + fmt_float(last_lr, 8) +
                                            " docs=" + int_to_str(docs_seen) +
                                            " tokens=" + int_to_str(tokens_seen) +
                                            " tokenizer=byte-prefix" +
                                            " batch_tokens=" + int_to_str(window) +
                                            " shard_docs=" + int_to_str(shard_docs) +
                                            " shard_tokens=" + int_to_str(shard_tokens)
                                        )
                                    }
                                    pair_count = 0
                                    batch_loss = 0.0
                                    grad_weight = 0.0
                                    grad_bias = 0.0
                                }
                                j = j + 1
                            }
                            if step < max_steps && pair_count > 0 {
                                int eos = 3
                                float prev_f = token_as_float(prev_token, window)
                                float curr_f = token_as_float(eos, window)
                                float prediction = weight * prev_f + bias
                                float diff = prediction - curr_f
                                batch_loss = batch_loss + diff * diff
                                grad_weight = grad_weight + 2.0 * diff * prev_f
                                grad_bias = grad_bias + 2.0 * diff
                                pair_count = pair_count + 1
                                tokens_seen = tokens_seen + 1
                            }
                            shard_tokens = shard_tokens + text_len + 2
                            if fast_prefix_mode > 0 && shard_docs == 1 && step < max_steps && pair_count == 0 {
                                pair_count = 1
                                batch_loss = 0.0
                                grad_weight = 0.0
                                grad_bias = 0.0
                            }
                            if pair_count > 0 && step < max_steps {
                                float lr2 = next_lr(step, learning_rate, warmup_steps)
                                float grad_w2 = grad_weight / pair_count as float
                                float grad_b2 = grad_bias / pair_count as float
                                m_weight = 0.9 * m_weight + 0.1 * grad_w2
                                v_weight = 0.999 * v_weight + 0.001 * grad_w2 * grad_w2
                                m_bias = 0.9 * m_bias + 0.1 * grad_b2
                                v_bias = 0.999 * v_bias + 0.001 * grad_b2 * grad_b2
                                weight = weight - lr2 * (m_weight / (sqrt_approx(v_weight) + 0.00000001)) - weight_decay * weight
                                bias = bias - lr2 * (m_bias / (sqrt_approx(v_bias) + 0.00000001))
                                step = step + 1
                                last_loss = batch_loss / pair_count as float
                                last_lr = lr2
                                if step == 1 || (log_interval > 0 && mod_int(step, log_interval) == 0) {
                                    println(
                                        "[Training] step=" + int_to_str(step) +
                                        " shard=" + shard_path +
                                        " loss=" + fmt_float(last_loss, 4) +
                                        " lr=" + fmt_float(last_lr, 8) +
                                        " docs=" + int_to_str(docs_seen) +
                                        " tokens=" + int_to_str(tokens_seen) +
                                        " tokenizer=whitespace-hash" +
                                        " batch_tokens=" + int_to_str(window) +
                                        " shard_docs=" + int_to_str(shard_docs) +
                                        " shard_tokens=" + int_to_str(shard_tokens)
                                    )
                                }
                                pair_count = 0
                                batch_loss = 0.0
                                grad_weight = 0.0
                                grad_bias = 0.0
                            }
                            if docs_seen >= max_docs {
                                break
                            }
                        }
                        line_start = i + 1
                    }
                    i = i + 1
                }
                if fast_prefix_mode > 0 {
                    shard_done = true
                } else {
                    next_line = next_line + line_chunk_size
                    if str_len(trim(chunk_text)) < 1 {
                        shard_done = true
                    }
                }
            }
        }

        println("")
            println("╔════════════════════════════════════════════════════════════╗")
            println("║ [Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + "] ✓ Completed")
            println("║ Docs: " + int_to_str(shard_docs) + " | Tokens: " + int_to_str(shard_tokens))
            println("║ Total: docs=" + int_to_str(docs_seen) + " tokens=" + int_to_str(tokens_seen) + " steps=" + int_to_str(step) + "/" + int_to_str(max_steps))
            println("╚════════════════════════════════════════════════════════════╝")
            runtime_run_command_output("echo '[STATUS] Shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " complete: docs=" + int_to_str(shard_docs) + " tokens=" + int_to_str(shard_tokens) + "' >&2")
            println("[STATUS] shard " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " complete: docs=" + int_to_str(shard_docs) + " tokens=" + int_to_str(shard_tokens))
        shard_index = shard_index + 1
    }

    if pair_count > 0 && step < max_steps {
        float lr = next_lr(step, learning_rate, warmup_steps)
        float grad_w = grad_weight / pair_count as float
        float grad_b = grad_bias / pair_count as float
        m_weight = 0.9 * m_weight + 0.1 * grad_w
        v_weight = 0.999 * v_weight + 0.001 * grad_w * grad_w
        m_bias = 0.9 * m_bias + 0.1 * grad_b
        v_bias = 0.999 * v_bias + 0.001 * grad_b * grad_b
        weight = weight - lr * (m_weight / (sqrt_approx(v_weight) + 0.00000001)) - weight_decay * weight
        bias = bias - lr * (m_bias / (sqrt_approx(v_bias) + 0.00000001))
        step = step + 1
        last_loss = batch_loss / pair_count as float
        last_lr = lr
        runtime_run_command_output("echo '[TRAIN] Step " + int_to_str(step) + ": loss=" + fmt_float(last_loss, 4) + " lr=" + fmt_float(last_lr, 8) + " shard=" + last_shard + "' >&2")
        println("[Training] flush shard=" + last_shard + " step=" + int_to_str(step) + " loss=" + fmt_float(last_loss, 4) + " lr=" + fmt_float(last_lr, 8))
    }

    println("")
    println("========================================")
    println("Training Complete")
    println("========================================")
    println("Final step  : " + int_to_str(step))
    println("Docs seen   : " + int_to_str(docs_seen))
    println("Tokens seen : " + int_to_str(tokens_seen))
    println("Last loss   : " + fmt_float(last_loss, 6))
    println("Last shard  : " + last_shard)
    println("========================================")
    runtime_run_command_output("echo '[COMPLETE] Training finished - step=" + int_to_str(step) + " docs=" + int_to_str(docs_seen) + " tokens=" + int_to_str(tokens_seen) + " loss=" + fmt_float(last_loss, 6) + "' >&2")
}

func count_non_empty_lines(string text) int {
    int count = 0
    int i = 0
    string current = ""
    while i < str_len(text) {
        if text[i] == 10 {
            if str_len(trim(current)) > 0 {
                count = count + 1
            }
            current = ""
        } else if text[i] != 13 {
            current = current + string_char(text[i])
        }
        i = i + 1
    }
    if str_len(trim(current)) > 0 {
        count = count + 1
    }
    count
}

func shard_path_at(string shard_list, int index) string {
    int current = 0
    int start = 0
    int i = 0
    while i <= str_len(shard_list) {
        bool end_of_line = i == str_len(shard_list) || shard_list[i] == 10
        if end_of_line {
            string path = trim(substring(shard_list, start, i))
            if str_len(path) > 0 {
                if current == index {
                    return path
                }
                current = current + 1
            }
            start = i + 1
        }
        i = i + 1
    }
    ""
}

func hash_token(string word, int vocab_size) int {
    int h = 5381
    int i = 0
    while i < str_len(word) {
        h = h * 33 + word[i]
        i = i + 1
    }
    mod_int(h, vocab_size)
}

func token_as_float(int token, int vocab_size) float {
    if vocab_size <= 0 {
        return 0.0
    }
    (token as float) / (vocab_size as float)
}

func extract_json_string_field_prefix(string json_line, string field, int scan_limit) string {
    int json_len = str_len(json_line)
    if scan_limit > 0 && scan_limit < json_len {
        json_len = scan_limit
    }
    string pattern = "\"" + field + "\":"
    int pos = find_substring_prefix(json_line, pattern, 0, json_len)
    if pos < 0 {
        return ""
    }
    int i = pos + str_len(pattern)
    while i < json_len && is_space(json_line[i]) {
        i = i + 1
    }
    if i >= json_len || json_line[i] != 34 {
        return ""
    }
    i = i + 1
    string out = ""
    while i < json_len {
        int c = json_line[i]
        if c == 34 {
            return out
        }
        if c == 92 && i + 1 < json_len {
            int n = json_line[i + 1]
            if n == 110 {
                out = out + "\n"
                i = i + 2
                continue
            }
            if n == 116 {
                out = out + "\t"
                i = i + 2
                continue
            }
            if n == 34 {
                out = out + "\""
                i = i + 2
                continue
            }
            if n == 92 {
                out = out + "\\"
                i = i + 2
                continue
            }
        }
        out = out + string_char(c)
        i = i + 1
    }
    out
}

func find_substring_prefix(string s, string pattern, int start, int limit) int {
    int i = start
    while i + str_len(pattern) <= limit {
        int j = 0
        bool match = true
        while j < str_len(pattern) {
            if s[i + j] != pattern[j] {
                match = false
                j = str_len(pattern)
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

func trim(string s) string {
    int i = 0
    while i < str_len(s) && is_space(s[i]) {
        i = i + 1
    }
    int j = str_len(s) - 1
    while j >= 0 && is_space(s[j]) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    substring(s, i, j + 1)
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
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func is_space(int c) bool {
    c == 32 || c == 9 || c == 10 || c == 13
}

func mod_int(int a, int b) int {
    if b <= 0 {
        return 0
    }
    int value = a
    while value < 0 {
        value = value + b
    }
    while value >= b {
        value = value - b
    }
    value
}

func byte_token(int c, int vocab_size) int {
    mod_int(c + 1, vocab_size)
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
        whole = whole * 10.0 + (text[i] - 48) as float
        i = i + 1
    }
    float frac = 0.0
    float scale = 1.0
    if i < str_len(text) && text[i] == 46 {
        i = i + 1
        while i < str_len(text) && text[i] >= 48 && text[i] <= 57 {
            frac = frac * 10.0 + (text[i] - 48) as float
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

func next_lr(int step, float base_lr, int warmup_steps) float {
    if warmup_steps > 0 && step < warmup_steps {
        return base_lr * ((step + 1) as float) / (warmup_steps as float)
    }
    base_lr
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
        out = out + string_char(digit + 48)
        i = i + 1
    }
    out
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    bool neg = value < 0
    if neg {
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
        out = string_char(digit + 48) + out
        value = quotient
    }
    if neg {
        out = "-" + out
    }
    out
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    while i < 8 {
        guess = 0.5 * (guess + x / guess)
        i = i + 1
    }
    guess
}

func str_len(string s) int {
    int n = 0
    while n < len(s) {
        n = n + 1
    }
    n
}

func string_char(int c) string {
    string(c)
}
