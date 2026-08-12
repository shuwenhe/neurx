package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_write_text_file}
use std.io.println
func main() {
    println("[TRAINER] === Fast Training Loop (No Shell Commands) ===")
    string project_root = runtime_env_get("NEURX_ROOT", ".")
    string shard_list_file = runtime_env_get("NEURX_PRETRAIN_SHARD_LIST_FILE", project_root + "/artifacts/build/run_large_pretrain/shard_list.txt")
    string shard_dir = runtime_env_get("NEURX_PRETRAIN_SHARD_DIR", project_root + "/dataset/pretrain/shard")
    string progress_file = runtime_env_get("NEURX_PRETRAIN_PROGRESS_FILE", "")
    int max_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_STEPS", "1000"), 1000)
    int max_docs = parse_int(runtime_env_get("NEURX_PRETRAIN_MAX_DOCS", "100000000"), 100000000)
    int log_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_LOG_INTERVAL", "100"), 100)
    if !runtime_file_exists(shard_list_file) {
        println("[ERROR] Shard list not found: " + shard_list_file)
        return
    }
    string shard_list_text = runtime_read_text_file(shard_list_file)
    int shard_count = count_lines(shard_list_text)
    println("[TRAINER] Processing " + int_to_str(shard_count) + " shards")
    int step = 0
    int docs_seen = 0
    int shard_index = 0
    while shard_index < shard_count && step < max_steps && docs_seen < max_docs {
        string shard_path = get_shard_path(shard_list_text, shard_index)
        if !runtime_file_exists(shard_path) {
            println("[ERROR] Shard not found: " + shard_path)
            shard_index = shard_index + 1
            continue
        }
        println("[shard] " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " : " + extract_filename(shard_path))
        string full_content = runtime_read_text_file(shard_path)
        int content_len = str_len(full_content)
        int shard_lines = 0
        int shard_steps_before = step
        int i = 0
        while i < content_len && step < max_steps && docs_seen < max_docs {
            if full_content[i] == 10 {
                shard_lines = shard_lines + 1
                docs_seen = docs_seen + 1
                step = step + 1
                if should_log(step, log_interval) {
                    println("  step=" + int_to_str(step) + " docs=" + int_to_str(docs_seen) + " lines=" + int_to_str(shard_lines))
                    write_progress(progress_file, "step=" + int_to_str(step) + " docs=" + int_to_str(docs_seen))
                }
            }
            i = i + 1
        }
        int shard_steps = step - shard_steps_before
        println("[shard] complete: " + int_to_str(shard_index + 1) + "/" + int_to_str(shard_count) + " lines=" + int_to_str(shard_lines) + " steps=" + int_to_str(shard_steps))
        write_progress(progress_file, "shard-complete index=" + int_to_str(shard_index + 1) + " lines=" + int_to_str(shard_lines))
        shard_index = shard_index + 1
    }
    println("[TRAINER] === Training Complete ===")
    println("[TRAINER] Total steps: " + int_to_str(step))
    println("[TRAINER] Total docs: " + int_to_str(docs_seen))
    write_progress(progress_file, "training-complete steps=" + int_to_str(step) + " docs=" + int_to_str(docs_seen))
}
func count_lines(string text) int {
    int count = 0
    int i = 0
    while i < str_len(text) {
        if text[i] == 10 {
            count = count + 1
        }
        i = i + 1
    }
    count
}
func get_shard_path(string list_text, int index) string {
    int current_line = 0
    int line_start = 0
    int i = 0
    int list_len = str_len(list_text)
    while i < list_len && current_line <= index {
        if list_text[i] == 10 {
            if current_line == index {
                string result = ""
                int j = line_start
                while j < i && list_text[j] != 10 {
                    result = result + string_char(list_text[j])
                    j = j + 1
                }
                return result
            }
            current_line = current_line + 1
            line_start = i + 1
        }
        i = i + 1
    }
    if current_line == index {
        string result = ""
        int j = line_start
        while j < list_len {
            result = result + string_char(list_text[j])
            j = j + 1
        }
        return result
    }
    ""
}
func extract_filename(string path) string {
    int i = str_len(path) - 1
    while i >= 0 && path[i] != 47 {
        i = i - 1
    }
    i = i + 1
    string result = ""
    while i < str_len(path) && path[i] != 0 {
        result = result + string_char(path[i])
        i = i + 1
    }
    result
}
func should_log(int step, int interval) bool {
    if interval <= 0 { return false }
    step % interval == 0
}
func write_progress(string path, string text) {
    if str_len(path) > 0 {
        runtime_write_text_file(path, text + "\n")
    }
}
func string_char(int c) string {
    string(c)
}
func parse_int(string s, int default_val) int {
    if str_len(s) == 0 { return default_val }
    bool neg = false
    int i = 0
    int result = 0
    if s[0] == 45 {
        neg = true
        i = 1
    }
    while i < str_len(s) && s[i] >= 48 && s[i] <= 57 {
        result = result * 10 + (s[i] - 48)
        i = i + 1
    }
    if neg { result = -result }
    result
}
func int_to_str(int v) string {
    if v == 0 { return "0" }
    if v < 0 { return "-" + int_to_str(-v) }
    int_to_str(v / 10) + string_char((v % 10) + 48)
}
func str_len(string s) int {
    int i = 0
    while i < 1000000000 {
        if s[i] == 0 {
            return i
        }
        i = i + 1
    }
    -1
}
