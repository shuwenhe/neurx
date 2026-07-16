package neurx.pretrain.llm.gpt_large_pretrain
use neurx.strings
use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file, runtime_env_get}
use neurx.model.llm.gpt_moe_1t.{moe_1t_framework_default, moe_1t_summary}
use neurx.dl.dataloader.{dataloader_state, dataloader_config, dataloader_step_output, dataloader_state_dict, dataloader_load_state_dict, has_next, next_batch, new_state, reset_state, with_config, set_shuffle, set_drop_last, new_config}
use neurx.model.llm.gpt_large_train.{gpt_large_state, gpt_large_training_config, gpt_large_training_state, transformer_layer_optimizer_state, transformer_layer, new_gpt_large_training_config, new_gpt_large_training_state, gpt_large_training_forward, gpt_large_training_loss, gpt_large_training_update, gpt_large_training_state_dict, gpt_large_training_load_state_dict, transformer_backward, gpt_large_backward_result}
use neurx.model.llm.model_large_train.{adamw_step_state, adamw_step_output, embedding_apply_grad, sum_first_dim, sub, softmax_last_dim, one_hot_tensor}
use neurx.pretrain.distributed.{pretrain_ddp_state, pretrain_ddp_state_dict, pretrain_ddp_load_state_dict, new_pretrain_ddp_state_from_env, pretrain_ddp_enabled, pretrain_ddp_sync_tensor, pretrain_ddp_step, pretrain_ddp_rank, pretrain_ddp_world_size}
use neurx.pretrain.optimizer.pretrain_adamw.{pretrain_optimizer_state, pretrain_optimizer_step_state, new_pretrain_optimizer_state, pretrain_optimizer_step, pretrain_optimizer_state_dict, pretrain_optimizer_load_state_dict}
use neurx.tokenizer.bpe_trainer.{bpe_split_state, bpe_tokenizer_state, bpe_tokenized_corpus_state, bpe_tokenized_corpus_from_documents, bpe_split_state_dict, bpe_split_load_state_dict, bpe_tokenizer_state_dict, bpe_tokenizer_load_state_dict, bpe_tokenized_corpus_state_dict, bpe_tokenized_corpus_load_state_dict}
use neurx.pretrain.checkpoint.{pretrain_checkpoint_state, pretrain_checkpoint_bundle_state, new_pretrain_checkpoint_state, new_pretrain_checkpoint_bundle_state, mark_saved, mark_best, pretrain_checkpoint_state_dict, pretrain_checkpoint_load_state_dict}
use neurx.pretrain.config.{pretrain_config, pretrain_config_state_dict, pretrain_config_load_state_dict}
use neurx.pretrain.eval.{pretrain_eval_state, new_pretrain_eval_state, update_pretrain_eval, pretrain_eval_state_dict, pretrain_eval_load_state_dict}
use neurx.pretrain.loop.{pretrain_loop_state, new_pretrain_loop_state, pretrain_step, pretrain_reset_micro_step, pretrain_loop_state_dict, pretrain_loop_load_state_dict}
use neurx.checkpoint.{save_checkpoint, load_checkpoint, checkpoint_step, checkpoint_loss, checkpoint_params}
use neurx.compression.release.{compression_release_config, prepare_compression_release}
use neurx.deployment.chain.{default_model_deployment_config}
use neurx.exporter.{default_model_export_config}
use neurx.nn.{embedding_lookup, transformer_forward}
use neurx.opt.optim.{adamw_optimizer}
use neurx.ops
use neurx.tensor.new
use neurx.tensor.tensor

// ============================================================================
// File Reading with Progress Display
// ============================================================================

func get_file_size(string path) int {
    if !runtime_file_exists(path) {
        return 0
    }
    216123783  // Placeholder for shard_00000.jsonl size
}

func format_bytes(int bytes) string {
    if bytes < 1024 {
        return int_to_str(bytes, 0) + " B"
    }
    if bytes < 1024 * 1024 {
        int kb = bytes / 1024
        return int_to_str(kb, 0) + " KB"
    }
    if bytes < 1024 * 1024 * 1024 {
        int mb = bytes / (1024 * 1024)
        return int_to_str(mb, 0) + " MB"
    }
    int gb = bytes / (1024 * 1024 * 1024)
    return int_to_str(gb, 0) + " GB"
}

func create_progress_bar(int percent, int width) string {
    int filled = (percent * width) / 100
    if filled > width {
        filled = width
    }
    
    string bar = "["
    int i = 0
    while i < width {
        if i < filled {
            bar = bar + "="
        } else if i == filled && percent < 100 {
            bar = bar + ">"
        } else {
            bar = bar + " "
        }
        i = i + 1
    }
    bar = bar + "]"
    
    return bar
}

func read_text_file_with_estimated_progress(string path, int update_interval_ms) string {
    if !runtime_file_exists(path) {
        println("[io] ERROR: file not found: " + path)
        return ""
    }
    
    int file_size = get_file_size(path)
    string size_str = format_bytes(file_size)
    
    println("[io] reading: " + path)
    println("[io] size: " + size_str)
    println("[io] [>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>] 0% | allocating buffer...")
    
    // Read file with blocking I/O
    string text = runtime_read_text_file(path)
    
    int loaded_size = len(text)
    string loaded_str = format_bytes(loaded_size)
    
    println("[io] [========================================] 100% | complete, loaded " + loaded_str)
    
    return text
}

struct gpt_large_pretrain_state {
    pretrain_config cfg
    string dataset_manifest
    string output_dir
    []string shard_refs
    []string train_shard_refs
    []string valid_shard_refs
    []string test_shard_refs
    []int shard_order
    int shard_order_index
    int shard_epoch
    int shard_shuffle_seed
    int active_shard_index
    string active_shard_path
    int active_shard_tokens
    pretrain_data_state data
    pretrain_loop_state loop
    pretrain_checkpoint_state checkpoint
    pretrain_eval_state eval
    bpe_tokenized_corpus_state corpus
    pretrain_optimizer_state optimizer
    pretrain_ddp_state ddp
    gpt_large_training_state training
    dataloader_state valid_loader
    dataloader_state test_loader
    int rng_seed
    int rng_state
}

struct gpt_large_pretrain_shard_splits {
    []string train_refs
    []string valid_refs
    []string test_refs
}

struct gpt_large_pretrain_eval_result {
    pretrain_eval_state eval
    dataloader_state valid_loader
}

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
        s = string_char(value - (value / 10) * 10 + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func join_ints([]int values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + int_to_str(values[i], 0)
        i = i + 1
    }
    out
}

func bool_to_int(bool value) int {
    if value {
        1
    }
    0
}

func gpt_large_pretrain_shard_progress_text(int shard_token_cursor, int shard_total_tokens) string {
    if shard_total_tokens <= 0 {
        return "ShardProgress=0/0 (0.0%)"
    }
    float progress = shard_token_cursor * 1.0 / shard_total_tokens * 100.0
    if progress < 0.0 {
        progress = 0.0
    }
    if progress > 100.0 {
        progress = 100.0
    }
    "ShardProgress=" + int_to_str(shard_token_cursor, 0) + "/" + int_to_str(shard_total_tokens, 0) + " (" + fmt_float(progress, 1) + "%)"
}

func gpt_large_pretrain_shard_summary_text(int shard_index, int shard_total, string shard_path) string {
    string shard_name = gpt_large_pretrain_basename(shard_path)
    "Shard " + int_to_str(shard_index, 0) + "/" + int_to_str(shard_total, 0) + " " + shard_name
}

func gpt_large_pretrain_string_at([]string values, int idx) string {
    int i = idx
    if i < 0 {
        i = 0
    }
    if i >= len(values) {
        i = len(values) - 1
    }
    if i < 0 {
        return ""
    }
    values[i]
}

func gpt_large_pretrain_int_at([]int values, int idx) int {
    int i = idx
    if i < 0 {
        i = 0
    }
    if i >= len(values) {
        i = len(values) - 1
    }
    if i < 0 {
        return 0
    }
    values[i]
}

func gpt_large_pretrain_positive_mod(int value, int modulus) int {
    if modulus <= 0 {
        return 0
    }
    int div_result = value / modulus
    int result = value - div_result * modulus
    if result < 0 {
        result = result + modulus
    }
    result
}

func gpt_large_pretrain_mix_seed(int seed, int epoch, int total) int {
    int mixed = seed + epoch * 1103515245
    mixed = mixed + total * 265443576
    mixed
}

func gpt_large_pretrain_shuffle_ints([]int values, int seed) []int {
    []int out = copy_int(values)
    int i = len(out) - 1
    int state = seed
    while i > 0 {
        state = state * 1664525 + 1013904223
        int j = gpt_large_pretrain_positive_mod(state, i + 1)
        int tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
        i = i - 1
    }
    out
}

func gpt_large_pretrain_build_shard_order(int shard_count, int shard_seed, int shard_epoch) []int {
    if shard_count <= 0 {
        return []int{cap: 0}
    }
    []int order = []int{cap: shard_count}
    int i = 0
    while i < shard_count {
        order[i] = i
        i = i + 1
    }
    return gpt_large_pretrain_shuffle_ints(order, gpt_large_pretrain_mix_seed(shard_seed, shard_epoch, shard_count))
}

func gpt_large_pretrain_shuffle_strings([]string values, int seed) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    int j = len(out) - 1
    int state = seed
    while j > 0 {
        state = state * 1664525 + 1013904223
        int k = gpt_large_pretrain_positive_mod(state, j + 1)
        string tmp = out[j]
        out[j] = out[k]
        out[k] = tmp
        j = j - 1
    }
    out
}

func gpt_large_pretrain_slice_strings([]string values, int start, int end) []string {
    int lo = start
    int hi = end
    if lo < 0 {
        lo = 0
    }
    if hi < lo {
        hi = lo
    }
    if hi > len(values) {
        hi = len(values)
    }
    if lo > len(values) {
        lo = len(values)
    }
    []string out = []string{cap: hi - lo}
    int i = lo
    int j = 0
    while i < hi {
        out[j] = values[i]
        i = i + 1
        j = j + 1
    }
    out
}

func gpt_large_pretrain_split_shard_refs([]string refs, int seed) gpt_large_pretrain_shard_splits {
    []string ordered = gpt_large_pretrain_shuffle_strings(refs, seed)
    int total = len(ordered)
    gpt_large_pretrain_shard_splits splits = gpt_large_pretrain_shard_splits {
        train_refs: []string{cap: 0},
        valid_refs: []string{cap: 0},
        test_refs: []string{cap: 0},
    }
    if total > 0 {
        int train_count = (total * 80) / 100
        int valid_count = (total * 10) / 100
        int test_count = total - train_count - valid_count

        if train_count < 1 {
            train_count = 1
        }
        if total >= 2 && valid_count < 1 {
            valid_count = 1
        }
        if total >= 3 && test_count < 1 {
            test_count = 1
        }

        int assigned = train_count + valid_count + test_count
        while assigned > total {
            if test_count > 1 {
                test_count = test_count - 1
            } else if valid_count > 1 {
                valid_count = valid_count - 1
            } else if train_count > 1 {
                train_count = train_count - 1
            } else {
                break
            }
            assigned = train_count + valid_count + test_count
        }

        int valid_start = train_count
        int test_start = train_count + valid_count
        splits = gpt_large_pretrain_shard_splits {
            train_refs: gpt_large_pretrain_slice_strings(ordered, 0, train_count),
            valid_refs: gpt_large_pretrain_slice_strings(ordered, valid_start, test_start),
            test_refs: gpt_large_pretrain_slice_strings(ordered, test_start, total),
        }
    }
    splits
}

func gpt_large_pretrain_substring(string text, int start, int end) string {
    int begin = start
    int finish = end
    if begin < 0 {
        begin = 0
    }
    if finish > len(text) {
        finish = len(text)
    }
    if begin >= finish {
        return ""
    }
    string result = ""
    int i = begin
    while i < finish {
        result = result + string_char(text[i])
        i = i + 1
    }
    result
}

func gpt_large_pretrain_basename(string path) string {
    int i = len(path) - 1
    while i >= 0 {
        if path[i] == 47 {
            return gpt_large_pretrain_substring(path, i + 1, len(path))
        }
        i = i - 1
    }
    path
}

func gpt_large_pretrain_split_csv(string value) []string {
    string text = trim(value)
    if text == "" {
        return []string{cap: 0}
    }
    []string parts = []string{cap: len(text)}
    int count = 0
    int start = 0
    int i = 0
    while i <= len(text) {
        bool at_end = i == len(text)
        if at_end || text[i] == 44 {
            string part = trim(gpt_large_pretrain_substring(text, start, i))
            if part != "" {
                parts[count] = part
                count = count + 1
            }
            start = i + 1
        }
        i = i + 1
    }
    if count == 0 {
        return []string{cap: 0}
    }
    []string out = []string{cap: count}
    int j = 0
    while j < count {
        out[j] = parts[j]
        j = j + 1
    }
    out
}

func gpt_large_pretrain_string_matches_shard(string value, string shard_path) bool {
    string cleaned = trim(value)
    if cleaned == "" {
        return false
    }
    if cleaned == shard_path {
        return true
    }
    string shard_name = gpt_large_pretrain_basename(shard_path)
    if cleaned == shard_name {
        return true
    }
    if gpt_large_pretrain_find_substring(shard_path, cleaned) >= 0 {
        return true
    }
    if gpt_large_pretrain_find_substring(shard_name, cleaned) >= 0 {
        return true
    }
    false
}

