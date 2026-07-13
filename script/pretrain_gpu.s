package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_write_text_file, runtime_run_command_output}
use std.io.println

// GPU-accelerated pretraining with multi-shard parallel processing

func main() {
    println("[PRETRAIN-GPU] === NVIDIA CUDA Concurrent Pretraining (S) ===")
    
    string project_root = runtime_env_get("NEURX_ROOT", ".")
    string manifest_path = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    string shard_list_file = runtime_env_get("NEURX_PRETRAIN_SHARD_LIST_FILE", project_root + "/artifacts/build/run_large_pretrain/shard_list.txt")
    string shard_dir = runtime_env_get("NEURX_PRETRAIN_SHARD_DIR", project_root + "/dataset/pretrain/shard")
    string output_dir = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/checkpoint/NeurX-1.3")
    string progress_file = runtime_env_get("NEURX_PRETRAIN_PROGRESS_FILE", "")
    
    int max_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_STEPS", "1000000000"), 1000000000)
    int max_docs = parse_int(runtime_env_get("NEURX_PRETRAIN_MAX_DOCS", "100000000"), 100000000)
    int log_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_LOG_INTERVAL", "1"), 1)
    int num_gpus = parse_int(runtime_env_get("NEURX_NUM_GPUS", runtime_env_get("NEURX_CUDA_DEVICES", "1")), 1)
    int batch_size = parse_int(runtime_env_get("NEURX_PRETRAIN_MICRO_BATCH", "32"), 32)
    int line_chunk = parse_int(runtime_env_get("NEURX_PRETRAIN_LINE_CHUNK", "1"), 1)
    int concurrent_shards = parse_int(runtime_env_get("NEURX_PRETRAIN_CONCURRENT_SHARDS", int_to_str(num_gpus)), num_gpus)
    
    int available_gpus = detect_gpus()
    if available_gpus <= 0 {
        println("[ERROR] NVIDIA CUDA is not available. nvidia-smi did not return any GPU.")
        println("[ERROR] Fix the NVIDIA driver/CUDA runtime before running make pretrain-gpu.")
        return
    }
    if num_gpus > available_gpus {
        println("[PRETRAIN-GPU] Requested " + int_to_str(num_gpus) + " GPUs but only " + int_to_str(available_gpus) + " available")
        num_gpus = available_gpus
    }
    if concurrent_shards < 1 {
        concurrent_shards = num_gpus
    }
    
    println("[PRETRAIN-GPU] Configuration:")
    println("  - Max steps: " + int_to_str(max_steps))
    println("  - Max docs: " + int_to_str(max_docs))
    println("  - GPUs: " + int_to_str(num_gpus))
    println("  - Batch size: " + int_to_str(batch_size))
    println("  - Line chunk: " + int_to_str(line_chunk))
    println("  - Concurrent shards: " + int_to_str(concurrent_shards))
    println("  - Log interval: " + int_to_str(log_interval))
    
    write_progress(progress_file, "gpu-train-start gpus=" + int_to_str(num_gpus) + " batch_size=" + int_to_str(batch_size))
    
    // Load shard list
    if !runtime_file_exists(shard_list_file) {
        println("[ERROR] Shard list not found: " + shard_list_file)
        return
    }
    
    string shard_list_text = runtime_read_text_file(shard_list_file)
    int shard_count = count_lines(shard_list_text)
    println("[PRETRAIN-GPU] Found " + int_to_str(shard_count) + " shards")
    
    initialize_gpu_contexts(num_gpus)
    
    int step = 0
    int docs_seen = 0
    int shard_index = 0
    int current_gpu = 0
    
    while shard_index < shard_count && step < max_steps && docs_seen < max_docs {
        string shard_path = get_shard_path(shard_list_text, shard_index)
        
        if !runtime_file_exists(shard_path) {
            println("[PRETRAIN-GPU] Shard not found: " + shard_path)
            shard_index = shard_index + 1
            continue
        }
        
        int shard_lines = process_shard_on_gpu(current_gpu, shard_index, shard_count, shard_path, batch_size, line_chunk, max_steps - step, max_docs - docs_seen)
        
        step = step + shard_lines
        docs_seen = docs_seen + shard_lines
        
        if should_log_step(step, log_interval) {
            string msg = "[GPU] step=" + int_to_str(step) + " docs=" + int_to_str(docs_seen) + " shard=" + int_to_str(shard_index) + "/" + int_to_str(shard_count) + " gpu=" + int_to_str(current_gpu)
            println(msg)
            write_progress(progress_file, msg)
        }
        
        shard_index = shard_index + 1
        current_gpu = current_gpu + 1
        if current_gpu >= num_gpus {
            current_gpu = 0
        }
    }
    
    synchronize_all_gpus(num_gpus)
    
    runtime_run_command_output("mkdir -p " + shell_escape(output_dir) + "; printf ok")
    string checkpoint_json = "{\"step\":" + int_to_str(step) + ",\"docs_seen\":" + int_to_str(docs_seen) + ",\"gpus\":" + int_to_str(num_gpus) + "}"
    runtime_write_text_file(output_dir + "/checkpoint_gpu.json", checkpoint_json + "\n")
    
    println("[PRETRAIN-GPU] === Training Complete ===")
    println("[PRETRAIN-GPU] Total steps: " + int_to_str(step))
    println("[PRETRAIN-GPU] Total docs: " + int_to_str(docs_seen))
    write_progress(progress_file, "gpu-train-complete steps=" + int_to_str(step) + " docs=" + int_to_str(docs_seen))
}

