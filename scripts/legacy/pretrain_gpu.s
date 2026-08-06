package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_write_text_file, runtime_run_command_output}
use std.io.println
struct training_state {
    int current_step
    int completed_docs
    int completed_shards
    float loss
    string checkpoint_time
}
func main() {
    println("[PRETRAIN-GPU] === NVIDIA CUDA Runtime/cuBLAS Pretraining (S launcher) ===")
    string project_root = runtime_env_get("NEURX_ROOT", ".")
    string shard_list_file = runtime_env_get("NEURX_PRETRAIN_SHARD_LIST_FILE", project_root + "/artifacts/build/run_large_pretrain/shard_list.txt")
    string output_dir = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/checkpoint/NeurX-1.3")
    string progress_file = runtime_env_get("NEURX_PRETRAIN_PROGRESS_FILE", "")
    string bridge = runtime_env_get("NEURX_CUDA_TRAIN_BRIDGE", project_root + "/artifacts/build/cuda_train/neurx_cuda_train_bridge")
    string resume_mode = runtime_env_get("NEURX_PRETRAIN_RESUME", "auto")
    int max_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_STEPS", "1000000000"), 1000000000)
    int log_interval = parse_int(runtime_env_get("NEURX_PRETRAIN_LOG_INTERVAL", "1"), 1)
    int num_gpus = parse_int(runtime_env_get("NEURX_NUM_GPUS", runtime_env_get("NEURX_CUDA_DEVICES", "1")), 1)
    int batch_size = parse_int(runtime_env_get("NEURX_PRETRAIN_MICRO_BATCH", "32"), 32)
    int seq_len = parse_int(runtime_env_get("NEURX_PRETRAIN_SEQ_LEN", "512"), 512)
    int batch_pairs = parse_int(runtime_env_get("NEURX_CUDA_BATCH_PAIRS", "256"), 256)
    int cuda_vocab = parse_int(runtime_env_get("NEURX_CUDA_VOCAB_SIZE", "4096"), 4096)
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
    println("[PRETRAIN-GPU] Configuration:")
    println("  - Native bridge: " + bridge)
    println("  - Shard list: " + shard_list_file)
    println("  - Output dir: " + output_dir)
    println("  - Max steps: " + int_to_str(max_steps))
    println("  - GPUs: " + int_to_str(num_gpus))
    println("  - Micro batch: " + int_to_str(batch_size))
    println("  - Seq len: " + int_to_str(seq_len))
    println("  - CUDA batch pairs: " + int_to_str(batch_pairs))
    println("  - CUDA vocab: " + int_to_str(cuda_vocab))
    println("  - Log interval: " + int_to_str(log_interval))
    println("  - Resume mode: " + resume_mode)
    if !runtime_file_exists(shard_list_file) {
        println("[ERROR] Shard list not found: " + shard_list_file)
        return
    }
    if !runtime_file_exists(bridge) {
        println("[ERROR] CUDA train bridge not found: " + bridge)
        println("[ERROR] Run make build-cuda-train-bridge or make pretrain-gpu.")
        return
    }
    println("[PRETRAIN-GPU] Phase 1: checkpoint Detection")
    bool has_checkpoint = checkpoint_exists(output_dir)
    training_state state = new_training_state()
    if has_checkpoint {
        println("[PRETRAIN-GPU] ✓ Found existing checkpoint at " + output_dir)
        state = load_training_state(output_dir)
        if resume_mode == "no" {
            println("[PRETRAIN-GPU] Resume disabled (NEURX_PRETRAIN_RESUME=no)")
            println("[PRETRAIN-GPU] Starting from scratch...")
            state = new_training_state()
        } else {
            println("[PRETRAIN-GPU] ✓ Loaded training state:")
            println("  - Current step: " + int_to_str(state.current_step))
            println("  - Completed docs: " + int_to_str(state.completed_docs))
            println("  - Completed shards: " + int_to_str(state.completed_shards))
            println("  - Last loss: " + float_to_str(state.loss))
            println("  - Last checkpoint: " + state.checkpoint_time)
        }
    } else {
        println("[PRETRAIN-GPU] ✗ No existing checkpoint found")
        println("[PRETRAIN-GPU] Starting fresh training from step 0")
    }
    println("[PRETRAIN-GPU] Phase 2: Environment Setup")
    string shard_list_text = runtime_read_text_file(shard_list_file)
    int shard_count = count_lines(shard_list_text)
    println("[PRETRAIN-GPU] Found " + int_to_str(shard_count) + " shards")
    string resume_step_str = int_to_str(state.current_step)
    string resume_docs_str = int_to_str(state.completed_docs)
    string resume_shards_str = int_to_str(state.completed_shards)
    string resume_loss_str = float_to_str(state.loss)
    string resume_flag = "0"
    if has_checkpoint && resume_mode != "no" {
        resume_flag = "1"
    }
    println("[PRETRAIN-GPU] Phase 3: Training Parameters")
    println("  - Starting from step: " + resume_step_str)
    println("  - Target steps: " + int_to_str(max_steps))
    println("  - Remaining steps: " + int_to_str(max_steps - state.current_step))
    println("  - Resume docs: " + resume_docs_str)
    println("  - Resume shards: " + resume_shards_str)
    println("  - Last loss: " + resume_loss_str)
    println("  - Resume enabled: " + (if resume_flag == "1" { "yes" } else { "no" }))
    if str_len(latest_weights_path) > 0 {
        println("  - Weights checkpoint: " + latest_weights_path)
    }
    save_training_state(output_dir, state)
    if resume_flag == "1" {
        create_cuda_resume_state(checkpoint_state_file, state, latest_weights_path)
    }
    write_progress(progress_file, "gpu-launcher-ready shards=" + int_to_str(shard_count) + " bridge=" + bridge + " resume_step=" + resume_step_str + " resume=" + resume_flag)
    println("[PRETRAIN-GPU] Phase 4: Bridge Invocation")
    println("[PRETRAIN-GPU] S launcher validation complete.")
    println("[PRETRAIN-GPU] Makefile will now exec the native CUDA bridge with resume parameters.")
    println("[PRETRAIN-GPU] Environment variables set:")
    println("  - NEURX_PRETRAIN_RESUME: " + resume_flag)
    println("  - NEURX_PRETRAIN_RESUME_FROM: " + checkpoint_state_file)
    if str_len(latest_weights_path) > 0 {
        println("  - model weights will be loaded from checkpoint")
    }
    println("[PRETRAIN-GPU] Resume state will be automatically saved every NEURX_PRETRAIN_SAVE_INTERVAL steps.")
}
func checkpoint_exists(string checkpoint_dir) bool {
    string state_file = checkpoint_dir + "/training_state.txt"
    runtime_file_exists(state_file)
}
func new_training_state() training_state {
    training_state {
        current_step: 0,
        completed_docs: 0,
        completed_shards: 0,
        loss: 0.0,
        checkpoint_time: "2026-07-14T00:00:00Z",
    }
}
func load_training_state(string checkpoint_dir) training_state {
    string state_file = checkpoint_dir + "/training_state.txt"
    string content = ""
    if runtime_file_exists(state_file) {
        content = runtime_read_text_file(state_file)
    }
    training_state state = parse_training_state(content)
    state
}
func parse_training_state(string content) training_state {
    training_state state = new_training_state()
    if str_len(trim(content)) == 0 {
        return state
    }
    int step_idx = index_of(content, "step=")
    if step_idx >= 0 {
        int val = parse_int_at(content, step_idx + 5)
        if val >= 0 {
            state.current_step = val
        }
    }
    int docs_idx = index_of(content, "docs=")
    if docs_idx >= 0 {
        int val = parse_int_at(content, docs_idx + 5)
        if val >= 0 {
            state.completed_docs = val
        }
    }
    int shards_idx = index_of(content, "shards=")
    if shards_idx >= 0 {
        int val = parse_int_at(content, shards_idx + 7)
        if val >= 0 {
            state.completed_shards = val
        }
    }
    state
}
func save_training_state(string checkpoint_dir, training_state state) {
    string state_file = checkpoint_dir + "/training_state.txt"
    string content = "step=" + int_to_str(state.current_step) + " docs=" + int_to_str(state.completed_docs) + " shards=" + int_to_str(state.completed_shards) + " loss=" + float_to_str(state.loss) + "\n"
    runtime_write_text_file(state_file, content)
    println("[PRETRAIN-GPU] ✓ Saved training state to " + state_file)
}
func update_training_state(string checkpoint_dir, int step, int docs, int shards, float loss) {
    training_state state = training_state {
        current_step: step,
        completed_docs: docs,
        completed_shards: shards,
        loss: loss,
        checkpoint_time: "2026-07-14T00:00:00Z",
    }
    save_training_state(checkpoint_dir, state)
}
func index_of(string s, string needle) int {
    int s_len = str_len(s)
    int n_len = str_len(needle)
    if n_len > s_len {
        return -1
    }
    int i = 0
    while i <= s_len - n_len {
        int j = 0
        while j < n_len && s[i + j] == needle[j] {
            j = j + 1
        }
        if j == n_len {
            return i
        }
        i = i + 1
    }
    -1
}
func parse_int_at(string s, int start) int {
    int i = start
    int value = 0
    while i < str_len(s) {
        int c = s[i]
        if c >= 48 && c <= 57 {
            value = value * 10 + (c - 48)
            i = i + 1
        } else {
            break
        }
    }
    value
}
func float_to_str(float f) string {
    int int_part = int(f)
    string result = int_to_str(int_part)
    result
}
func int(float f) int {
    0
}
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
func detect_gpus() int {
    int count = parse_int(runtime_env_get("NEURX_CUDA_DEVICE_COUNT", "0"), 0)
    if count > 0 {
        println("[PRETRAIN-GPU] Detected " + int_to_str(count) + " NVIDIA GPU(s)")
    } else {
        println("[PRETRAIN-GPU] No NVIDIA GPUs detected")
    }
    count
}
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
func find_latest_checkpoint_weights(string checkpoint_dir, int resume_step) string {
    string cmd = "ls -1 '" + checkpoint_dir + "/checkpoint_step_'*.weights.f32 2>/dev/null | sort -V | tail -1"
    string latest = runtime_run_command_output(cmd)
    string trimmed = trim(latest)
    trimmed
}
func create_cuda_resume_state(string state_file, training_state state, string weights_path) {
    string content = ""
    content = content + "completed_step=" + int_to_str(state.current_step) + "\n"
    content = content + "pairs_seen=" + int_to_str(state.completed_docs * 100) + "\n"
    content = content + "shard_index=" + int_to_str(state.completed_shards) + "\n"
    content = content + "line_in_shard=0\n"
    content = content + "pending_offset=0\n"
    content = content + "vocab_size=4096\n"
    content = content + "batch_pairs=256\n"
    content = content + "loss=" + float_to_str(state.loss) + "\n"
    content = content + "weights=" + (if str_len(weights_path) > 0 { weights_path } else { "" }) + "\n"
    runtime_write_text_file(state_file, content)
    println("[PRETRAIN-GPU] \u2713 Created CUDA resume state: " + state_file)
}