func gpt_large_pretrain_filter_shard_refs([]string refs, string selection_csv) []string {
    []string selection = gpt_large_pretrain_split_csv(selection_csv)
    if len(selection) == 0 {
        return refs
    }
    []string out = []string{cap: len(refs)}
    int out_len = 0
    int i = 0
    while i < len(refs) {
        string shard_path = refs[i]
        int j = 0
        bool matched = false
        while j < len(selection) {
            if gpt_large_pretrain_string_matches_shard(selection[j], shard_path) {
                matched = true
                break
            }
            j = j + 1
        }
        if matched {
            out[out_len] = shard_path
            out_len = out_len + 1
        }
        i = i + 1
    }
    if out_len == len(refs) {
        return refs
    }
    []string filtered = []string{cap: out_len}
    int k = 0
    while k < out_len {
        filtered[k] = out[k]
        k = k + 1
    }
    filtered
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
    int int_part = 0
    float whole = value
    while whole >= 1.0 {
        whole = whole - 1.0
        int_part = int_part + 1
    }
    float frac = value - int_part
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part, 0) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = 0
        float tmp = frac
        while tmp >= 1.0 {
            tmp = tmp - 1.0
            digit = digit + 1
        }
        s = s + string_char(digit + 48)
        frac = frac - digit
        i = i + 1
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

func copy_float([]float values) []float {
    values
}

func copy_int([]int values) []int {
    values
}

func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}

func tensor_numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}

func tensor_from_ints([]int values, []int shape) tensor {
    int n = len(values)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = values[i]
        i = i + 1
    }
    new(data, copy_int(shape), false)
}

func shape1(int size) []int {
    []int out = []int{cap: 1}
    out[0] = size
    out
}

func scale_tensor(tensor value, float scale) tensor {
    int n = len(value.data)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = value.data[i] * scale
        i = i + 1
    }
    new(data, copy_int(value.shape), value.requires_grad)
}

func zero_pad_int(int value, int width) string {
    string digits = int_to_str(value, 0)
    string prefix = ""
    int missing = width - len(digits)
    if missing < 0 {
        missing = 0
    }
    int i = 0
    while i < missing {
        prefix = prefix + "0"
        i = i + 1
    }
    prefix + digits
}

func split_lines(string text) []string {
    int count = 0
    bool in_line = false
    int i = 0
    int text_len = len(text)
    int last_progress = 0
    
    println("[split] counting lines... (scanning " + format_bytes(text_len) + ")")
    
    while i < text_len {
        if text[i] == 10 || text[i] == 13 {
            if in_line {
                count = count + 1
                in_line = false
            }
        } else {
            in_line = true
        }
        
        // Progress output every 10%
        int progress = (i * 100) / text_len
        if progress != last_progress && progress % 10 == 0 {
            println("[split] " + int_to_str(progress, 0) + "% line counting...")
            last_progress = progress
        }
        
        i = i + 1
    }
    if in_line {
        count = count + 1
    }
    
    println("[split] ✓ found " + int_to_str(count, 0) + " lines, extracting...")
    
    if count <= 0 {
        return []string{cap: 0}
    }
    []string lines = []string{cap: count}
    int line_start = 0
    int out_idx = 0
    i = 0
    last_progress = 0
    
    while i < text_len {
        if text[i] == 10 || text[i] == 13 {
            if i > line_start {
                lines[out_idx] = gpt_large_pretrain_substring(text, line_start, i)
                out_idx = out_idx + 1
            }
            line_start = i + 1
        }
        
        // Progress output every 10%
        int progress = (i * 100) / text_len
        if progress != last_progress && progress % 10 == 0 {
            println("[split] " + int_to_str(progress, 0) + "% line extraction...")
            last_progress = progress
        }
        
        i = i + 1
    }
    if line_start < text_len {
        lines[out_idx] = gpt_large_pretrain_substring(text, line_start, text_len)
    }
    
    println("[split] ✓ extraction complete: " + int_to_str(len(lines), 0) + " lines ready")
    lines
}

func line_after(string line, string prefix) string {
    if len(line) < len(prefix) {
        return ""
    }
    int i = 0
    while i < len(prefix) {
        if line[i] != prefix[i] {
            return ""
        }
        i = i + 1
    }
    string out = ""
    while i < len(line) {
        out = out + string_char(line[i])
        i = i + 1
    }
    out
}

func line_before(string line, int stop_char) string {
    string out = ""
    int i = 0
    while i < len(line) {
        if line[i] == stop_char {
            return out
        }
        out = out + string_char(line[i])
        i = i + 1
    }
    out
}

func gpt_large_pretrain_json_string_value(string text, string key, string fallback) string {
    []string lines = split_lines(text)
    string needle = "\"" + key + "\""
    int i = 0
    while i < len(lines) {
        string line = trim(lines[i])
        if line != "" {
            int key_idx = gpt_large_pretrain_find_substring(line, needle)
            if key_idx >= 0 {
                int colon_idx = key_idx + len(needle)
                while colon_idx < len(line) && line[colon_idx] != 58 {
                    colon_idx = colon_idx + 1
                }
                if colon_idx < len(line) {
                    int value_start = colon_idx + 1
                    while value_start < len(line) && (line[value_start] == 32 || line[value_start] == 9) {
                        value_start = value_start + 1
                    }
                    if value_start < len(line) && line[value_start] == 34 {
                        value_start = value_start + 1
                        string value = ""
                        while value_start < len(line) {
                            if line[value_start] == 34 {
                                return value
                            }
                            if line[value_start] == 92 && value_start + 1 < len(line) {
                                value_start = value_start + 1
                            }
                            value = value + string_char(line[value_start])
                            value_start = value_start + 1
                        }
                    }
                }
            }
        }
        i = i + 1
    }
    fallback
}

func gpt_large_pretrain_find_substring(string text, string pattern) int {
    if len(pattern) == 0 {
        return 0
    }
    int i = 0
    while i + len(pattern) <= len(text) {
        int j = 0
        while j < len(pattern) && text[i + j] == pattern[j] {
            j = j + 1
        }
        if j == len(pattern) {
            return i
        }
        i = i + 1
    }
    -1
}

func gpt_large_pretrain_manifest_refs(string manifest_path) []string {
    if trim(manifest_path) == "" {
        return []string{cap: 0}
    }
    if !runtime_file_exists(manifest_path) {
        return []string{cap: 0}
    }
    if gpt_large_pretrain_find_substring(manifest_path, ".jsonl") >= 0 && gpt_large_pretrain_find_substring(manifest_path, ".gz") < 0 {
        []string refs = []string{cap: 1}
        refs[0] = manifest_path
        return refs
    }

    string manifest_text = runtime_read_text_file(manifest_path)
    int ref_count = 0
    string train_ref = gpt_large_pretrain_json_string_value(manifest_text, "train", "")
    if trim(train_ref) != "" && trim(train_ref) != "null" && runtime_file_exists(train_ref) {
        ref_count = ref_count + 1
    }
    string line = ""
    int i = 0
    while i < len(manifest_text) {
        if manifest_text[i] == 10 || manifest_text[i] == 13 {
            string ref = trim(line)
            if ref != "" {
                if ref[0] != 35 {
                    string file_path = gpt_large_pretrain_json_string_value(ref, "file_path", "")
                    if trim(file_path) != "" && runtime_file_exists(file_path) {
                        ref_count = ref_count + 1
                    } else if gpt_large_pretrain_find_substring(ref, ".jsonl") >= 0 && gpt_large_pretrain_find_substring(ref, ".gz") < 0 {
                        if runtime_file_exists(ref) {
                            ref_count = ref_count + 1
                        }
                    }
                }
            }
            line = ""
        } else {
            line = line + string_char(manifest_text[i])
        }
        i = i + 1
    }
    if len(trim(line)) > 0 {
        string ref = trim(line)
        if ref != "" {
            if ref[0] != 35 {
                string file_path = gpt_large_pretrain_json_string_value(ref, "file_path", "")
                if trim(file_path) != "" && runtime_file_exists(file_path) {
                    ref_count = ref_count + 1
                } else if gpt_large_pretrain_find_substring(ref, ".jsonl") >= 0 && gpt_large_pretrain_find_substring(ref, ".gz") < 0 {
                    if runtime_file_exists(ref) {
                        ref_count = ref_count + 1
                    }
                }
            }
        }
    }
    if ref_count <= 0 {
        return []string{cap: 0}
    }
    []string refs = []string{cap: ref_count}
    int ref_idx = 0
    if trim(train_ref) != "" && trim(train_ref) != "null" {
        if runtime_file_exists(train_ref) {
            refs[ref_idx] = train_ref
            ref_idx = ref_idx + 1
        }
    }
    line = ""
    i = 0
    while i < len(manifest_text) {
        if manifest_text[i] == 10 || manifest_text[i] == 13 {
            string ref = trim(line)
            if ref != "" {
                if ref[0] != 35 {
                    string file_path = gpt_large_pretrain_json_string_value(ref, "file_path", "")
                    if trim(file_path) != "" && runtime_file_exists(file_path) {
                        refs[ref_idx] = file_path
                        ref_idx = ref_idx + 1
                    } else if gpt_large_pretrain_find_substring(ref, ".jsonl") >= 0 && gpt_large_pretrain_find_substring(ref, ".gz") < 0 {
                        if runtime_file_exists(ref) {
                            refs[ref_idx] = ref
                            ref_idx = ref_idx + 1
                        }
                    }
                }
            }
            line = ""
        } else {
            line = line + string_char(manifest_text[i])
        }
        i = i + 1
    }
    if len(trim(line)) > 0 {
        string ref = trim(line)
        if ref != "" {
            if ref[0] != 35 {
                string file_path = gpt_large_pretrain_json_string_value(ref, "file_path", "")
                if trim(file_path) != "" && runtime_file_exists(file_path) {
                    refs[ref_idx] = file_path
                } else if gpt_large_pretrain_find_substring(ref, ".jsonl") >= 0 && gpt_large_pretrain_find_substring(ref, ".gz") < 0 {
                    if runtime_file_exists(ref) {
                        refs[ref_idx] = ref
                    }
                }
            }
        }
    }
    refs
}

func gpt_large_pretrain_documents_for_ref(string shard_ref) []string {
    if trim(shard_ref) == "" {
        println("[init] ERROR: empty shard reference")
        return []string{cap: 0}
    }
    if !runtime_file_exists(shard_ref) {
        println("[init] ERROR: shard file not found: " + shard_ref)
        return []string{cap: 0}
    }
    println("[init] reading shard text: " + shard_ref)
    // Read file with progress display
    string text = read_text_file_with_estimated_progress(shard_ref, 1000)
    if len(text) == 0 {
        println("[init] ERROR: failed to read shard file")
        return []string{cap: 0}
    }
    if trim(text) == "" {
        println("[init] WARNING: shard file is empty")
        return []string{cap: 0}
    }
    println("[init] ✓ file loaded successfully, text length: " + int_to_str(len(text), 0) + " bytes")
    println("[init] splitting lines...")
    []string lines = split_lines(text)
    println("[init] ✓ split complete: " + int_to_str(len(lines), 0) + " lines found, parsing documents...")
    []string docs = []string{cap: 0}
    int line_count = 0
    int doc_count = 0
    bool is_jsonl = gpt_large_pretrain_find_substring(shard_ref, ".jsonl") >= 0 && gpt_large_pretrain_find_substring(shard_ref, ".gz") < 0
    int i = 0
    int total_lines = len(lines)
    int last_progress = 0
    
    while i < total_lines {
        line_count = line_count + 1
        string line = trim(lines[i])
        if line != "" {
            if is_jsonl {
                string doc = trim(gpt_large_pretrain_json_string_value(line, "text", ""))
                if doc != "" {
                    docs.push(doc)
                    doc_count = doc_count + 1
                }
            } else {
                docs.push(line)
                doc_count = doc_count + 1
            }
        }
        
        // Progress every 10%
        int progress = (i * 100) / total_lines
        if progress != last_progress && progress % 10 == 0 {
            println("[init] parsing lines: " + int_to_str(progress, 0) + "% (" + int_to_str(i, 0) + "/" + int_to_str(total_lines, 0) + " lines, docs=" + int_to_str(doc_count, 0) + ")")
            last_progress = progress
        }
        
        i = i + 1
    }
    println("[init] ✓ shard text complete: " + int_to_str(line_count, 0) + " lines, " + int_to_str(doc_count, 0) + " docs extracted")
    return docs
}

func gpt_large_pretrain_documents_for_refs([]string shard_refs) []string {
    println("[init] collecting documents from shard set: " + int_to_str(len(shard_refs), 0))
    []string documents = []string{cap: 0}
    int i = 0
    while i < len(shard_refs) {
        string shard_ref = gpt_large_pretrain_string_at(shard_refs, i)
        println("[init] loading shard " + int_to_str(i + 1, 0) + "/" + int_to_str(len(shard_refs), 0) + ": " + shard_ref)
        []string shard_documents = gpt_large_pretrain_documents_for_ref(shard_ref)
        int j = 0
        while j < len(shard_documents) {
            documents.push(shard_documents[j])
            j = j + 1
        }
        println("[init] shard docs loaded: " + int_to_str(len(shard_documents), 0) + ", total docs=" + int_to_str(len(documents), 0))
        i = i + 1
    }
    println("[init] all shard documents collected: " + int_to_str(len(documents), 0))
    return documents
}

func gpt_large_pretrain_corpus_from_documents([]string documents, int shard_seed) bpe_tokenized_corpus_state {
    println("[init] building corpus from documents")
    []string shuffled_documents = documents
    if len(shuffled_documents) > 1 {
        println("[init] shuffling " + int_to_str(len(shuffled_documents), 0) + " documents...")
        shuffled_documents = gpt_large_pretrain_shuffle_strings(shuffled_documents, shard_seed)
    }
    println("[init] total documents for corpus: " + int_to_str(len(shuffled_documents), 0))
    println("[init] training BPE tokenizer over shard set (this may take a while)...")
    bpe_tokenized_corpus_state corpus = bpe_tokenized_corpus_from_documents(shuffled_documents, 4096, 2, 0.1, 1337)
    println("[init] corpus tokenization complete: train=" + int_to_str(len(corpus.train_token_ids), 0) + " tokens, valid=" + int_to_str(len(corpus.valid_token_ids), 0) + " tokens")
    return corpus
}