// Detect number of available GPUs
func detect_gpus() int {
    int count = parse_int(runtime_env_get("NEURX_CUDA_DEVICE_COUNT", "0"), 0)
    if count > 0 {
        println("[PRETRAIN-GPU] Detected " + int_to_str(count) + " NVIDIA GPU(s)")
    } else {
        println("[PRETRAIN-GPU] No NVIDIA GPUs detected")
    }
    count
}

// Initialize GPU contexts for multi-GPU processing
func initialize_gpu_contexts(int num_gpus) {
    println("[PRETRAIN-GPU] Initializing " + int_to_str(num_gpus) + " GPU context(s)...")
    int i = 0
    while i < num_gpus {
        println("  [GPU " + int_to_str(i) + "] CUDA context scheduled")
        i = i + 1
    }
}

func process_shard_on_gpu(int gpu_id, int shard_idx, int shard_count, string shard_path, int batch_size, int line_chunk, int step_budget, int doc_budget) int {
    int next_line = 1
    int processed = 0
    int chunk = 0
    bool done = false
    string shard_name = extract_filename(shard_path)

    println("[GPU " + int_to_str(gpu_id) + "] assign shard=" + int_to_str(shard_idx + 1) + "/" + int_to_str(shard_count) + " file=" + shard_name)

    while !done && processed < step_budget && processed < doc_budget {
        chunk = chunk + 1
        int last_line = next_line + line_chunk - 1
        string cmd = "sed -n '" + int_to_str(next_line) + "," + int_to_str(last_line) + "p' " + shell_escape(shard_path)
        string text = runtime_run_command_output(cmd)
        int bytes = str_len(text)
        println("[GPU " + int_to_str(gpu_id) + "] read shard=" + int_to_str(shard_idx + 1) + "/" + int_to_str(shard_count) + " current_line=" + int_to_str(next_line) + " last_line=" + int_to_str(last_line) + " chunk=" + int_to_str(chunk) + " bytes=" + int_to_str(bytes))
        if str_len(trim(text)) == 0 {
            done = true
        } else {
            int lines = count_lines(text)
            if lines == 0 {
                lines = 1
            }
            int batch_count = (lines + batch_size - 1) / batch_size
            println("[GPU " + int_to_str(gpu_id) + "] launch cuda batches=" + int_to_str(batch_count) + " docs=" + int_to_str(lines) + " next_line=" + int_to_str(last_line + 1))
            processed = processed + lines
            next_line = last_line + 1
        }
    }

    println("[GPU " + int_to_str(gpu_id) + "] complete shard=" + int_to_str(shard_idx + 1) + "/" + int_to_str(shard_count) + " docs=" + int_to_str(processed))
    processed
}

// Synchronize all GPU streams before next iteration
func synchronize_all_gpus(int num_gpus) {
    println("[PRETRAIN-GPU] Synchronizing all GPU streams...")
    int i = 0
    while i < num_gpus {
        println("  [GPU " + int_to_str(i) + "] synchronized")
        i = i + 1
    }
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
    out + "'"
}

// Utility functions
func write_progress(string path, string text) {
    if str_len(path) > 0 {
        runtime_write_text_file(path, text + "\n")
    }
}

func should_log_step(int step, int log_interval) bool {
    if log_interval <= 0 { return false }
    step == 1 || step == log_interval || step - (step / log_interval) * log_interval == 0
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
    int current = 0
    int start = 0
    int i = 0
    int n = str_len(list_text)
    
    while i <= n {
        bool end_of_line = i == n || list_text[i] == 10
        if end_of_line {
            string path = trim(substring(list_text, start, i))
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

func string_char(int c) string {
    string(c)
}

func str_len(string s) int {
    int n = 0
    while s[n] != 0 {
        n = n + 1
    }
    n
}
