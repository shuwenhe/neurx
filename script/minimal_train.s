package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_run_command_output, runtime_write_text_file}
use std.io.println

func main() {
    println("[TRAINER] Initializing minimal_train.s...")
    string startup_marker_file = runtime_env_get("NEURX_STARTUP_MARKER_FILE", "")
    if str_len(startup_marker_file) > 0 {
        runtime_run_command_output("echo 'started' > " + shell_escape(startup_marker_file))
    }
    
    string project_root = runtime_env_get("NEURX_ROOT", ".")
    string model_name = runtime_env_get("NEURX_PRETRAIN_MODEL_NAME", "NeurX-1.3")
    string manifest_path = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    println("[TRAINER] Manifest: " + manifest_path)
    string shard_list_file = runtime_env_get("NEURX_PRETRAIN_SHARD_LIST_FILE", project_root + "/artifacts/build/run_large_pretrain/shard_list.sample.txt")
    string shard_dir = project_root + "/dataset/pretrain/shard"
    string output_dir = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/checkpoint/" + model_name)
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
    int text_token_cap = parse_int(runtime_env_get("NEURX_PRETRAIN_TEXT_TOKEN_CAP", "0"), 0)
    int json_scan_cap = parse_int(runtime_env_get("NEURX_PRETRAIN_JSON_SCAN_CAP", "0"), 0)
    int fast_prefix_mode = parse_int(runtime_env_get("NEURX_PRETRAIN_FAST_PREFIX", "0"), 0)
    int save_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_SAVE_INTERVAL", "100"), 100)
    int shard_docs_target = parse_int(runtime_env_get("NEURX_PRETRAIN_SHARD_DOCS_PER_FILE", "5000"), 5000)
    int shard_index_mode = parse_int(runtime_env_get("NEURX_PRETRAIN_SHARD_INDEX_MODE", "1"), 1)

    println("[TRAINER] Checking manifest exists...")
    if !runtime_file_exists(manifest_path) {
        println("[ERROR] Manifest not found: " + manifest_path)
        return
    }
    println("[TRAINER] Manifest found!")

    println("[TRAINER] Loading shard list...")
    int shard_count = parse_int(runtime_env_get("NEURX_PRETRAIN_SHARD_COUNT", "0"), 0)
    println("[TRAINER] Shard count from env: " + int_to_str(shard_count))
    string shard_list_text = ""
    if shard_count <= 0 && runtime_file_exists(shard_list_file) {
        println("[TRAINER] Reading shard list from: " + shard_list_file)
        shard_list_text = runtime_read_text_file(shard_list_file)
        println("[TRAINER] Shard list loaded, counting lines...")
    }
    if shard_count <= 0 && !has_non_space(shard_list_text) {
        println("[TRAINER] Discovering shards via find command...")
        string shard_cmd = "find " + shard_dir + " -maxdepth 1 -name 'shard_*.jsonl' -print | sort"
        shard_list_text = runtime_run_command_output(shard_cmd)
    }
    if shard_count <= 0 {
        shard_count = count_non_empty_lines(shard_list_text)
        println("[TRAINER] Counted shards: " + int_to_str(shard_count))
    }

    if shard_count == 0 {
        println("[ERROR] No shards found!")
        return
    }
    println("[TRAINER] Starting training with " + int_to_str(shard_count) + " shards")

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
    int last_shard_no = 0
    string last_shard = ""
    while shard_index < shard_count && step < max_steps {
        string shard_path = shard_path_for_index(shard_list_text, shard_list_file, shard_dir, shard_index, shard_index_mode)
        last_shard = shard_path
        last_shard_no = shard_index + 1
        string shard_slice = int_to_str(last_shard_no) + "/" + int_to_str(shard_count)
        string shard_name_start = extract_filename(shard_path)
        println("[shard] loading " + shard_slice + " " + shard_name_start)

        if !runtime_file_exists(shard_path) {
            println("[ERROR] Shard file not found: " + shard_path)
            shard_index = shard_index + 1
            continue
        }

        println("[" + shard_slice + "] " + shard_name_start)
        int shard_docs = 0
        int shard_tokens = 0
        int shard_start_step = step
        int next_line = 1
        bool shard_done = false
        int chunk_count = 0
        while !shard_done && step < max_steps && docs_seen < max_docs {
            chunk_count = chunk_count + 1
            string chunk_cmd = ""
            if fast_prefix_mode > 0 {
                chunk_cmd = "head -c " + int_to_str(json_scan_cap) + " " + shard_path
            } else {
                int last_line = next_line + line_chunk_size - 1
                if json_scan_cap > 0 {
                    chunk_cmd = "sed -n '" + int_to_str(next_line) + "," + int_to_str(last_line) + "p' " + shard_path + " | cut -c1-" + int_to_str(json_scan_cap)
                } else {
                    chunk_cmd = "sed -n '" + int_to_str(next_line) + "," + int_to_str(last_line) + "p' " + shard_path
                }
            }
            
            string chunk_text = runtime_run_command_output(chunk_cmd)
            if str_len(trim(chunk_text)) == 0 {
                shard_done = true
                shard_done = true
            } else {
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
                                    if should_log_step(step, log_interval) {
                                        println(training_progress_line(step, max_steps, docs_seen, tokens_seen, last_loss, last_lr, shard_name_start))
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
                                if should_log_step(step, log_interval) {
                                    println(training_progress_line(step, max_steps, docs_seen, tokens_seen, last_loss, last_lr, shard_name_start))
                                }
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

        string shard_name_complete = extract_filename(shard_path)
        println(shard_complete_line(last_shard_no, shard_count, shard_name_complete, shard_docs, shard_tokens, step - shard_start_step, step, docs_seen, tokens_seen, last_loss))
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
        if should_log_step(step, log_interval) {
            println(training_progress_line(step, max_steps, docs_seen, tokens_seen, last_loss, last_lr, extract_filename(last_shard)))
        }
    }

    string final_model_path = output_dir + "/final_model.neurx"
    string best_model_path = output_dir + "/best_model.neurx"
    string latest_checkpoint_file = output_dir + "/latest_checkpoint.txt"
    string resume_state_file = output_dir + "/resume_state.json"

    runtime_run_command_output("mkdir -p " + shell_escape(output_dir) + "; printf ok")
    string checkpoint_json = "{\"model_name\":\"" + model_name + "\",\"output_dir\":\"" + output_dir + "\",\"model_path\":\"" + final_model_path + "\",\"step\":" + int_to_str(step) + ",\"docs_seen\":" + int_to_str(docs_seen) + ",\"tokens_seen\":" + int_to_str(tokens_seen) + ",\"loss\":" + fmt_float(last_loss, 6) + ",\"last_slice\":" + int_to_str(last_shard_no) + ",\"last_shard\":\"" + last_shard + "\"}"
    runtime_write_text_file(resume_state_file, checkpoint_json + "\n")
    runtime_write_text_file(final_model_path, checkpoint_json + "\n")
    runtime_write_text_file(latest_checkpoint_file, final_model_path + "\n")
    if !runtime_file_exists(best_model_path) {
        runtime_run_command_output("ln -sf final_model.neurx " + shell_escape(best_model_path) + "; printf ok")
    }
    println("[pretrain] complete: step=" + int_to_str(step) + ", docs=" + int_to_str(docs_seen) + ", tokens=" + int_to_str(tokens_seen) + ", loss=" + fmt_float(last_loss, 6))
    println("[pretrain] model: " + model_name)
    println("[pretrain] output: " + output_dir)
    println("[pretrain] checkpoint: " + final_model_path)
}

func should_log_step(int step, int log_interval) bool {
    int interval = log_interval
    if interval < 1 {
        interval = 1
    }
    step == 1 || step == interval || step - (step / interval) * interval == 0
}

func training_progress_line(int step, int max_steps, int docs_seen, int tokens_seen, float loss, float lr, string shard_name) string {
    "[train] step=" + int_to_str(step) + "/" + int_to_str(max_steps) +
        " loss=" + fmt_float(loss, 6) +
        " lr=" + fmt_float(lr, 8) +
        " docs=" + int_to_str(docs_seen) +
        " tokens=" + int_to_str(tokens_seen) +
        " shard=" + shard_name
}

func shard_complete_line(int shard_no, int shard_count, string shard_name, int shard_docs, int shard_tokens, int shard_steps, int total_steps, int total_docs, int total_tokens, float loss) string {
    "[shard] done " + int_to_str(shard_no) + "/" + int_to_str(shard_count) +
        " shard=" + shard_name +
        " shard_steps=" + int_to_str(shard_steps) +
        " shard_docs=" + int_to_str(shard_docs) +
        " shard_tokens=" + int_to_str(shard_tokens) +
        " total_steps=" + int_to_str(total_steps) +
        " total_docs=" + int_to_str(total_docs) +
        " total_tokens=" + int_to_str(total_tokens) +
        " loss=" + fmt_float(loss, 6)
}

func shard_progress_bar(int done, int total, int width) string {
    int bar_total = total
    int bar_width = width
    int bar_done = done
    if bar_total < 1 {
        bar_total = 1
    }
    if bar_width < 1 {
        bar_width = 1
    }
    if bar_done < 0 {
        bar_done = 0
    }
    if bar_done > bar_total {
        bar_done = bar_total
    }
    int filled = (bar_done * bar_width) / bar_total
    if filled < 0 {
        filled = 0
    }
    if filled > bar_width {
        filled = bar_width
    }
    string out = "["
    int i = 0
    while i < filled {
        out = out + "="
        i = i + 1
    }
    i = filled
    while i < bar_width {
        out = out + "-"
        i = i + 1
    }
    out = out + "]"
    out
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    while i < str_len(s) {
        string ch = string_char(s[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "'"
    out
}

func count_non_empty_lines(string text) int {
    int count = 0
    int i = 0
    int n = str_len(text)
    bool in_line = false
    while i < n {
        if text[i] == 10 {
            if in_line {
                count = count + 1
            }
            in_line = false
        } else if text[i] != 13 && !is_space(text[i]) {
            in_line = true
        }
        i = i + 1
    }
    if in_line {
        count = count + 1
    }
    count
}

func has_non_space(string text) bool {
    int i = 0
    int n = str_len(text)
    while i < n {
        if !is_space(text[i]) {
            return true
        }
        i = i + 1
    }
    false
}

func shard_path_at(string shard_list, int index) string {
    int current = 0
    int start = 0
    int i = 0
    int n = str_len(shard_list)
    while i <= n {
        bool end_of_line = i == n || shard_list[i] == 10
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

func shard_path_for_index(string shard_list, string shard_list_file, string shard_dir, int index, int index_mode) string {
    if index_mode > 0 {
        return shard_dir + "/shard_" + zero_pad_int(index, 5) + ".jsonl"
    }
    if has_non_space(shard_list) {
        return shard_path_at(shard_list, index)
    }
    trim(runtime_run_command_output("sed -n '" + int_to_str(index + 1) + "p' " + shell_escape(shard_list_file)))
}

func zero_pad_int(int value, int width) string {
    string digits = int_to_str(value)
    string out = ""
    int missing = width - str_len(digits)
    int i = 0
    while i < missing {
        out = out + "0"
        i = i + 1
    }
    out + digits
}

func extract_filename(string path) string {
    int last_slash = -1
    int i = 0
    while i < str_len(path) {
        if path[i] == 47 {
            last_slash = i
        }
        i = i + 1
    }
    if last_slash >= 0 && last_slash < str_len(path) - 1 {
        return substring(path, last_slash + 1, str_len(path))
    }
    path
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
    int pos = find_string_prefix(json_line, pattern, 0, json_len)
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

func find_string_prefix(string s, string pattern, int start, int limit) int {
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
    int s_start = start
    int s_end = end
    if s_start < 0 {
        s_start = 0
    }
    if s_end > str_len(s) {
        s_end = str_len(s)
    }
    if s_end <= s_start {
        return ""
    }
    string out = ""
    int i = s_start
    while i < s_end {
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
    float val = value
    bool neg = val < 0.0
    if neg {
        val = 0.0 - val
    }
    int whole = 0
    while val >= 1.0 {
        val = val - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        val = val * 10.0
        int digit = 0
        while val >= 1.0 {
            val = val - 1.0
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

func progress_bar(int done, int total, int width) string {
    int w = width
    int t = total
    int d = done
    if w < 1 {
        w = 1
    }
    if t < 1 {
        t = 1
    }
    if d < 0 {
        d = 0
    }
    if d > t {
        d = t
    }
    int filled = (d * w) / t
    if filled < 0 {
        filled = 0
    }
    if filled > w {
        filled = w
    }
    string out = "["
    int i = 0
    while i < filled {
        out = out + "#"
        i = i + 1
    }
    while i < w {
        out = out + "-"
        i = i + 1
    }
    out = out + "]"
    out
}

func shard_progress_line(int shard_no, int shard_count, string shard_path, int shard_docs, int shard_docs_target) string {
    string label = "Shard " + int_to_str(shard_no) + "/" + int_to_str(shard_count)
    string bar = shard_progress_bar(shard_docs, shard_docs_target, 36)
    label + " " + bar + " docs=" + int_to_str(shard_docs) + "/" + int_to_str(shard_docs_target) + " path=" + shard_path
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