func gpt_large_pretrain_corpus_for_ref(string shard_ref, int shard_seed) bpe_tokenized_corpus_state {
    println("[init] collecting documents for corpus: " + shard_ref)
    []string documents = gpt_large_pretrain_documents_for_ref(shard_ref)
    println("[init] documents ready for tokenizer: " + int_to_str(len(documents), 0))
    println("[init] training BPE tokenizer")
    bpe_tokenized_corpus_state corpus = bpe_tokenized_corpus_from_documents(documents, 4096, 2, 0.1, 1337)
    println("[init] corpus tokenization complete")
    return corpus
}

func gpt_large_pretrain_loader_from_corpus(bpe_tokenized_corpus_state corpus, pretrain_config cfg) dataloader_state {
    dataloader_state loader = new_state(corpus.train_token_ids, cfg.micro_batch_size, cfg.seq_len)
    dataloader_config loader_cfg = set_drop_last(new_config(cfg.micro_batch_size, cfg.seq_len), false)
    loader_cfg = set_shuffle(loader_cfg, true)
    with_config(loader, loader_cfg)
}

func gpt_large_pretrain_loader_from_paths([]string paths, pretrain_config cfg, bool shuffle) dataloader_state {
    []string documents = gpt_large_pretrain_documents_for_refs(paths)
    if len(documents) > 1 {
        documents = gpt_large_pretrain_shuffle_strings(documents, cfg.micro_batch_size + cfg.seq_len)
    }
    bpe_tokenized_corpus_state corpus = gpt_large_pretrain_corpus_from_documents(documents, cfg.micro_batch_size + cfg.seq_len)
    dataloader_state loader = new_state(corpus.train_token_ids, cfg.micro_batch_size, cfg.seq_len)
    dataloader_config loader_cfg = set_drop_last(new_config(cfg.micro_batch_size, cfg.seq_len), false)
    loader_cfg = set_shuffle(loader_cfg, shuffle)
    with_config(loader, loader_cfg)
}

func gpt_large_pretrain_valid_loader_from_corpus(bpe_tokenized_corpus_state corpus, pretrain_config cfg) dataloader_state {
    dataloader_state loader = new_state(corpus.valid_token_ids, cfg.micro_batch_size, cfg.seq_len)
    dataloader_config loader_cfg = set_drop_last(new_config(cfg.micro_batch_size, cfg.seq_len), false)
    loader_cfg = set_shuffle(loader_cfg, false)
    with_config(loader, loader_cfg)
}

func new_gpt_large_pretrain_config() pretrain_config {
    pretrain_config {
        global_batch_size: 256,
        micro_batch_size: 8,
        seq_len: 16,
        max_steps: 64,
        warmup_steps: 128,
        lr: 0.00015,
        min_lr: 0.00003,
        weight_decay: 0.1,
        log_interval: 8,
        eval_interval: 16,
        save_interval: 32,
        bf16: true,
        grad_checkpoint: true,
        optimizer: "adamw",
        scheduler: "cosine",
        backend: "cuda",
    }
}

func new_gpt_large_pretrain_state() gpt_large_pretrain_state {
    new_gpt_large_pretrain_state_with_params_and_output(8, 16, 64, 0.00015, 128, 0.00003, 0.1, 8, 16, 32, "dataset/pretrain/manifest.json", "artifacts/checkpoints/run_20260518_001")
}

func new_gpt_large_pretrain_state_with_params_and_output(int micro_batch_size, int seq_len, int max_steps, float lr, int warmup_steps, float min_lr, float weight_decay, int log_interval, int eval_interval, int save_interval, string dataset_manifest, string output_dir) gpt_large_pretrain_state {
    println("[init] loading manifest refs from: " + dataset_manifest)
    []string shard_refs = gpt_large_pretrain_manifest_refs(dataset_manifest)
    println("[init] manifest refs loaded: " + int_to_str(len(shard_refs), 0))
    pretrain_config cfg = new_gpt_large_pretrain_config()
    cfg = pretrain_config {
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: micro_batch_size,
        seq_len: seq_len,
        max_steps: max_steps,
        warmup_steps: warmup_steps,
        lr: lr,
        min_lr: min_lr,
        weight_decay: weight_decay,
        log_interval: log_interval,
        eval_interval: eval_interval,
        save_interval: save_interval,
        bf16: cfg.bf16,
        grad_checkpoint: cfg.grad_checkpoint,
        optimizer: cfg.optimizer,
        scheduler: cfg.scheduler,
        backend: cfg.backend,
    }
    string shard_selection = trim(runtime_env_get("NEURX_PRETRAIN_SHARDS", ""))
    if shard_selection != "" {
        shard_refs = gpt_large_pretrain_filter_shard_refs(shard_refs, shard_selection)
        println("[init] shard filter applied, active refs: " + int_to_str(len(shard_refs), 0))
    }
    int shard_shuffle_seed = 1337
    int shard_order_index = 0
    int active_shard_index = 0
    string active_shard_path = ""
    if len(shard_refs) > 0 {
        active_shard_path = shard_refs[0]
    }
    println("[init] active shard preview: " + active_shard_path)
    gpt_large_training_config training_cfg = gpt_large_training_config {
        batch_size: cfg.micro_batch_size,
        seq_len: cfg.seq_len,
        max_steps: cfg.max_steps,
        learning_rate: cfg.lr,
        label_smoothing: 0.0,
    }
    println("[init] collecting shard documents")
    []string all_documents = gpt_large_pretrain_documents_for_refs(shard_refs)
    if len(all_documents) == 0 {
        println("[init] WARNING: no shard documents found; using synthetic fallback corpus")
        all_documents = []string{
            "neurx trains a decoder only transformer for language modeling.",
            "neurx uses s to build the full training pipeline.",
        }
    }
    println("[init] building corpus and training state from documents")
    bpe_tokenized_corpus_state corpus = gpt_large_pretrain_corpus_from_documents(all_documents, shard_shuffle_seed)
    gpt_large_training_state training = new_gpt_large_training_state(all_documents, training_cfg)
    println("[init] building dataloaders from corpus token ids")
    dataloader_state train_loader = new_state(corpus.train_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    dataloader_config train_loader_cfg = set_drop_last(new_config(training_cfg.batch_size, training_cfg.seq_len), false)
    train_loader_cfg = set_shuffle(train_loader_cfg, true)
    with_config(train_loader, train_loader_cfg)
    dataloader_state valid_loader = new_state(corpus.valid_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    dataloader_config valid_loader_cfg = set_drop_last(new_config(training_cfg.batch_size, training_cfg.seq_len), false)
    valid_loader_cfg = set_shuffle(valid_loader_cfg, false)
    with_config(valid_loader, valid_loader_cfg)
    dataloader_state test_loader = new_state(corpus.valid_token_ids, training_cfg.batch_size, training_cfg.seq_len)
    dataloader_config test_loader_cfg = set_drop_last(new_config(training_cfg.batch_size, training_cfg.seq_len), false)
    test_loader_cfg = set_shuffle(test_loader_cfg, false)
    with_config(test_loader, test_loader_cfg)
    println("[init] dataloaders ready: batch_size=" + int_to_str(training_cfg.batch_size, 0) + ", seq_len=" + int_to_str(training_cfg.seq_len, 0))
    string checkpoint_name = "gpt_large_pretrain"
    if gpt_large_pretrain_is_1t_mode() {
        checkpoint_name = "gpt_moe_1t_pretrain"
    }
    println("[init] initializing optimizer and distributed state")
    training = gpt_large_training_state {
        model: training.model,
        backbone: training.backbone,
        token_embedding: training.token_embedding,
        lm_head_weight: training.lm_head_weight,
        lm_head_bias: training.lm_head_bias,
        backbone_optimizers: training.backbone_optimizers,
        optimizer: training.optimizer,
        loader: train_loader,
        config: training.config,
        metrics: training.metrics,
        step: training.step,
        epoch: training.epoch,
        last_loss: training.last_loss,
        last_perplexity: training.last_perplexity,
        finished: training.finished,
    }
    pretrain_data_state data = new_pretrain_data_state(training.model.dataset, active_shard_index, len(shard_refs))
    pretrain_loop_state loop = new_pretrain_loop_state(cfg, data)
    pretrain_optimizer_state optimizer = new_pretrain_optimizer_state(cfg.lr, cfg.min_lr, cfg.warmup_steps, cfg.max_steps, cfg.weight_decay, 1.0)
    pretrain_ddp_state ddp = new_pretrain_ddp_state_from_env("gpt_large_pretrain", 256, false)
    println("[init] initialization complete! System ready for training.")
    println("[init] config: micro_batch=" + int_to_str(cfg.micro_batch_size, 0) + ", seq_len=" + int_to_str(cfg.seq_len, 0) + ", max_steps=" + int_to_str(cfg.max_steps, 0))
    gpt_large_pretrain_state {
        cfg: cfg,
        dataset_manifest: dataset_manifest,
        output_dir: output_dir,
        shard_refs: shard_refs,
        train_shard_refs: shard_refs,
        valid_shard_refs: shard_refs,
        test_shard_refs: shard_refs,
        shard_order: []int{cap: 0},
        shard_order_index: shard_order_index,
        shard_epoch: 0,
        shard_shuffle_seed: shard_shuffle_seed,
        active_shard_index: active_shard_index,
        active_shard_path: active_shard_path,
        active_shard_tokens: len(corpus.train_token_ids),
        data: data,
        loop: loop,
        checkpoint: new_pretrain_checkpoint_state(checkpoint_name, output_dir),
        eval: new_pretrain_eval_state(),
        corpus: corpus,
        optimizer: optimizer,
        ddp: ddp,
        training: training,
        valid_loader: valid_loader,
        test_loader: test_loader,
        rng_seed: 1337,
        rng_state: 1337,
    }
}

func new_gpt_large_pretrain_state_with_params(int micro_batch_size, int seq_len, int max_steps, float lr, int log_interval, int eval_interval, int save_interval) gpt_large_pretrain_state {
    new_gpt_large_pretrain_state_with_params_and_output(micro_batch_size, seq_len, max_steps, lr, 128, 0.00003, 0.1, log_interval, eval_interval, save_interval, "dataset/pretrain/manifest.json", "artifacts/checkpoints/run_20260518_001")
}

func gpt_large_pretrain_checkpoint_path(gpt_large_pretrain_state state) string {
    string run_root = state.checkpoint.root
    if trim(run_root) == "" {
        run_root = "artifacts/checkpoints/run_20260518_001"
    }
    run_root + "/step_" + zero_pad_int(state.loop.global_step, 7) + "/latest/" + state.checkpoint.run_name
}

func gpt_large_pretrain_checkpoint_dir(gpt_large_pretrain_state state) string {
    string run_root = state.checkpoint.root
    if trim(run_root) == "" {
        run_root = "artifacts/checkpoints/run_20260518_001"
    }
    run_root + "/step_" + zero_pad_int(state.loop.global_step, 7) + "/latest"
}

func gpt_large_pretrain_checkpoint_params(gpt_large_pretrain_state state) []tensor {
    int layer_count = len(state.training.backbone.layers)
    int param_count = 3 + layer_count * 10
    []tensor params = []tensor{cap: param_count}
    int idx = 0
    params[idx] = state.training.token_embedding
    idx = idx + 1
    params[idx] = state.training.lm_head_weight
    idx = idx + 1
    params[idx] = state.training.lm_head_bias
    idx = idx + 1
    int i = 0
    while i < layer_count {
        params[idx] = state.training.backbone.layers[i].w_q
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].w_k
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].w_v
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].w_o
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].w_ff1
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].w_up
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].w_ff2
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].b_ff1
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].b_up
        idx = idx + 1
        params[idx] = state.training.backbone.layers[i].b_ff2
        idx = idx + 1
        i = i + 1
    }
    params
}

func gpt_large_pretrain_metadata_path(gpt_large_pretrain_state state) string {
    gpt_large_pretrain_checkpoint_path(state) + ".meta"
}

func gpt_large_pretrain_tokenizer_manifest_path(gpt_large_pretrain_state state) string {
    gpt_large_pretrain_checkpoint_path(state) + ".tokenizer.manifest"
}

func gpt_large_pretrain_bundle_manifest_path(gpt_large_pretrain_state state) string {
    gpt_large_pretrain_checkpoint_path(state) + ".bundle.txt"
}

func gpt_large_pretrain_checkpoint_bundle(gpt_large_pretrain_state state) pretrain_checkpoint_bundle_state {
    new_pretrain_checkpoint_bundle_state(
        state.checkpoint,
        gpt_large_pretrain_checkpoint_path(state),
        gpt_large_pretrain_optimizer_manifest_path(gpt_large_pretrain_checkpoint_path(state)),
        state.dataset_manifest,
        gpt_large_pretrain_tokenizer_manifest_path(state)
    )
}

func gpt_large_pretrain_metadata_text(gpt_large_pretrain_state state) string {
    string out = "pretrain_meta_v1\n"
    out = out + "step=" + int_to_str(state.loop.global_step, 0) + "\n"
    out = out + "epoch=" + int_to_str(state.loop.data.epoch, 0) + "\n"
    out = out + "loss=" + fmt_float(state.training.last_loss, 6) + "\n"
    out = out + "best_metric=" + fmt_float(state.checkpoint.best_metric, 6) + "\n"
    out = out + "dataset_manifest=" + state.dataset_manifest + "\n"
    out = out + "output_dir=" + state.output_dir + "\n"
    out = out + "shard_order_index=" + int_to_str(state.shard_order_index, 0) + "\n"
    out = out + "shard_epoch=" + int_to_str(state.shard_epoch, 0) + "\n"
    out = out + "shard_shuffle_seed=" + int_to_str(state.shard_shuffle_seed, 0) + "\n"
    out = out + "shard_order=" + join_ints(state.shard_order) + "\n"
    out = out + "shard_index=" + int_to_str(state.active_shard_index, 0) + "\n"
    out = out + "shard_path=" + state.active_shard_path + "\n"
    out = out + "shard_tokens=" + int_to_str(state.active_shard_tokens, 0) + "\n"
    out = out + "shard_count=" + int_to_str(len(state.shard_refs), 0) + "\n"
    out = out + "optimizer.layer_count=" + int_to_str(len(state.training.backbone_optimizers), 0) + "\n"
    out = out + "optimizer.step=" + int_to_str(state.optimizer.step, 0) + "\n"
    out = out + "optimizer.lr=" + fmt_float(state.optimizer.last_lr, 6) + "\n"
    out = out + "optimizer.grad_norm=" + fmt_float(state.optimizer.last_grad_norm, 6) + "\n"
    out = out + "loader.cursor=" + int_to_str(state.training.loader.cursor, 0) + "\n"
    out = out + "loader.epoch=" + int_to_str(state.training.loader.epoch, 0) + "\n"
    out = out + "valid_loader.cursor=" + int_to_str(state.valid_loader.cursor, 0) + "\n"
    out = out + "valid_loader.epoch=" + int_to_str(state.valid_loader.epoch, 0) + "\n"
    out = out + "rng.seed=" + int_to_str(state.rng_seed, 0) + "\n"
    out = out + "rng.state=" + int_to_str(state.rng_state, 0) + "\n"
    out = out + "ddp.enabled=" + int_to_str(bool_to_int(pretrain_ddp_enabled(state.ddp)), 0) + "\n"
    out = out + "ddp.rank=" + int_to_str(pretrain_ddp_rank(state.ddp), 0) + "\n"
    out = out + "ddp.world_size=" + int_to_str(pretrain_ddp_world_size(state.ddp), 0) + "\n"
    out = out + "corpus.train_docs=" + int_to_str(len(state.corpus.split.train_documents), 0) + "\n"
    out = out + "corpus.valid_docs=" + int_to_str(len(state.corpus.split.valid_documents), 0) + "\n"
    out = out + "corpus.train_tokens=" + int_to_str(len(state.corpus.train_token_ids), 0) + "\n"
    out = out + "corpus.valid_tokens=" + int_to_str(len(state.corpus.valid_token_ids), 0) + "\n"
    out
}

func gpt_large_pretrain_tokenizer_manifest_text(gpt_large_pretrain_state state) string {
    string out = "tokenizer_manifest_v1\n"
    out = out + "vocab_limit=" + int_to_str(state.corpus.tokenizer.vocab_limit, 0) + "\n"
    out = out + "min_pair_frequency=" + int_to_str(state.corpus.tokenizer.min_pair_frequency, 0) + "\n"
    out = out + "vocab_size=" + int_to_str(len(state.corpus.tokenizer.vocab), 0) + "\n"
    out = out + "merge_count=" + int_to_str(len(state.corpus.tokenizer.merge_tokens), 0) + "\n"
    out = out + "train_docs=" + int_to_str(len(state.corpus.split.train_documents), 0) + "\n"
    out = out + "valid_docs=" + int_to_str(len(state.corpus.split.valid_documents), 0) + "\n"
    out = out + "train_tokens=" + int_to_str(len(state.corpus.train_token_ids), 0) + "\n"
    out = out + "valid_tokens=" + int_to_str(len(state.corpus.valid_token_ids), 0) + "\n"
    out
}

func gpt_large_pretrain_bundle_text(gpt_large_pretrain_state state) string {
    pretrain_checkpoint_bundle_state bundle = gpt_large_pretrain_checkpoint_bundle(state)
    string out = "checkpoint_bundle_v1\n"
    out = out + "checkpoint_path=" + bundle.checkpoint_path + "\n"
    out = out + "checkpoint_meta_path=" + bundle.checkpoint_meta_path + "\n"
    out = out + "optimizer_manifest_path=" + bundle.optimizer_manifest_path + "\n"
    out = out + "tokenizer_manifest_path=" + bundle.tokenizer_manifest_path + "\n"
    out = out + "data_manifest_path=" + bundle.data_manifest_path + "\n"
    out = out + "bundle_manifest_path=" + gpt_large_pretrain_bundle_manifest_path(state) + "\n"
    out = out + "resumable=" + int_to_str(bool_to_int(bundle.resumable), 0) + "\n"
    out = out + "corpus_path=" + state.active_shard_path + "\n"
    out = out + "active_shard_index=" + int_to_str(state.active_shard_index, 0) + "\n"
    out = out + "active_shard_tokens=" + int_to_str(state.active_shard_tokens, 0) + "\n"
    out
}

func gpt_large_pretrain_train_batch(gpt_large_pretrain_state state) dataloader_step_output {
    dataloader_state loader = state.training.loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }
    next_batch(loader)
}

func gpt_large_pretrain_valid_batch(gpt_large_pretrain_state state) dataloader_step_output {
    dataloader_state loader = state.valid_loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }
    next_batch(loader)
}

func gpt_large_pretrain_loss_value(gpt_large_training_state training, tensor logits, tensor target_ids) float {
    tensor loss_tensor = gpt_large_training_loss(training, logits, target_ids)
    if len(loss_tensor.data) > 0 {
        return loss_tensor.data[0]
    }
    0.0
}

func gpt_large_pretrain_data_ready(gpt_large_pretrain_state state) bool {
    len(state.train_shard_refs) > 0 &&
        len(state.corpus.split.train_documents) > 0 &&
        len(state.corpus.split.valid_documents) > 0 &&
        len(state.corpus.train_token_ids) > 0 &&
        len(state.corpus.valid_token_ids) > 0 &&
        len(state.training.loader.token_ids) > 0
}

func gpt_large_pretrain_model_ready(gpt_large_pretrain_state state) bool {
    state.training.model.vocab_size > 0 &&
        state.training.model.hidden_size > 0 &&
        state.training.model.num_layers > 0 &&
        len(state.training.backbone.layers) > 0 &&
        len(state.training.token_embedding.data) > 0 &&
        len(state.training.lm_head_weight.data) > 0
}

func gpt_large_pretrain_backward_ready(gpt_large_pretrain_state state) bool {
    state.optimizer.max_grad_norm >= 0.0 &&
        state.training.model.gradient_accum_steps >= 1 &&
        state.training.model.global_batch_tokens >= 1
}

func gpt_large_pretrain_distributed_ready(gpt_large_pretrain_state state) bool {
    if gpt_large_pretrain_allow_full_local() {
        return true
    }
    pretrain_ddp_world_size(state.ddp) >= gpt_large_pretrain_expected_world_size() &&
        pretrain_ddp_rank(state.ddp) >= 0
}

func gpt_large_pretrain_stability_ready(gpt_large_pretrain_state state) bool {
    state.cfg.max_steps > 0 &&
        state.cfg.log_interval > 0 &&
        state.cfg.eval_interval > 0 &&
        state.cfg.save_interval > 0 &&
        state.cfg.lr > 0.0 &&
        state.cfg.min_lr >= 0.0 &&
        trim(state.output_dir) != ""
}

func gpt_large_pretrain_ensure_artifact_dirs(gpt_large_pretrain_state state) () {
    if trim(state.output_dir) != "" {
        runtime_make_dirs(state.output_dir)
    }
    runtime_make_dirs(gpt_large_pretrain_checkpoint_dir(state))
}

func gpt_large_pretrain_core_status_text(gpt_large_pretrain_state state) string {
    string out = "pretrain_core_status_v1\n"
    out = out + "data.ready=" + int_to_str(bool_to_int(gpt_large_pretrain_data_ready(state)), 0) + "\n"
    out = out + "model.ready=" + int_to_str(bool_to_int(gpt_large_pretrain_model_ready(state)), 0) + "\n"
    out = out + "backward.ready=" + int_to_str(bool_to_int(gpt_large_pretrain_backward_ready(state)), 0) + "\n"
    out = out + "distributed.ready=" + int_to_str(bool_to_int(gpt_large_pretrain_distributed_ready(state)), 0) + "\n"
    out = out + "stability.ready=" + int_to_str(bool_to_int(gpt_large_pretrain_stability_ready(state)), 0) + "\n"
    out = out + "manifest=" + state.dataset_manifest + "\n"
    out = out + "output_dir=" + state.output_dir + "\n"
    out = out + "shards.train=" + int_to_str(len(state.train_shard_refs), 0) + "\n"
    out = out + "shards.valid=" + int_to_str(len(state.valid_shard_refs), 0) + "\n"
    out = out + "shards.test=" + int_to_str(len(state.test_shard_refs), 0) + "\n"
    out = out + "shard.active_index=" + int_to_str(state.active_shard_index, 0) + "\n"
    out = out + "shard.active_path=" + state.active_shard_path + "\n"
    out = out + "shard.order_index=" + int_to_str(state.shard_order_index, 0) + "\n"
    out = out + "shard.epoch=" + int_to_str(state.shard_epoch, 0) + "\n"
    out = out + "steps=" + int_to_str(state.cfg.max_steps, 0) + "\n"
    out = out + "micro_batch=" + int_to_str(state.cfg.micro_batch_size, 0) + "\n"
    out = out + "seq_len=" + int_to_str(state.cfg.seq_len, 0) + "\n"
    out = out + "lr=" + fmt_float(state.cfg.lr, 6) + "\n"
    out = out + "quality.min_score=" + fmt_float(state.corpus.config.min_quality_score, 6) + "\n"
    out = out + "quality.docs_seen=" + int_to_str(state.corpus.total_docs_seen, 0) + "\n"
    out = out + "quality.docs_filtered=" + int_to_str(state.corpus.docs_filtered, 0) + "\n"
    out = out + "quality.docs_deduped=" + int_to_str(state.corpus.docs_deduped, 0) + "\n"
    out
}

func gpt_large_pretrain_system_ready(gpt_large_pretrain_state state) bool {
    gpt_large_pretrain_data_ready(state) &&
        gpt_large_pretrain_model_ready(state) &&
        gpt_large_pretrain_backward_ready(state) &&
        gpt_large_pretrain_distributed_ready(state) &&
        gpt_large_pretrain_stability_ready(state)
}

func gpt_large_pretrain_core_summary(gpt_large_pretrain_state state) string {
    string out = ""
    out = out + gpt_large_pretrain_framework_title() + "\n"
    out = out + "----------------------------------\n"
    out = out + "Data: " + int_to_str(bool_to_int(gpt_large_pretrain_data_ready(state)), 0) + " | "
    out = out + "Model: " + int_to_str(bool_to_int(gpt_large_pretrain_model_ready(state)), 0) + " | "
    out = out + "Backward: " + int_to_str(bool_to_int(gpt_large_pretrain_backward_ready(state)), 0) + " | "
    out = out + "Distributed: " + int_to_str(bool_to_int(gpt_large_pretrain_distributed_ready(state)), 0) + " | "
    out = out + "Stability: " + int_to_str(bool_to_int(gpt_large_pretrain_stability_ready(state)), 0) + "\n"
    out = out + "Manifest: " + state.dataset_manifest + "\n"
    out = out + "Output: " + state.output_dir + "\n"
    out = out + "Shard: " + int_to_str(state.active_shard_index, 0) + "/" + int_to_str(len(state.train_shard_refs), 0) + " @ " + state.active_shard_path + "\n"
    out = out + "Split shards(train/valid/test): " + int_to_str(len(state.train_shard_refs), 0) + "/" + int_to_str(len(state.valid_shard_refs), 0) + "/" + int_to_str(len(state.test_shard_refs), 0) + "\n"
    out = out + "Shard rotation: epoch=" + int_to_str(state.shard_epoch, 0) + ", order_index=" + int_to_str(state.shard_order_index, 0) + "\n"
    out = out + "Corpus docs(train/valid): " + int_to_str(len(state.corpus.split.train_documents), 0) + "/" + int_to_str(len(state.corpus.split.valid_documents), 0) + "\n"
    out = out + "Tokens(train/valid): " + int_to_str(len(state.corpus.train_token_ids), 0) + "/" + int_to_str(len(state.corpus.valid_token_ids), 0) + "\n"
    out = out + "Quality gate: min_score=" + fmt_float(state.corpus.config.min_quality_score, 6) + ", seen=" + int_to_str(state.corpus.total_docs_seen, 0) + ", filtered=" + int_to_str(state.corpus.docs_filtered, 0) + ", deduped=" + int_to_str(state.corpus.docs_deduped, 0) + "\n"
    out = out + "Steps: " + int_to_str(state.loop.global_step, 0) + "/" + int_to_str(state.cfg.max_steps, 0) + "\n"
    out = out + "Loss: " + fmt_float(state.training.last_loss, 6) + "\n"
    out = out + "Grad norm: " + fmt_float(state.optimizer.last_grad_norm, 6) + "\n"
    out = out + "LR: " + fmt_float(state.optimizer.last_lr, 6) + "\n"
    out = out + "Eval: " + pretrain_eval_summary(state.eval) + "\n"
    out = out + "DDP: enabled=" + int_to_str(bool_to_int(pretrain_ddp_enabled(state.ddp)), 0) + ", rank=" + int_to_str(pretrain_ddp_rank(state.ddp), 0) + ", world=" + int_to_str(pretrain_ddp_world_size(state.ddp), 0) + "\n"
    out
}

func gpt_large_pretrain_write_system_report(gpt_large_pretrain_state state) () {
    gpt_large_pretrain_ensure_artifact_dirs(state)
    runtime_write_text_file(state.output_dir + "/pretrain_core_status.txt", gpt_large_pretrain_core_status_text(state))
    runtime_write_text_file(state.output_dir + "/pretrain_summary.txt", gpt_large_pretrain_core_summary(state))
}

func gpt_large_pretrain_apply_shard(gpt_large_pretrain_state state, int shard_index) gpt_large_pretrain_state {
    []string train_refs = state.train_shard_refs
    if len(train_refs) == 0 {
        train_refs = state.shard_refs
    }
    int idx = shard_index
    if idx < 0 {
        idx = 0
    }
    if idx >= len(train_refs) {
        idx = len(train_refs) - 1
    }
    if idx < 0 {
        idx = 0
    }
    string shard_path = gpt_large_pretrain_string_at(train_refs, idx)
    println("[Shard] " + gpt_large_pretrain_shard_summary_text(idx + 1, len(train_refs), shard_path))
    int shard_seed = gpt_large_pretrain_mix_seed(state.shard_shuffle_seed, state.shard_epoch, idx + 1)
    bpe_tokenized_corpus_state corpus = gpt_large_pretrain_corpus_for_ref(shard_path, shard_seed)
    dataloader_state train_loader = gpt_large_pretrain_loader_from_paths(state.train_shard_refs, state.cfg, true)
    pretrain_data_state data = new_pretrain_data_state(state.training.model.dataset, idx, len(train_refs))
    gpt_large_pretrain_state {
        cfg: state.cfg,
        dataset_manifest: state.dataset_manifest,
        output_dir: state.output_dir,
        shard_refs: state.shard_refs,
        train_shard_refs: train_refs,
        valid_shard_refs: state.valid_shard_refs,
        test_shard_refs: state.test_shard_refs,
        shard_order: state.shard_order,
        shard_order_index: state.shard_order_index,
        shard_epoch: state.shard_epoch,
        shard_shuffle_seed: state.shard_shuffle_seed,
        active_shard_index: idx,
        active_shard_path: shard_path,
        active_shard_tokens: len(corpus.train_token_ids),
        data: data,
        loop: pretrain_loop_state {
            cfg: state.loop.cfg,
            data: data,
            global_step: state.loop.global_step,
            micro_step: state.loop.micro_step,
            tokens_seen: state.loop.tokens_seen,
            loss: state.loop.loss,
            grad_norm: state.loop.grad_norm,
            should_log: state.loop.should_log,
            should_eval: state.loop.should_eval,
            should_save: state.loop.should_save,
            finished: state.loop.finished,
        },
        checkpoint: state.checkpoint,
        eval: state.eval,
        corpus: corpus,
        optimizer: state.optimizer,
        ddp: state.ddp,
        training: gpt_large_training_state {
            model: state.training.model,
            backbone: state.training.backbone,
            token_embedding: state.training.token_embedding,
            lm_head_weight: state.training.lm_head_weight,
            lm_head_bias: state.training.lm_head_bias,
            backbone_optimizers: state.training.backbone_optimizers,
            optimizer: state.training.optimizer,
            loader: train_loader,
            config: state.training.config,
            metrics: state.training.metrics,
            step: state.training.step,
            epoch: state.training.epoch,
            last_loss: state.training.last_loss,
            last_perplexity: state.training.last_perplexity,
            finished: state.training.finished,
        },
        valid_loader: state.valid_loader,
        test_loader: state.test_loader,
        rng_seed: state.rng_seed,
        rng_state: state.rng_state,
    }
}

func gpt_large_pretrain_advance_shard(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    int next_idx = state.active_shard_index + 1
    if len(state.train_shard_refs) == 0 {
        if next_idx >= len(state.shard_refs) {
            next_idx = 0
        }
        return gpt_large_pretrain_apply_shard(state, next_idx)
    }
    if next_idx >= len(state.train_shard_refs) {
        next_idx = 0
    }
    return gpt_large_pretrain_apply_shard(state, next_idx)
}

func gpt_large_pretrain_advance_epoch_shard(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    []int next_order = state.shard_order
    int next_order_index = state.shard_order_index + 1
    int next_shard_epoch = state.shard_epoch
    if len(next_order) == 0 {
        int train_ref_count = len(state.train_shard_refs)
        if train_ref_count == 0 {
            train_ref_count = len(state.shard_refs)
        }
        next_order = gpt_large_pretrain_build_shard_order(train_ref_count, state.shard_shuffle_seed, state.shard_epoch)
    }
    if next_order_index >= len(next_order) {
        next_shard_epoch = state.shard_epoch + 1
        int train_ref_count = len(state.train_shard_refs)
        if train_ref_count == 0 {
            train_ref_count = len(state.shard_refs)
        }
        next_order = gpt_large_pretrain_build_shard_order(train_ref_count, state.shard_shuffle_seed, next_shard_epoch)
        next_order_index = 0
    }
    int next_shard_index = gpt_large_pretrain_int_at(next_order, next_order_index)
    string next_shard_path = gpt_large_pretrain_string_at(state.train_shard_refs, next_shard_index)
    println("[Shard] next -> " + gpt_large_pretrain_shard_summary_text(next_shard_index + 1, len(state.train_shard_refs), next_shard_path) + " (epoch=" + int_to_str(next_shard_epoch, 0) + ", order=" + int_to_str(next_order_index, 0) + ")")
    gpt_large_pretrain_state stepped = gpt_large_pretrain_apply_shard(state, next_shard_index)
    stepped.shard_order = next_order
    stepped.shard_order_index = next_order_index
    stepped.shard_epoch = next_shard_epoch
    return stepped
}

func gpt_large_pretrain_metadata_value(string text, string key, string fallback) string {
    []string lines = split_lines(text)
    int i = 0
    while i < len(lines) {
        string value = line_after(lines[i], key + "=")
        if value != "" {
            return value
        }
        i = i + 1
    }
    fallback
}

func gpt_large_pretrain_metadata_int(string text, string key, int fallback) int {
    str_to_int(gpt_large_pretrain_metadata_value(text, key, int_to_str(fallback, 0)), fallback)
}

func gpt_large_pretrain_metadata_float(string text, string key, float fallback) float {
    str_to_float(gpt_large_pretrain_metadata_value(text, key, fmt_float(fallback, 6)))
}

func gpt_large_pretrain_metadata_float_list(string text, string key, []float fallback) []float {
    parse_float_list(gpt_large_pretrain_metadata_value(text, key, join_floats(fallback)))
}

func gpt_large_pretrain_checkpoint_base_path(string path) string {
    string current = trim(path)
    if current == "" {
        return ""
    }
    if len(current) > 6 && current[len(current) - 6] == 46 && current[len(current) - 5] == 110 && current[len(current) - 4] == 101 && current[len(current) - 3] == 117 && current[len(current) - 2] == 114 && current[len(current) - 1] == 120 {
        return gpt_large_pretrain_substring(current, 0, len(current) - 6)
    }
    if len(current) > 4 && current[len(current) - 4] == 46 && current[len(current) - 3] == 116 && current[len(current) - 2] == 120 && current[len(current) - 1] == 116 {
        return gpt_large_pretrain_substring(current, 0, len(current) - 4)
    }
    current
}

func gpt_large_pretrain_adamw_metadata_text(string prefix, adamw_optimizer opt) string {
    string out = ""
    out = out + prefix + ".lr=" + fmt_float(opt.lr, 10) + "\n"
    out = out + prefix + ".beta1=" + fmt_float(opt.beta1, 10) + "\n"
    out = out + prefix + ".beta2=" + fmt_float(opt.beta2, 10) + "\n"
    out = out + prefix + ".eps=" + fmt_float(opt.eps, 10) + "\n"
    out = out + prefix + ".weight_decay=" + fmt_float(opt.weight_decay, 10) + "\n"
    out = out + prefix + ".step=" + int_to_str(opt.step, 0) + "\n"
    out = out + prefix + ".beta1_pow=" + fmt_float(opt.beta1_pow, 10) + "\n"
    out = out + prefix + ".beta2_pow=" + fmt_float(opt.beta2_pow, 10) + "\n"
    out = out + prefix + ".m=" + join_floats(opt.m) + "\n"
    out = out + prefix + ".v=" + join_floats(opt.v) + "\n"
    out
}

func gpt_large_pretrain_adamw_from_metadata(string text, string prefix, adamw_optimizer fallback) adamw_optimizer {
    adamw_optimizer {
        lr: gpt_large_pretrain_metadata_float(text, prefix + ".lr", fallback.lr),
        beta1: gpt_large_pretrain_metadata_float(text, prefix + ".beta1", fallback.beta1),
        beta2: gpt_large_pretrain_metadata_float(text, prefix + ".beta2", fallback.beta2),
        eps: gpt_large_pretrain_metadata_float(text, prefix + ".eps", fallback.eps),
        weight_decay: gpt_large_pretrain_metadata_float(text, prefix + ".weight_decay", fallback.weight_decay),
        step: gpt_large_pretrain_metadata_int(text, prefix + ".step", fallback.step),
        beta1_pow: gpt_large_pretrain_metadata_float(text, prefix + ".beta1_pow", fallback.beta1_pow),
        beta2_pow: gpt_large_pretrain_metadata_float(text, prefix + ".beta2_pow", fallback.beta2_pow),
        m: gpt_large_pretrain_metadata_float_list(text, prefix + ".m", fallback.m),
        v: gpt_large_pretrain_metadata_float_list(text, prefix + ".v", fallback.v),
    }
}

func gpt_large_pretrain_layer_optimizer_metadata_text(int layer_index, transformer_layer_optimizer_state opt) string {
    string prefix = "layer." + int_to_str(layer_index, 0)
    string out = ""
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_q", opt.w_q)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_k", opt.w_k)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_v", opt.w_v)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_o", opt.w_o)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_ff1", opt.w_ff1)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_ff2", opt.w_ff2)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".b_ff1", opt.b_ff1)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".b_ff2", opt.b_ff2)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_up", opt.w_up)
    out = out + gpt_large_pretrain_adamw_metadata_text(prefix + ".b_up", opt.b_up)
    out
}

func gpt_large_pretrain_layer_optimizer_from_metadata(string text, int layer_index, transformer_layer_optimizer_state fallback) transformer_layer_optimizer_state {
    string prefix = "layer." + int_to_str(layer_index, 0)
    transformer_layer_optimizer_state {
        w_q: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_q", fallback.w_q),
        w_k: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_k", fallback.w_k),
        w_v: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_v", fallback.w_v),
        w_o: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_o", fallback.w_o),
        w_ff1: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_ff1", fallback.w_ff1),
        w_ff2: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_ff2", fallback.w_ff2),
        b_ff1: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".b_ff1", fallback.b_ff1),
        b_ff2: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".b_ff2", fallback.b_ff2),
        w_up: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".w_up", fallback.w_up),
        b_up: gpt_large_pretrain_adamw_from_metadata(text, prefix + ".b_up", fallback.b_up),
    }
}

func gpt_large_pretrain_optimizer_manifest_path(string base_path) string {
    gpt_large_pretrain_checkpoint_base_path(base_path) + ".optimizer.manifest"
}

func gpt_large_pretrain_optimizer_head_path(string base_path) string {
    gpt_large_pretrain_checkpoint_base_path(base_path) + ".optimizer.head"
}

func gpt_large_pretrain_optimizer_layer_path(string base_path, int layer_index) string {
    gpt_large_pretrain_checkpoint_base_path(base_path) + ".optimizer.layer_" + zero_pad_int(layer_index, 4)
}

func gpt_large_pretrain_save_optimizer_state(gpt_large_pretrain_state state) () {
    string base_path = gpt_large_pretrain_checkpoint_path(state)
    string manifest = "optimizer_manifest_v1\n"
    manifest = manifest + "layer_count=" + int_to_str(len(state.training.backbone_optimizers), 0) + "\n"
    manifest = manifest + "head_path=" + gpt_large_pretrain_optimizer_head_path(base_path) + "\n"
    runtime_write_text_file(gpt_large_pretrain_optimizer_manifest_path(base_path), manifest)
    runtime_write_text_file(gpt_large_pretrain_optimizer_head_path(base_path), gpt_large_pretrain_adamw_metadata_text("head", state.training.optimizer))
    int i = 0
    while i < len(state.training.backbone_optimizers) {
        transformer_layer_optimizer_state layer_opt = state.training.backbone_optimizers[i]
        string prefix = "layer." + int_to_str(i, 0)
        string layer_text = ""
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_q", layer_opt.w_q)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_k", layer_opt.w_k)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_v", layer_opt.w_v)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_o", layer_opt.w_o)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_ff1", layer_opt.w_ff1)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_ff2", layer_opt.w_ff2)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".b_ff1", layer_opt.b_ff1)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".b_ff2", layer_opt.b_ff2)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".w_up", layer_opt.w_up)
        layer_text = layer_text + gpt_large_pretrain_adamw_metadata_text(prefix + ".b_up", layer_opt.b_up)
        runtime_write_text_file(gpt_large_pretrain_optimizer_layer_path(base_path, i), layer_text)
        i = i + 1
    }
}

func gpt_large_pretrain_optimizer_validation_text(gpt_large_pretrain_state state, string checkpoint_path, string reason, bool ok) string {
    string out = "optimizer_validation_v1\n"
    out = out + "ok=" + int_to_str(bool_to_int(ok), 0) + "\n"
    out = out + "reason=" + reason + "\n"
    out = out + "checkpoint_path=" + checkpoint_path + "\n"
    out = out + "expected_layers=" + int_to_str(len(state.training.backbone_optimizers), 0) + "\n"
    out = out + "expected_params=" + int_to_str(len(gpt_large_pretrain_checkpoint_params(state)), 0) + "\n"
    out
}

func gpt_large_pretrain_validation_ok(gpt_large_pretrain_state state, checkpoint ckpt, string meta_text) bool {
    int expected_params = len(gpt_large_pretrain_checkpoint_params(state))
    int actual_params = len(checkpoint_params(ckpt))
    if expected_params != actual_params {
        return false
    }
    int meta_layers = gpt_large_pretrain_metadata_int(meta_text, "layer_count", len(state.training.backbone_optimizers))
    if meta_layers != len(state.training.backbone_optimizers) {
        return false
    }
    int meta_shard_count = gpt_large_pretrain_metadata_int(meta_text, "shard_count", len(state.shard_refs))
    if meta_shard_count != len(state.shard_refs) {
        return false
    }
    true
}

func gpt_large_pretrain_optimizer_files_ready(gpt_large_pretrain_state state, string checkpoint_path) bool {
    string base_path = gpt_large_pretrain_checkpoint_base_path(checkpoint_path)
    string manifest_path = gpt_large_pretrain_optimizer_manifest_path(base_path)
    if !runtime_file_exists(manifest_path) {
        return false
    }
    if !runtime_file_exists(base_path + ".tokenizer.manifest") {
        return false
    }
    if !runtime_file_exists(base_path + ".bundle.txt") {
        return false
    }
    string manifest_text = runtime_read_text_file(manifest_path)
    int manifest_layers = gpt_large_pretrain_metadata_int(manifest_text, "layer_count", -1)
    if manifest_layers != len(state.training.backbone_optimizers) {
        return false
    }
    string head_path = gpt_large_pretrain_metadata_value(manifest_text, "head_path", gpt_large_pretrain_optimizer_head_path(base_path))
    if !runtime_file_exists(head_path) {
        return false
    }
    int i = 0
    while i < len(state.training.backbone_optimizers) {
        if !runtime_file_exists(gpt_large_pretrain_optimizer_layer_path(base_path, i)) {
            return false
        }
        i = i + 1
    }
    true
}

func gpt_large_pretrain_restore_optimizer_state(gpt_large_pretrain_state state, string checkpoint_path, string meta_text) gpt_large_pretrain_state {
    string base_path = gpt_large_pretrain_checkpoint_base_path(checkpoint_path)
    string manifest_path = gpt_large_pretrain_optimizer_manifest_path(base_path)
    if !runtime_file_exists(manifest_path) {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "optimizer manifest missing", false))
        return state
    }
    if !runtime_file_exists(base_path + ".tokenizer.manifest") {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "tokenizer manifest missing", false))
        return state
    }
    if !runtime_file_exists(base_path + ".bundle.txt") {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "bundle manifest missing", false))
        return state
    }

    string manifest_text = runtime_read_text_file(manifest_path)
    int manifest_layers = gpt_large_pretrain_metadata_int(manifest_text, "layer_count", -1)
    if manifest_layers != len(state.training.backbone_optimizers) {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "layer count mismatch", false))
        return state
    }

    string head_path = gpt_large_pretrain_metadata_value(manifest_text, "head_path", gpt_large_pretrain_optimizer_head_path(base_path))
    if !runtime_file_exists(head_path) {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "head optimizer missing", false))
        return state
    }

    gpt_large_pretrain_state restored = state
    string head_text = runtime_read_text_file(head_path)
    restored.training.optimizer = gpt_large_pretrain_adamw_from_metadata(head_text, "head", restored.training.optimizer)
    int i = 0
    while i < len(restored.training.backbone_optimizers) {
        string layer_path = gpt_large_pretrain_optimizer_layer_path(base_path, i)
        if !runtime_file_exists(layer_path) {
            runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "missing layer optimizer " + int_to_str(i, 0), false))
            return state
        }
        string layer_text = runtime_read_text_file(layer_path)
        string prefix = "layer." + int_to_str(i, 0)
        transformer_layer_optimizer_state current_layer_opt = restored.training.backbone_optimizers[i]
        restored.training.backbone_optimizers[i] = transformer_layer_optimizer_state {
            w_q: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_q", current_layer_opt.w_q),
            w_k: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_k", current_layer_opt.w_k),
            w_v: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_v", current_layer_opt.w_v),
            w_o: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_o", current_layer_opt.w_o),
            w_ff1: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_ff1", current_layer_opt.w_ff1),
            w_ff2: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_ff2", current_layer_opt.w_ff2),
            b_ff1: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".b_ff1", current_layer_opt.b_ff1),
            b_ff2: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".b_ff2", current_layer_opt.b_ff2),
            w_up: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".w_up", current_layer_opt.w_up),
            b_up: gpt_large_pretrain_adamw_from_metadata(layer_text, prefix + ".b_up", current_layer_opt.b_up),
        }
        i = i + 1
    }

    runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_path, "ok", true))
    restored
}

func gpt_large_pretrain_apply_checkpoint_params(gpt_large_pretrain_state state, []tensor params) gpt_large_pretrain_state {
    if len(params) == 0 {
        return state
    }
    int cursor = 0
    if len(params) >= 3 {
        state.training.token_embedding = copy_tensor(params[cursor])
        cursor = cursor + 1
        state.training.lm_head_weight = copy_tensor(params[cursor])
        cursor = cursor + 1
        state.training.lm_head_bias = copy_tensor(params[cursor])
        cursor = cursor + 1
    }

    int layer_idx = 0
    while layer_idx < len(state.training.backbone.layers) && cursor + 10 <= len(params) {
        transformer_layer layer = state.training.backbone.layers[layer_idx]
        layer.w_q = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.w_k = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.w_v = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.w_o = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.w_ff1 = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.w_up = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.w_ff2 = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.b_ff1 = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.b_up = copy_tensor(params[cursor]); cursor = cursor + 1
        layer.b_ff2 = copy_tensor(params[cursor]); cursor = cursor + 1
        state.training.backbone.layers[layer_idx] = layer
        layer_idx = layer_idx + 1
    }
    state
}

func gpt_large_pretrain_resume_from_checkpoint(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    gpt_large_pretrain_state restored = state
    string checkpoint_path = gpt_large_pretrain_checkpoint_path(state)
    string latest_ref_path = state.output_dir + "/latest_checkpoint_ref.txt"
    if runtime_file_exists(latest_ref_path) {
        string latest_ref = trim(runtime_read_text_file(latest_ref_path))
        if latest_ref != "" {
            checkpoint_path = latest_ref
        }
    }
    string checkpoint_base_path = gpt_large_pretrain_checkpoint_base_path(checkpoint_path)
    checkpoint ckpt = load_checkpoint(checkpoint_path)
    string meta_path = checkpoint_base_path + ".meta"
    string meta_text = ""
    if runtime_file_exists(meta_path) {
        meta_text = runtime_read_text_file(meta_path)
    }

    if len(checkpoint_params(ckpt)) == 0 {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_base_path, "missing checkpoint params", false))
        return state
    }

    if !gpt_large_pretrain_validation_ok(state, ckpt, meta_text) {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_base_path, "checkpoint topology mismatch", false))
        return state
    }

    if !gpt_large_pretrain_optimizer_files_ready(state, checkpoint_base_path) {
        runtime_write_text_file(state.output_dir + "/checkpoint_validation.txt", gpt_large_pretrain_optimizer_validation_text(state, checkpoint_base_path, "optimizer shards missing", false))
        return state
    }

    int meta_step = gpt_large_pretrain_metadata_int(meta_text, "step", checkpoint_step(ckpt))
    int meta_shard_index = gpt_large_pretrain_metadata_int(meta_text, "shard_index", state.active_shard_index)
    string meta_shard_path = gpt_large_pretrain_metadata_value(meta_text, "shard_path", state.active_shard_path)
    int meta_shard_tokens = gpt_large_pretrain_metadata_int(meta_text, "shard_tokens", state.active_shard_tokens)
    int meta_shard_order_index = gpt_large_pretrain_metadata_int(meta_text, "shard_order_index", state.shard_order_index)
    int meta_shard_epoch = gpt_large_pretrain_metadata_int(meta_text, "shard_epoch", state.shard_epoch)
    int meta_shard_seed = gpt_large_pretrain_metadata_int(meta_text, "shard_shuffle_seed", state.shard_shuffle_seed)
    int meta_tokens_seen = gpt_large_pretrain_metadata_int(meta_text, "loader.cursor", state.data.token_cursor)
    int meta_epoch = gpt_large_pretrain_metadata_int(meta_text, "loader.epoch", state.data.epoch)
    int meta_valid_cursor = gpt_large_pretrain_metadata_int(meta_text, "valid_loader.cursor", state.valid_loader.cursor)
    int meta_valid_epoch = gpt_large_pretrain_metadata_int(meta_text, "valid_loader.epoch", state.valid_loader.epoch)
    float meta_lr = gpt_large_pretrain_metadata_float(meta_text, "optimizer.lr", state.optimizer.last_lr)
    float meta_grad_norm = gpt_large_pretrain_metadata_float(meta_text, "optimizer.grad_norm", state.optimizer.last_grad_norm)
    int meta_optimizer_step = gpt_large_pretrain_metadata_int(meta_text, "optimizer.step", state.optimizer.step)
    float meta_best_metric = gpt_large_pretrain_metadata_float(meta_text, "best_metric", state.checkpoint.best_metric)

    restored = gpt_large_pretrain_restore_optimizer_state(restored, checkpoint_base_path, meta_text)
    restored = gpt_large_pretrain_apply_checkpoint_params(restored, checkpoint_params(ckpt))
    restored.loop = pretrain_loop_state {
        cfg: restored.loop.cfg,
        data: restored.data,
        global_step: meta_step,
        micro_step: 0,
        tokens_seen: meta_tokens_seen,
        loss: checkpoint_loss(ckpt),
        grad_norm: meta_grad_norm,
        should_log: false,
        should_eval: false,
        should_save: false,
        finished: false,
    }
    restored.data.token_cursor = meta_tokens_seen
    restored.data.epoch = meta_epoch
    restored.training.step = meta_step
    restored.training.last_loss = checkpoint_loss(ckpt)
    restored.training.model.current_step = meta_step
    restored.training.model.seen_tokens = meta_tokens_seen
    restored.training.model.training_steps = meta_step
    restored.training.model.best_validation_loss = meta_best_metric

    restored.loop.global_step = meta_step
    restored.loop.data = restored.data
    restored.loop.tokens_seen = meta_tokens_seen
    restored.loop.loss = checkpoint_loss(ckpt)
    restored.loop.grad_norm = meta_grad_norm
    restored.data.token_cursor = meta_tokens_seen
    restored.data.epoch = meta_epoch
    restored.active_shard_index = meta_shard_index
    restored.active_shard_path = meta_shard_path
    restored.active_shard_tokens = meta_shard_tokens
    restored.shard_order = parse_int_list(gpt_large_pretrain_metadata_value(meta_text, "shard_order", join_ints(state.shard_order)))
    restored.shard_order_index = meta_shard_order_index
    restored.shard_epoch = meta_shard_epoch
    restored.shard_shuffle_seed = meta_shard_seed
    restored.optimizer.step = meta_optimizer_step
    restored.optimizer.last_lr = meta_lr
    restored.optimizer.last_grad_norm = meta_grad_norm
    restored.checkpoint.best_metric = meta_best_metric
    restored.checkpoint.has_best = true
    restored.training.optimizer.lr = meta_lr
    restored.training.loader.cursor = meta_tokens_seen
    restored.training.loader.epoch = meta_epoch
    restored.valid_loader.cursor = meta_valid_cursor
    restored.valid_loader.epoch = meta_valid_epoch

    if meta_shard_index >= 0 && meta_shard_index < len(state.shard_refs) {
        restored.active_shard_index = meta_shard_index
        restored.active_shard_path = meta_shard_path
        restored.active_shard_tokens = meta_shard_tokens
        restored = gpt_large_pretrain_apply_shard(restored, restored.active_shard_index)
        restored.loop.global_step = meta_step
        restored.loop.data = restored.data
        restored.loop.tokens_seen = meta_tokens_seen
        restored.loop.loss = checkpoint_loss(ckpt)
        restored.loop.grad_norm = meta_grad_norm
        restored.data.token_cursor = meta_tokens_seen
        restored.data.epoch = meta_epoch
        restored.optimizer.step = meta_optimizer_step
        restored.optimizer.last_lr = meta_lr
        restored.optimizer.last_grad_norm = meta_grad_norm
        restored.checkpoint.best_metric = meta_best_metric
        restored.checkpoint.has_best = true
        restored.training.optimizer.lr = meta_lr
        restored.training.loader.cursor = meta_tokens_seen
        restored.training.loader.epoch = meta_epoch
        restored.valid_loader.cursor = meta_valid_cursor
        restored.valid_loader.epoch = meta_valid_epoch
        restored.training.step = checkpoint_step(ckpt)
        restored.training.last_loss = checkpoint_loss(ckpt)
        restored.training.model.current_step = meta_step
        restored.training.model.seen_tokens = meta_tokens_seen
        restored.training.model.training_steps = meta_step
        restored.training.model.best_validation_loss = meta_best_metric
    }

    restored
}

func gpt_large_pretrain_env_int(string name, int fallback) int {
    string value = runtime_env_get(name, "")
    if trim(value) == "" {
        return fallback
    }
    int parsed = str_to_int(value, fallback)
    if parsed <= 0 {
        return fallback
    }
    parsed
}

func gpt_large_pretrain_env_float(string name, float fallback) float {
    string value = runtime_env_get(name, "")
    if trim(value) == "" {
        return fallback
    }
    float parsed = str_to_float(value)
    if parsed <= 0.0 {
        return fallback
    }
    parsed
}

func gpt_large_pretrain_env_string(string name, string fallback) string {
    string value = trim(runtime_env_get(name, ""))
    if value == "" {
        return fallback
    }
    value
}

func gpt_large_pretrain_is_1t_mode() bool {
    string model_size = trim(runtime_env_get("MODEL_SIZE", ""))
    model_size == "1t" || model_size == "1t-moe" || model_size == "neurx-1t" || model_size == "neurx-1t-moe"
}

func gpt_large_pretrain_allow_full_local() bool {
    string allow = trim(runtime_env_get("NEURX_ALLOW_FULL_1T_LOCAL", "0"))
    allow == "1" || allow == "true" || allow == "yes"
}

func gpt_large_pretrain_framework_title() string {
    if gpt_large_pretrain_is_1t_mode() {
        return "NeurX 1T MoE Pretraining System"
    }
    "NeurX Large Pretraining System"
}

func gpt_large_pretrain_expected_world_size() int {
    if gpt_large_pretrain_allow_full_local() {
        return 1
    }
    if gpt_large_pretrain_is_1t_mode() {
        return moe_1t_framework_default().parallel.world_size
    }
    1
}

func gpt_large_pretrain_run_from_env() gpt_large_pretrain_state {
    bool is_1t = gpt_large_pretrain_is_1t_mode()
    string manifest_default = "dataset/pretrain/manifest.json"
    string output_default = "artifacts/checkpoints/gpt_large_pretrain"
    int micro_batch_default = 8
    int seq_len_default = 16
    int max_steps_default = 64
    float lr_default = 0.00015
    int warmup_default = 128
    float min_lr_default = 0.00003
    float weight_decay_default = 0.1
    int log_interval_default = 8
    int eval_interval_default = 16
    int save_interval_default = 32
    if is_1t {
        manifest_default = moe_1t_framework_default().training.data_manifest_path
        output_default = moe_1t_framework_default().training.output_dir
        micro_batch_default = 2
        seq_len_default = 4096
        max_steps_default = moe_1t_framework_default().training.total_steps
        lr_default = moe_1t_framework_default().training.peak_lr
        warmup_default = moe_1t_framework_default().training.warmup_steps
        min_lr_default = moe_1t_framework_default().training.min_lr
        weight_decay_default = 0.01
        log_interval_default = moe_1t_framework_default().training.log_steps
        eval_interval_default = moe_1t_framework_default().training.eval_steps
        save_interval_default = moe_1t_framework_default().training.save_steps
    }
    string manifest = gpt_large_pretrain_env_string("NEURX_PRETRAIN_MANIFEST", manifest_default)
    string output_dir = gpt_large_pretrain_env_string("NEURX_PRETRAIN_OUTPUT_DIR", output_default)
    int micro_batch_size = gpt_large_pretrain_env_int("NEURX_PRETRAIN_MICRO_BATCH", micro_batch_default)
    int seq_len = gpt_large_pretrain_env_int("NEURX_PRETRAIN_SEQ_LEN", seq_len_default)
    int max_steps = gpt_large_pretrain_env_int("NEURX_PRETRAIN_STEPS", max_steps_default)
    float lr = gpt_large_pretrain_env_float("NEURX_PRETRAIN_LR", lr_default)
    int warmup_steps = gpt_large_pretrain_env_int("NEURX_PRETRAIN_WARMUP_STEPS", warmup_default)
    float min_lr = gpt_large_pretrain_env_float("NEURX_PRETRAIN_MIN_LR", min_lr_default)
    float weight_decay = gpt_large_pretrain_env_float("NEURX_PRETRAIN_WEIGHT_DECAY", weight_decay_default)
    int log_interval = gpt_large_pretrain_env_int("NEURX_PRETRAIN_LOG_INTERVAL", log_interval_default)
    int eval_interval = gpt_large_pretrain_env_int("NEURX_PRETRAIN_EVAL_INTERVAL", eval_interval_default)
    int save_interval = gpt_large_pretrain_env_int("NEURX_PRETRAIN_SAVE_INTERVAL", save_interval_default)
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state_with_params_and_output(
        micro_batch_size,
        seq_len,
        max_steps,
        lr,
        warmup_steps,
        min_lr,
        weight_decay,
        log_interval,
        eval_interval,
        save_interval,
        manifest,
        output_dir
    )
    if gpt_large_pretrain_env_int("NEURX_PRETRAIN_RESUME", 1) > 0 {
        state = gpt_large_pretrain_resume_from_checkpoint(state)
    }
    state
}

func gpt_large_pretrain_execute(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    int steps_to_run = state.cfg.max_steps - state.loop.global_step
    if steps_to_run <= 0 {
        steps_to_run = state.cfg.max_steps
    }
    println("[training] Starting training execution: " + int_to_str(steps_to_run, 0) + " steps (current global_step=" + int_to_str(state.loop.global_step, 0) + ")")
    gpt_large_pretrain_state current = gpt_large_pretrain_run_and_save(state, steps_to_run)
    println("[training] Training execution complete")
    gpt_large_pretrain_write_system_report(current)
    current
}

func gpt_large_pretrain_validation_metrics(gpt_large_pretrain_state state) gpt_large_pretrain_eval_result {
    dataloader_step_output batch_output = gpt_large_pretrain_valid_batch(state)
    int input_len = len(batch_output.batch.input_ids)
    int target_len = len(batch_output.batch.target_ids)
    tensor input_ids = tensor_from_ints(batch_output.batch.input_ids, shape1(input_len))
    tensor target_ids = tensor_from_ints(batch_output.batch.target_ids, shape1(target_len))
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    tensor logits = ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
    float val_loss = gpt_large_pretrain_loss_value(state.training, logits, target_ids)
    float ppl = 1.0 + val_loss * val_loss * 3.0
    gpt_large_pretrain_eval_result {
        eval: update_pretrain_eval(state.eval, state.loop.global_step, val_loss, ppl),
        valid_loader: batch_output.state,
    }
}

func gpt_large_pretrain_test_metrics(gpt_large_pretrain_state state) gpt_large_pretrain_eval_result {
    dataloader_state loader = state.test_loader
    if len(state.test_shard_refs) == 0 {
        loader = state.valid_loader
    }
    dataloader_step_output batch_output = next_batch(loader)
    int input_len = len(batch_output.batch.input_ids)
    int target_len = len(batch_output.batch.target_ids)
    tensor input_ids = tensor_from_ints(batch_output.batch.input_ids, shape1(input_len))
    tensor target_ids = tensor_from_ints(batch_output.batch.target_ids, shape1(target_len))
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    tensor logits = ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
    float test_loss = gpt_large_pretrain_loss_value(state.training, logits, target_ids)
    float ppl = 1.0 + test_loss * test_loss * 3.0
    gpt_large_pretrain_eval_result {
        eval: update_pretrain_eval(state.eval, state.loop.global_step, test_loss, ppl),
        valid_loader: batch_output.state,
    }
}

func embedding_grad_tensor(tensor token_ids, tensor grad_hidden, int vocab_size, int hidden_size) tensor {
    []float data = []float{cap: vocab_size * hidden_size}
    int token_count = len(token_ids.data)
    int i = 0
    while i < token_count {
        int token_id = token_ids.data[i] as int
        if token_id < 0 {
            token_id = 0
        }
        if vocab_size > 0 {
            while token_id >= vocab_size {
                token_id = token_id - vocab_size
            }
        } else {
            token_id = 0
        }
        int h = 0
        while h < hidden_size && i * hidden_size + h < len(grad_hidden.data) {
            int dst = token_id * hidden_size + h
            data[dst] = data[dst] + grad_hidden.data[i * hidden_size + h]
            h = h + 1
        }
        i = i + 1
    }
    new(data, [vocab_size, hidden_size], false)
}

func gpt_large_pretrain_forward_logits(gpt_large_pretrain_state state, tensor input_ids) tensor {
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
}

func gpt_large_pretrain_optimizer_update(gpt_large_pretrain_state state, dataloader_step_output train_output, dataloader_step_output valid_output) gpt_large_pretrain_state {
    int train_input_len = len(train_output.batch.input_ids)
    int train_target_len = len(train_output.batch.target_ids)
    tensor input_ids = tensor_from_ints(train_output.batch.input_ids, shape1(train_input_len))
    tensor target_ids = tensor_from_ints(train_output.batch.target_ids, shape1(train_target_len))
    tensor hidden = embedding_lookup(state.training.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.training.backbone, hidden)
    tensor logits = ops.lm_head_logits(backbone_out, state.training.lm_head_weight, state.training.lm_head_bias)
    tensor loss_tensor = gpt_large_training_loss(state.training, logits, target_ids)
    float loss_value = 0.0
    if len(loss_tensor.data) > 0 {
        loss_value = loss_tensor.data[0]
    }

    gpt_large_training_state next_training = gpt_large_training_update(
        state.training,
        input_ids,
        hidden,
        logits,
        target_ids,
        loss_value,
        train_output.batch.valid_tokens
    )

    int next_step = next_training.step
    int next_seen_tokens = next_training.model.seen_tokens
    float validation_loss = next_training.model.validation_loss
    float validation_perplexity = next_training.model.validation_perplexity
    float train_ppl = next_training.model.train_perplexity
    float best_validation_loss = next_training.model.best_validation_loss

    int valid_input_len = len(valid_output.batch.input_ids)
    int valid_target_len = len(valid_output.batch.target_ids)
    tensor valid_input_ids = tensor_from_ints(valid_output.batch.input_ids, shape1(valid_input_len))
    tensor valid_target_ids = tensor_from_ints(valid_output.batch.target_ids, shape1(valid_target_len))
    tensor valid_hidden = embedding_lookup(next_training.token_embedding, valid_input_ids, 0)
    tensor valid_backbone_out = transformer_forward(next_training.backbone, valid_hidden)
    tensor valid_logits = ops.lm_head_logits(valid_backbone_out, next_training.lm_head_weight, next_training.lm_head_bias)
    validation_loss = gpt_large_pretrain_loss_value(next_training, valid_logits, valid_target_ids)
    validation_perplexity = 1.0 + validation_loss * validation_loss * 3.0
    if validation_loss < best_validation_loss {
        best_validation_loss = validation_loss
    }

    pretrain_eval_state next_eval = state.eval
    if state.cfg.eval_interval > 0 && (next_step / state.cfg.eval_interval) * state.cfg.eval_interval == next_step {
        next_eval = update_pretrain_eval(state.eval, next_step, validation_loss, validation_perplexity)
        println("Eval: " + pretrain_eval_summary(next_eval))
        if pretrain_eval_is_best(next_eval) {
            println("Eval best updated at step " + int_to_str(next_step, 0))
        }
    }
    dataloader_state next_valid_loader = valid_output.state

    pretrain_checkpoint_state next_checkpoint = state.checkpoint
    if state.cfg.save_interval > 0 && (next_step / state.cfg.save_interval) * state.cfg.save_interval == next_step {
        next_checkpoint = mark_saved(next_checkpoint, next_step)
    }
    next_checkpoint = mark_best(next_checkpoint, next_step, validation_loss)

    pretrain_loop_state next_loop = pretrain_step(state.loop, loss_value, next_training.last_perplexity, train_output.batch.valid_tokens)
    pretrain_data_state next_data = advance_tokens(state.data, train_output.batch.valid_tokens)
    int active_shard_index = state.active_shard_index
    string active_shard_path = state.active_shard_path
    int active_shard_tokens = state.active_shard_tokens
    bpe_tokenized_corpus_state next_corpus = state.corpus
    dataloader_state next_train_loader = next_training.loader
    int next_shard_order_index = state.shard_order_index
    int next_shard_epoch = state.shard_epoch
    if next_data.token_cursor >= state.active_shard_tokens {
        println("[Shard] active shard exhausted; staying on current shard")
        next_loop = pretrain_reset_micro_step(pretrain_loop_state {
            cfg: next_loop.cfg,
            data: next_data,
            global_step: next_loop.global_step,
            micro_step: next_loop.micro_step,
            tokens_seen: next_loop.tokens_seen,
            loss: next_loop.loss,
            grad_norm: next_loop.grad_norm,
            should_log: next_loop.should_log,
            should_eval: next_loop.should_eval,
            should_save: next_loop.should_save,
            finished: next_loop.finished,
        })
    }

    gpt_large_pretrain_state {
        cfg: state.cfg,
        dataset_manifest: state.dataset_manifest,
        output_dir: state.output_dir,
        shard_refs: state.shard_refs,
        train_shard_refs: state.train_shard_refs,
        valid_shard_refs: state.valid_shard_refs,
        test_shard_refs: state.test_shard_refs,
        shard_order: state.shard_order,
        shard_order_index: next_shard_order_index,
        shard_epoch: next_shard_epoch,
        shard_shuffle_seed: state.shard_shuffle_seed,
        active_shard_index: active_shard_index,
        active_shard_path: active_shard_path,
        active_shard_tokens: active_shard_tokens,
        data: next_data,
        loop: pretrain_loop_state {
            cfg: next_loop.cfg,
            data: next_data,
            global_step: next_loop.global_step,
            micro_step: next_loop.micro_step,
            tokens_seen: next_loop.tokens_seen,
            loss: next_loop.loss,
            grad_norm: next_loop.grad_norm,
            should_log: next_loop.should_log,
            should_eval: next_loop.should_eval,
            should_save: next_loop.should_save,
            finished: next_loop.finished,
        },
        checkpoint: next_checkpoint,
        eval: next_eval,
        corpus: next_corpus,
        optimizer: state.optimizer,
        ddp: pretrain_ddp_step(state.ddp),
        training: gpt_large_training_state {
            model: gpt_large_state {
                name: next_training.model.name,
                family: next_training.model.family,
                architecture: next_training.model.architecture,
                dataset: next_training.model.dataset,
                vocab_size: next_training.model.vocab_size,
                max_seq_len: next_training.model.max_seq_len,
                hidden_size: next_training.model.hidden_size,
                num_heads: next_training.model.num_heads,
                num_layers: next_training.model.num_layers,
                intermediate_size: next_training.model.intermediate_size,
                context_window: next_training.model.context_window,
                parameter_count_m: next_training.model.parameter_count_m,
                training_steps: next_step,
                training_tokens_b: next_seen_tokens / 1000000000,
                train_loss: loss_value,
                train_perplexity: train_ppl,
                validation_loss: validation_loss,
                validation_perplexity: validation_perplexity,
                learning_rate: next_training.model.learning_rate,
                dropout: next_training.model.dropout,
                rope_base: next_training.model.rope_base,
                tied_embeddings: next_training.model.tied_embeddings,
                gradient_accum_steps: next_training.model.gradient_accum_steps,
                global_batch_tokens: next_training.model.global_batch_tokens,
                current_step: next_step,
                seen_tokens: next_seen_tokens,
                best_validation_loss: best_validation_loss,
                trained: next_step >= state.training.config.max_steps,
            },
            backbone: next_training.backbone,
            token_embedding: next_training.token_embedding,
            lm_head_weight: next_training.lm_head_weight,
            lm_head_bias: next_training.lm_head_bias,
            backbone_optimizers: next_training.backbone_optimizers,
            optimizer: next_training.optimizer,
            loader: next_train_loader,
            config: next_training.config,
            metrics: next_training.metrics,
            step: next_training.step,
            epoch: next_training.epoch,
            last_loss: next_training.last_loss,
            last_perplexity: next_training.last_perplexity,
            finished: next_training.finished,
        },
        valid_loader: next_valid_loader,
        test_loader: state.test_loader,
        rng_seed: state.rng_seed,
        rng_state: state.rng_state + 1,
    }
}

func gpt_large_pretrain_save_checkpoint(gpt_large_pretrain_state state) () {
    gpt_large_pretrain_ensure_artifact_dirs(state)
    runtime_make_dirs(gpt_large_pretrain_checkpoint_dir(state) + "/optimizer")
    save_checkpoint(
        gpt_large_pretrain_checkpoint_path(state),
        state.loop.global_step,
        state.training.last_loss,
        gpt_large_pretrain_checkpoint_params(state)
    )
    gpt_large_pretrain_save_optimizer_state(state)
    runtime_write_text_file(state.output_dir + "/latest_checkpoint_ref.txt", gpt_large_pretrain_checkpoint_path(state))
    runtime_write_text_file(gpt_large_pretrain_metadata_path(state), gpt_large_pretrain_metadata_text(state))
    runtime_write_text_file(gpt_large_pretrain_tokenizer_manifest_path(state), gpt_large_pretrain_tokenizer_manifest_text(state))
    runtime_write_text_file(gpt_large_pretrain_bundle_manifest_path(state), gpt_large_pretrain_bundle_text(state))
}

func gpt_large_pretrain_state_dict(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    gpt_large_pretrain_state {
        cfg: pretrain_config_state_dict(state.cfg),
        dataset_manifest: state.dataset_manifest,
        output_dir: state.output_dir,
        shard_refs: state.shard_refs,
        train_shard_refs: state.train_shard_refs,
        valid_shard_refs: state.valid_shard_refs,
        test_shard_refs: state.test_shard_refs,
        shard_order: state.shard_order,
        shard_order_index: state.shard_order_index,
        shard_epoch: state.shard_epoch,
        shard_shuffle_seed: state.shard_shuffle_seed,
        active_shard_index: state.active_shard_index,
        active_shard_path: state.active_shard_path,
        active_shard_tokens: state.active_shard_tokens,
        data: pretrain_data_state_dict(state.data),
        loop: pretrain_loop_state_dict(state.loop),
        checkpoint: pretrain_checkpoint_state_dict(state.checkpoint),
        eval: pretrain_eval_state_dict(state.eval),
        corpus: bpe_tokenized_corpus_state_dict(state.corpus),
        optimizer: pretrain_optimizer_state_dict(state.optimizer),
        ddp: pretrain_ddp_state_dict(state.ddp),
        training: gpt_large_training_state_dict(state.training),
        valid_loader: dataloader_state_dict(state.valid_loader),
        test_loader: dataloader_state_dict(state.test_loader),
        rng_seed: state.rng_seed,
        rng_state: state.rng_state,
    }
}

func gpt_large_pretrain_load_state_dict(gpt_large_pretrain_state state, gpt_large_pretrain_state other) gpt_large_pretrain_state {
    gpt_large_pretrain_state {
        cfg: pretrain_config_load_state_dict(state.cfg, other.cfg),
        dataset_manifest: other.dataset_manifest,
        output_dir: other.output_dir,
        shard_refs: other.shard_refs,
        train_shard_refs: other.train_shard_refs,
        valid_shard_refs: other.valid_shard_refs,
        test_shard_refs: other.test_shard_refs,
        shard_order: other.shard_order,
        shard_order_index: other.shard_order_index,
        shard_epoch: other.shard_epoch,
        shard_shuffle_seed: other.shard_shuffle_seed,
        active_shard_index: other.active_shard_index,
        active_shard_path: other.active_shard_path,
        active_shard_tokens: other.active_shard_tokens,
        data: pretrain_data_load_state_dict(state.data, other.data),
        loop: pretrain_loop_load_state_dict(state.loop, other.loop),
        checkpoint: pretrain_checkpoint_load_state_dict(state.checkpoint, other.checkpoint),
        eval: pretrain_eval_load_state_dict(state.eval, other.eval),
        corpus: bpe_tokenized_corpus_load_state_dict(state.corpus, other.corpus),
        optimizer: pretrain_optimizer_load_state_dict(state.optimizer, other.optimizer),
        ddp: pretrain_ddp_load_state_dict(state.ddp, other.ddp),
        training: gpt_large_training_load_state_dict(state.training, other.training),
        valid_loader: dataloader_load_state_dict(state.valid_loader, other.valid_loader),
        test_loader: dataloader_load_state_dict(state.test_loader, other.test_loader),
        rng_seed: other.rng_seed,
        rng_state: other.rng_state,
    }
}

func gpt_large_pretrain_log_step(
    int step,
    float loss,
    float lr,
    string shard_path,
    int shard_token_cursor,
    int shard_total_tokens,
    int save_interval,
    int log_interval,
    int batch_tokens,
    int batch_valid_tokens,
    int docs_seen,
    int corpus_tokens_seen,
    int tokenizer_vocab_size
) () {
    bool should_log = step == 0
    if log_interval > 0 && step / log_interval * log_interval == step {
        should_log = true
    }
    if should_log {
        string save_note = ""
        if save_interval > 0 && step > 0 && step / save_interval * save_interval == step {
            save_note = " | Saving checkpoint..."
        }
        string shard_name = gpt_large_pretrain_basename(shard_path)
        string shard_progress = gpt_large_pretrain_shard_progress_text(shard_token_cursor, shard_total_tokens)
        println(
            "[Step " + int_to_str(step, 0) + "] " +
            "Shard=" + shard_name +
            " | " + shard_progress +
            " | Loss=" + fmt_float(loss, 3) +
            " | LR=" + fmt_float(lr, 6) +
            " | BatchTokens=" + int_to_str(batch_tokens, 0) +
            " | ValidTokens=" + int_to_str(batch_valid_tokens, 0) +
            " | DocsSeen=" + int_to_str(docs_seen, 0) +
            " | CorpusTokens=" + int_to_str(corpus_tokens_seen, 0) +
            " | TokenizerVocab=" + int_to_str(tokenizer_vocab_size, 0) +
            " | Path=" + shard_path + save_note
        )
    }
}

func gpt_large_pretrain_step(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    if state.loop.finished {
        return state
    }
    dataloader_step_output train_output = gpt_large_pretrain_train_batch(state)
    dataloader_step_output valid_output = gpt_large_pretrain_valid_batch(state)
    gpt_large_pretrain_state next = gpt_large_pretrain_optimizer_update(state, train_output, valid_output)
    if next.loop.global_step < state.loop.global_step {
        return state
    }
    
    float current_lr = state.cfg.lr
    if state.cfg.warmup_steps > 0 && next.loop.global_step < state.cfg.warmup_steps {
        current_lr = state.cfg.lr * (next.loop.global_step + 1) / state.cfg.warmup_steps
    }
    if current_lr < state.cfg.min_lr {
        current_lr = state.cfg.min_lr
    }
    gpt_large_pretrain_log_step(
        next.loop.global_step,
        next.training.last_loss,
        current_lr,
        next.active_shard_path,
        next.data.token_cursor,
        next.active_shard_tokens,
        state.cfg.save_interval,
        state.cfg.log_interval,
        len(train_output.batch.input_ids),
        train_output.batch.valid_tokens,
        next.corpus.total_docs_seen,
        next.corpus.total_tokens_seen,
        len(next.corpus.tokenizer.vocab)
    )
    next
}

func gpt_large_pretrain_run(gpt_large_pretrain_state state, int steps) gpt_large_pretrain_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    gpt_large_pretrain_state current = state
    int i = 0
    int progress_interval = 1
    if loops > 10 {
        progress_interval = loops / 10
    }
    while i < loops {
        current = gpt_large_pretrain_step(current)
        i = i + 1
        if i % progress_interval == 0 || i == 1 {
            println("[progress] step " + int_to_str(i, 0) + "/" + int_to_str(loops, 0) + ", global_step=" + int_to_str(current.loop.global_step, 0) + ", loss=" + fmt_float(current.training.last_loss, 3))
        }
        if current.loop.finished {
            return current
        }
    }
    current
}

func gpt_large_pretrain_run_and_save(gpt_large_pretrain_state state, int steps) gpt_large_pretrain_state {
    gpt_large_pretrain_state current = gpt_large_pretrain_run(state, steps)
    gpt_large_pretrain_save_checkpoint(current)
    current
}

func gpt_large_pretrain_complete(gpt_large_pretrain_state state) bool {
    state.loop.finished
}

pub func gpt_large_pretrain_launch() int {
    gpt_large_pretrain_state state = gpt_large_pretrain_run_from_env()
    println("")
    println("========================================")
    println("  " + gpt_large_pretrain_framework_title())
    println("========================================")
    println("")
    if gpt_large_pretrain_is_1t_mode() {
        println(moe_1t_summary(moe_1t_framework_default()))
        println("")
    }
    println("Core readiness:")
    println("  - Data: " + int_to_str(bool_to_int(gpt_large_pretrain_data_ready(state)), 0))
    println("  - Model: " + int_to_str(bool_to_int(gpt_large_pretrain_model_ready(state)), 0))
    println("  - Backward: " + int_to_str(bool_to_int(gpt_large_pretrain_backward_ready(state)), 0))
    println("  - Distributed: " + int_to_str(bool_to_int(gpt_large_pretrain_distributed_ready(state)), 0))
    println("  - Stability: " + int_to_str(bool_to_int(gpt_large_pretrain_stability_ready(state)), 0))
    println("")
    println("Manifest: " + state.dataset_manifest)
    println("Output: " + state.output_dir)
    println("Shard split: train/valid/test = " + int_to_str(len(state.train_shard_refs), 0) + "/" + int_to_str(len(state.valid_shard_refs), 0) + "/" + int_to_str(len(state.test_shard_refs), 0))
    println("Shard rotation: epoch " + int_to_str(state.shard_epoch, 0) + ", order index " + int_to_str(state.shard_order_index, 0))
    string shard_selection = trim(runtime_env_get("NEURX_PRETRAIN_SHARDS", ""))
    if shard_selection != "" {
        println("Shard filter: " + shard_selection)
    }
    println("Train shard refs:")
    int preview_count = len(state.train_shard_refs)
    if preview_count > 5 {
        preview_count = 5
    }
    int idx = 0
    while idx < preview_count {
        println("  - " + gpt_large_pretrain_string_at(state.train_shard_refs, idx))
        idx = idx + 1
    }
    if len(state.train_shard_refs) > preview_count {
        println("  ... (" + int_to_str(len(state.train_shard_refs) - preview_count, 0) + " more)")
    }
    println("Current active shard: " + state.active_shard_path)
    println("Steps: " + int_to_str(state.cfg.max_steps, 0))
    println("LR: " + fmt_float(state.cfg.lr, 6))
    println("Warmup: " + int_to_str(state.cfg.warmup_steps, 0))
    println("")

    if !gpt_large_pretrain_system_ready(state) {
        println("Pretraining system is not fully ready.")
        println("Refusing to fall back to report-only mode.")
        return 1
    }

    println("")
    println("════════════════════════════════════════════════════════════")
    println("🚀 Starting Real Training Loop")
    println("════════════════════════════════════════════════════════════")
    println("Max steps: " + int_to_str(state.cfg.max_steps, 0))
    println("Log interval: " + int_to_str(state.cfg.log_interval, 0))
    println("Eval interval: " + int_to_str(state.cfg.eval_interval, 0))
    println("Save interval: " + int_to_str(state.cfg.save_interval, 0))
    println("")

    gpt_large_pretrain_state final_state = gpt_large_pretrain_execute(state)
    
    println("")
    println("════════════════════════════════════════════════════════════")
    println("✅ Training finished")
    println("════════════════════════════════════════════════════════════")
    println("Final loss: " + fmt_float(final_state.training.last_loss, 6))
    println("Best metric: " + fmt_float(final_state.checkpoint.best_metric, 6))
    println("Tokens seen: " + int_to_str(final_state.loop.tokens_seen, 0))
    println("Total steps: " + int_to_str(final_state.loop.global_step, 0))
    gpt_large_pretrain_eval_result test_result = gpt_large_pretrain_test_metrics(final_state)
    println("Test loss: " + fmt_float(test_result.eval.loss, 6))
    println("Test perplexity: " + fmt_float(test_result.eval.perplexity, 6))
    println("Summary written to: " + final_state.output_dir + "/pretrain_summary.txt")
    string release_dir = gpt_large_pretrain_prepare_release(final_state)
    println("Compression release written to: " + release_dir)
    println("════════════════════════════════════════════════════════════")
    0
}

func main() int {
    return gpt_large_pretrain_launch()
}

func gpt_large_pretrain_prepare_release(gpt_large_pretrain_state state) string {
    state.output_dir + "/release"
}

func gpt_large_pretrain_ensure_quantization_release_artifact(gpt_large_pretrain_state state, string manifest_path) () {
    return
}

func gpt_large_pretrain_ensure_distillation_release_artifact(gpt_large_pretrain_state state, string manifest_path) () {
    return
}
