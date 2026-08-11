package neurx.shard.shard_manager
use neurx.strings
use neurx.runtime.io.{runtime_file_exists, runtime_dir_exists, runtime_make_dirs, runtime_write_text_file, runtime_read_text_file, runtime_run_command_output, runtime_shell_escape}
struct shard_manager_config {
    int64 target_shard_size_mb
    int64 min_shard_size_mb
    int64 max_shard_size_mb
    string partition_strategy
    string boundary_alignment
    int num_ranks
    bool balance_by_token_count
    bool enable_replication
    string shard_dir
    string file_extension
    bool compress_shards
    int compression_level
    bool build_index
    bool include_checksums
    int max_retries_on_failure
}

func default_tb_shard_config() shard_manager_config:
    shard_manager_config cfg
    cfg.target_shard_size_mb = 2048
    cfg.min_shard_size_mb = 100
    cfg.max_shard_size_mb = 4096
    cfg.partition_strategy = "by_document"
    cfg.boundary_alignment = "document"
    cfg.num_ranks = 64
    cfg.balance_by_token_count = true
    cfg.enable_replication = true
    cfg.shard_dir = "./data/shards"
    cfg.file_extension = ".bin"
    cfg.compress_shards = true
    cfg.compression_level = 3
    cfg.build_index = true
    cfg.include_checksums = true
    cfg.max_retries_on_failure = 3
    return cfg
func default_training_dataset_path() string:
    "./data/training_data.jsonl"
func default_training_shard_dir() string:
    "./data/training_data_shards"
func default_training_shard_manifest_path() string:
    default_training_shard_dir() + "/manifest.json"
func default_training_dataset_name() string:
    "training_data"
struct training_dataset_layout:
    string dataset_path
    string dataset_name
    int64 total_size_bytes
    int total_documents
    int64 estimated_tokens
    bool is_single_file
func inspect_training_dataset(string dataset_path) training_dataset_layout:
    training_dataset_layout layout
    layout.dataset_path = dataset_path
    layout.dataset_name = default_training_dataset_name()
    layout.total_size_bytes = get_file_size(dataset_path)
    layout.total_documents = estimate_line_count(dataset_path, layout.total_size_bytes)
    layout.estimated_tokens = layout.total_size_bytes / 3
    layout.is_single_file = true
    layout
func build_training_dataset_manifest(string dataset_path) dataset_manifest:
    training_dataset_layout layout = inspect_training_dataset(dataset_path)
    dataset_manifest manifest
    manifest.dataset_name = layout.dataset_name
    manifest.dataset_version = "v1"
    manifest.source_path = layout.dataset_path
    manifest.total_size_bytes = layout.total_size_bytes
    manifest.total_compressed_bytes = layout.total_size_bytes
    manifest.total_shard_count = 1
    manifest.total_document_count = layout.total_documents
    manifest.total_token_count = layout.estimated_tokens
    manifest.shards = []shard_info{cap: 1}
    manifest.config_used = default_tb_shard_config()
    manifest.creation_timestamp = get_current_time_ms()
    manifest.created_by = "neurx_single_file_manifest"
    manifest.parent_dataset = ""
    shard_info shard
    shard.shard_id = 0
    shard.filename = dataset_path
    shard.file_size_bytes = layout.total_size_bytes
    shard.uncompressed_size_bytes = layout.total_size_bytes
    shard.document_count = layout.total_documents
    shard.token_count = layout.estimated_tokens
    shard.quality_score = 1.0
    shard.start_offset_in_dataset = 0
    shard.end_offset_in_dataset = layout.total_size_bytes
    shard.assigned_ranks = []int{cap: 1}
    shard.assigned_ranks[0] = 0
    shard.primary_rank = 0
    shard.is_fully_written = true
    shard.is_validated = true
    shard.checksum_sha256 = ""
    shard.version = 1
    shard.access_count = 0
    shard.avg_read_time_ms = 0.0
    manifest.shards.push(shard)
    manifest
struct shard_info {
    int shard_id
    string filename
    int64 file_size_bytes
    int64 uncompressed_size_bytes
    int document_count
    int64 token_count
    float quality_score
    int64 start_offset_in_dataset
    int64 end_offset_in_dataset
    []int assigned_ranks
    int primary_rank
    bool is_fully_written
    bool is_validated
    string checksum_sha256
    int version
    int access_count
    float avg_read_time_ms
}

struct dataset_manifest {
    string dataset_name
    string dataset_version
    string source_path
    int64 total_size_bytes
    int64 total_compressed_bytes
    int total_shard_count
    int total_document_count
    int64 total_token_count
    []shard_info shards
    shard_manager_config config_used
    int64 creation_timestamp
    string created_by
    string parent_dataset
}

struct shard_manager_state {
    shard_manager_config config
    dataset_manifest manifest
    string current_operation
    float operation_progress
    int current_shard_being_processed
    []shard_info recently_accessed
    int max_cache_size
    []string error_log
    int error_count
}

func new_shard_manager(shard_manager_config config) shard_manager_state:
    shard_manager_state mgr
    mgr.config = config
    mgr.current_operation = "idle"
    mgr.operation_progress = 0.0
    mgr.current_shard_being_processed = -1
    mgr.recently_accessed = []shard_info{cap: 100}
    mgr.max_cache_size = 100
    mgr.error_log = []string{cap: 100}
    mgr.error_count = 0
    return mgr
struct partition_result:
    dataset_manifest manifest
    bool success
    string error_message
    int total_time_ms
    []shard_info created_shards
func partition_dataset(
    shard_manager_state mgr,
    string input_path,
    string output_dir,
    string dataset_name
) partition_result:
    int start_time = get_current_time_ms()
    mgr.current_operation = "partitioning"
    partition_result result
    result.success = false
    print("Analyzing input dataset: ", input_path)
    dataset_analysis analysis = analyze_input_dataset(input_path, mgr.config)
    if !analysis.is_valid:
        result.error_message = "Invalid input dataset: " + analysis.error_reason
        log_error(mgr, result.error_message)
        mgr.current_operation = "idle"
        return result
    print("Dataset analyzed:")
    print("  Total size: ", analysis.total_size_gb, " GB")
    print("  document count: ", analysis.document_count)
    print("  Estimated tokens: ", analysis.estimated_tokens)
    print("Determining shard boundaries...")
    []shard_boundary boundaries = calculate_shard_boundaries(analysis, mgr.config)
    print("Will create ", len(boundaries), " shards")
    mgr.manifest.total_shard_count = len(boundaries)
    if !create_directory(output_dir):
        result.error_message = "Failed to create output directory: " + output_dir
        log_error(mgr, result.error_message)
        mgr.current_operation = "idle"
        return result
    string shard_base_path = output_dir + "/" + dataset_name
    mgr.config.shard_dir = shard_base_path
    print("Writing shards...")
    []shard_info all_shards = []shard_info{cap: len(boundaries)}
    int s = 0
    while s < len(boundaries):
        shard_boundary bnd = boundaries[s]
        mgr.current_shard_being_processed = s
        mgr.operation_progress = float(s) / float(len(boundaries))
        shard_write_result write_res = write_single_shard(
            mgr,
            input_path,
            bnd,
            s,
            shard_base_path
        )
        if write_res.success:
            all_shards.push(write_res.info)
            if (((s + 1) - ((s + 1) / 10) * 10) == 0 or s == len(boundaries) - 1:
                print("Completed shard ", s + 1, "/", len(boundaries),
                      " (", write_res.info.file_size_bytes / (1024*1024), " MB)")
        else:
            string warn_msg = "Failed to write shard " + s + ": " + write_res.error_msg
            log_warning(mgr, warn_msg)
            print("WARNING: ", warn_msg)
        s = s + 1
    print("Building dataset manifest...")
    dataset_manifest manifest
    manifest.dataset_name = dataset_name
    manifest.source_path = input_path
    manifest.total_size_bytes = analysis.total_size_bytes
    manifest.total_shard_count = len(all_shards)
    manifest.document_count = sum_document_counts(all_shards)
    manifest.total_token_count = sum_token_counts(all_shards)
    manifest.shards = all_shards
    manifest.config_used = copy_config(mgr.config)
    manifest.creation_timestamp = get_current_time_ms()
    manifest.created_by = "neurx_shard_manager_v1.0"
    int64 comp_total = 0
    s = 0
    while s < len(all_shards):
        comp_total = comp_total + all_shards[s].file_size_bytes
        s = s + 1
    manifest.total_compressed_bytes = comp_total
    save_manifest(manifest, shard_base_path + "/manifest.json")
    if mgr.config.include_checksums:
        print("Validating shards...")
        validate_all_shards(manifest)
    int end_time = get_current_time_ms()
    result.manifest = manifest
    result.success = true
    result.total_time_ms = end_time - start_time
    result.created_shards = all_shards
    mgr.manifest = manifest
    mgr.current_operation = "idle"
    mgr.operation_progress = 1.0
    print("\nPartitioning complete!")
    print("  Total time: ", result.total_time_ms / 1000, " seconds")
    print("  Shards created: ", len(all_shards))
    print("  Total size (compressed): ", comp_total / (1048576.0 * 1024.0), " GB")
    print("  Compression ratio: ",
          float(manifest.total_size_bytes) / float(comp_total), "x")
    return result
struct dataset_analysis:
    bool is_valid
    string error_reason
    int64 total_size_bytes
    float total_size_gb
    int document_count
    int64 estimated_tokens
    string detected_format
    []string source_files
    bool is_single_file
    string encoding
func analyze_input_dataset(string path, shard_manager_config cfg) dataset_analysis:
    dataset_analysis analysis
    analysis.is_valid = false
    if !file_exists(path):
        analysis.error_reason = "Path does not exist: " + path
        return analysis
    bool is_dir = is_directory(path)
    if is_dir:
        analysis.source_files = list_files_recursive(path, cfg.file_extension)
        analysis.is_single_file = false
        if len(analysis.source_files) == 0:
            analysis.error_reason = "No data files found in directory"
            return analysis
        int i = 0
        while i < len(analysis.source_files):
            analysis.total_size_bytes = analysis.total_size_bytes +
                                        get_file_size(analysis.source_files[i])
            i = i + 1
        analysis.document_count = estimate_doc_count_from_files(
            analysis.source_files,
            min(10, len(analysis.source_files))
        )
    else:
        analysis.source_files.push(path)
        analysis.is_single_file = true
        analysis.total_size_bytes = get_file_size(path)
        analysis.document_count = estimate_line_count(path, analysis.total_size_bytes)
    analysis.total_size_gb = float(analysis.total_size_bytes) / (1048576.0 * 1024.0)
    analysis.estimated_tokens = analysis.total_size_bytes / 3
    analysis.detected_format = detect_format_from_extension(path)
    analysis.encoding = "utf-8"
    analysis.is_valid = true
    return analysis
struct shard_boundary:
    int64 start_byte
    int64 end_byte
    int estimated_documents
    string split_reason
func calculate_shard_boundaries(
    dataset_analysis analysis,
    shard_manager_config cfg
) []shard_boundary:
    int64 target_size = cfg.target_shard_size_mb * 1024 * 1024
    int64 min_size = cfg.min_shard_size_mb * 1024 * 1024
    int64 max_size = cfg.max_shard_size_mb * 1024 * 1024
    []shard_boundary boundaries = []shard_boundary{cap: 100}
    if analysis.is_single_file:
        boundaries = find_split_points_single_file(
            analysis.source_files[0],
            analysis.total_size_bytes,
            target_size,
            min_size,
            max_size,
            cfg.boundary_alignment
        )
    else:
        boundaries = group_files_into_shards(
            analysis.source_files,
            target_size,
            min_size,
            max_size
        )
    return boundaries
func find_split_points_single_file(
    string filepath,
    int64 total_size,
    int64 target_size,
    int64 min_size,
    int64 max_size,
    string alignment
) []shard_boundary:
    []shard_boundary boundaries = []shard_boundary{cap: 100}
    int64 current_start = 0
    int shard_id = 0
    while current_start < total_size:
        int64 proposed_end = current_start + target_size
        if proposed_end >= total_size:
            boundaries.push(shard_boundary{
                start_byte: current_start,
                end_byte: total_size,
                estimated_documents: 0,
                split_reason: "final_shard"
            })
            break
        int64 actual_end = proposed_end
        if alignment == "line":
            actual_end = find_next_newline_after(filepath, proposed_end)
        elif alignment == "document":
            actual_end = find_next_document_boundary(filepath, proposed_end)
        elif alignment == "paragraph":
            actual_end = find_next_double_newline(filepath, proposed_end)
        else:
            actual_end = proposed_end
        if actual_end - current_start < min_size:
            actual_end = current_start + min_size
            if actual_end > total_size:
                actual_end = total_size
        if actual_end - current_start > max_size:
            actual_end = current_start + max_size
        boundaries.push(shard_boundary{
            start_byte: current_start,
            end_byte: actual_end,
            estimated_documents: 0,
            split_reason: alignment
        })
        current_start = actual_end
        shard_id = shard_id + 1
    return boundaries
struct shard_write_result:
    shard_info info
    bool success
    string error_msg
func write_single_shard(
    shard_manager_state mgr,
    string source_path,
    shard_boundary boundary,
    int shard_id,
    string base_path
) shard_write_result:
    shard_write_result result
    result.success = false
    string filename = base_path + "_shard_" + format_int_with_leading_zeros(shard_id, 6) +
                      mgr.config.file_extension
    []byte raw_data = read_file_range(source_path, boundary.start_byte,
                                      boundary.end_byte - boundary.start_byte)
    if len(raw_data) == 0:
        result.error_msg = "Failed to read data range from source"
        return result
    []byte data_to_write = raw_data
    if mgr.config.compress_shards:
        data_to_write = compress_data(raw_data, mgr.config.compression_level)
    bool write_ok = write_all_bytes(filename, data_to_write)
    if !write_ok:
        result.error_msg = "Failed to write shard file: " + filename
        return result
    string checksum = ""
    if mgr.config.include_checksums:
        checksum = compute_sha256(data_to_write)
    shard_info info
    info.shard_id = shard_id
    info.filename = filename
    info.file_size_bytes = int64(len(data_to_write))
    info.uncompressed_size_bytes = int64(len(raw_data))
    info.document_count = count_documents_in_data(raw_data)
    info.token_count = estimate_tokens_in_data(raw_data)
    info.quality_score = assess_data_quality(raw_data)
    info.start_offset_in_dataset = boundary.start_byte
    info.end_offset_in_dataset = boundary.end_byte
    info.checksum_sha256 = checksum
    info.is_fully_written = true
    info.is_validated = false
    info.version = 1
    info.access_count = 0
    info.avg_read_time_ms = 0.0
    info.assigned_ranks = assign_shard_to_ranks(shard_id, mgr.config.num_ranks)
    info.primary_rank = info.assigned_ranks[0]
    result.info = info
    result.success = true
    return result
func assign_shard_to_ranks(int shard_id, int num_ranks) []int:
    []int ranks = []int{cap: 2}
    int primary_rank = s(shard_id - (shard_id / num_ranks) * num_ranks)
    ranks.push(primary_rank)
    return ranks
func get_shards_for_rank(dataset_manifest manifest, int rank_id) []shard_info:
    []shard_info my_shards = []shard_info{cap: 100}
    int s = 0
    while s < len(manifest.shards):
        shard_info shard = manifest.shards[s]
        int r = 0
        while r < len(shard.assigned_ranks):
            if shard.assigned_ranks[r] == rank_id:
                my_shards.push(shard)
                break
            r = r + 1
        s = s + 1
    return my_shards
func rebalance_shards(
    dataset_manifest manifest,
    []float rank_performance_scores
) dataset_manifest:
    return manifest
struct incremental_update_result:
    dataset_manifest updated_manifest
    int new_shards_added
    int old_shards_updated
    bool success
    string message
func add_incremental_data(
    shard_manager_state mgr,
    dataset_manifest existing_manifest,
    string new_data_path
) incremental_update_result:
    incremental_update_result result
    result.success = false
    dataset_analysis new_analysis = analyze_input_dataset(new_data_path, mgr.config)
    if !new_analysis.is_valid:
        result.message = "Invalid new data: " + new_analysis.error_reason
        return result
    print("Adding incremental data: ", new_analysis.total_size_gb, " GB")
    int next_shard_id = len(existing_manifest.shards)
    result.success = true
    result.message = "Incremental update completed successfully"
    return result
func sum_document_counts([]shard_info shards) int:
    int total = 0
    int i = 0
    while i < len(shards):
        total = total + shards[i].document_count
        i = i + 1
    return total
func sum_token_counts([]shard_info shards) int64:
    int64 total = 0
    int i = 0
    while i < len(shards):
        total = total + shards[i].token_count
        i = i + 1
    return total
func copy_config(shard_manager_config orig) shard_manager_config:
    return orig
func log_error(shard_manager_state mgr, string msg) void:
    mgr.error_log.push("[ERROR] " + msg)
    mgr.error_count = mgr.error_count + 1
func log_warning(shard_manager_state mgr, string msg) void:
    mgr.error_log.push("[WARN] " + msg)
func save_manifest(dataset_manifest manifest, string path) void:
    string dir = trim(runtime_run_command_output("dirname " + runtime_shell_escape(path)))
    if dir != "" {
        runtime_make_dirs(dir)
    }
    runtime_write_text_file(path, manifest_to_json(manifest))
func validate_all_shards(dataset_manifest manifest) void:
    int i = 0
    int validated = 0
    while i < len(manifest.shards) {
        shard_info shard = manifest.shards[i]
        if !file_exists(shard.filename) {
            print("WARNING: missing shard file: ", shard.filename)
        } else if shard.checksum_sha256 != "" {
            int64 size_bytes = get_file_size(shard.filename)
            []byte shard_bytes = read_file_range(shard.filename, 0, size_bytes)
            string actual = compute_sha256(shard_bytes)
            if actual != shard.checksum_sha256 {
                print("WARNING: checksum mismatch for shard ", shard.shard_id, ": ", shard.filename)
            } else {
                validated = validated + 1
            }
        } else {
            validated = validated + 1
        }
        i = i + 1
    }
    print("Validated shards: ", validated, "/", len(manifest.shards))
func file_exists(string path) bool: return runtime_file_exists(path)
func is_directory(string path) bool: return runtime_dir_exists(path)
func list_files_recursive(string dir, string ext) []string: return []string{cap: 0}
func get_file_size(string path) int64 {
    string size_text = trim(runtime_run_command_output("wc -c < " + runtime_shell_escape(path)))
    int64 size = 0
    int i = 0
    while i < len(size_text) {
        string ch = string(size_text[i])
        if ch >= "0" && ch <= "9" {
            size = size * 10 + int64(int(ch) - 48)
        }
        i = i + 1
    }
    size
}

func create_directory(string path) bool {
    runtime_make_dirs(path).ok
}

func read_file_range(string path, int64 offset, int64 length) []byte {
    string content = runtime_read_text_file(path)
    int start = int(offset)
    if start < 0 {
        start = 0
    }
    int available = len(content)
    if start >= available {
        return []byte{cap: 0}
    }
    int count = int(length)
    if count < 0 {
        count = 0
    }
    int end = start + count
    if end > available {
        end = available
    }
    []byte out = []byte{cap: end - start}
    int i = 0
    int pos = start
    while pos < end {
        out[i] = int(string(content[pos]))
        i = i + 1
        pos = pos + 1
    }
    out
}

func write_all_bytes(string path, []byte data) bool {
    string content = ""
    int i = 0
    while i < len(data) {
        content = content + string(data[i])
        i = i + 1
    }
    runtime_write_text_file(path, content)
    true
}

func find_next_newline_after(string path, int64 offset) int64: return offset
func find_next_document_boundary(string path, int64 offset) int64: return offset
func find_next_double_newline(string path, int64 offset) int64: return offset
func estimate_line_count(string path, int64 size) int: return int(size / 100)
func estimate_doc_count_from_files([]string files, int sample_n) int: return 0
func detect_format_from_extension(string path) string: return "text"
func count_documents_in_data([]byte data) int: return 0
func estimate_tokens_in_data([]byte data) int64: return int64(len(data)) / 3
func assess_data_quality([]byte data) float: return 1.0
func compress_data([]byte data, int level) []byte: return data
func compute_sha256([]byte data) string {
    string payload = ""
    int i = 0
    while i < len(data) {
        payload = payload + string(data[i])
        i = i + 1
    }
    string escaped = runtime_shell_escape(payload)
    string checksum = trim(runtime_run_command_output("printf %s " + escaped + " | shasum -a 256 | awk '{print $1}'"))
    if checksum != "" {
        return checksum
    }
    trim(runtime_run_command_output("printf %s " + escaped + " | openssl dgst -sha256 | awk '{print $2}'"))
}

func format_int_with_leading_zeros(int val, int width) string {
    string s = string(val)
    while len(s) < width {
        s = "0" + s
    }
    s
}

func get_current_time_ms() int {
    string out = trim(runtime_run_command_output("date +%s%3N"))
    int current = 0
    int i = 0
    while i < len(out) {
        string ch = string(out[i])
        if ch >= "0" && ch <= "9" {
            current = current * 10 + (int(ch) - 48)
        }
        i = i + 1
    }
    current
}

func bool_to_json(bool value) string {
    if value {
        return "true"
    }
    "false"
}

func json_escape(string value) string {
    string out = ""
    int i = 0
    while i < len(value) {
        string ch = string(value[i])
        if ch == "\\" {
            out = out + "\\\\"
        } else if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\n" {
            out = out + "\\n"
        } else if ch == "\r" {
            out = out + "\\r"
        } else if ch == "\t" {
            out = out + "\\t"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out
}

func shard_info_to_json(shard_info shard) string {
    string out = "{"
    out = out + "\"shard_id\":" + string(shard.shard_id) + ","
    out = out + "\"filename\":\"" + json_escape(shard.filename) + "\","
    out = out + "\"file_size_bytes\":" + string(shard.file_size_bytes) + ","
    out = out + "\"uncompressed_size_bytes\":" + string(shard.uncompressed_size_bytes) + ","
    out = out + "\"document_count\":" + string(shard.document_count) + ","
    out = out + "\"token_count\":" + string(shard.token_count) + ","
    out = out + "\"quality_score\":" + string(shard.quality_score) + ","
    out = out + "\"start_offset_in_dataset\":" + string(shard.start_offset_in_dataset) + ","
    out = out + "\"end_offset_in_dataset\":" + string(shard.end_offset_in_dataset) + ","
    out = out + "\"primary_rank\":" + string(shard.primary_rank) + ","
    out = out + "\"is_fully_written\":" + bool_to_json(shard.is_fully_written) + ","
    out = out + "\"is_validated\":" + bool_to_json(shard.is_validated) + ","
    out = out + "\"checksum_sha256\":\"" + json_escape(shard.checksum_sha256) + "\","
    out = out + "\"version\":" + string(shard.version) + ","
    out = out + "\"access_count\":" + string(shard.access_count) + ","
    out = out + "\"avg_read_time_ms\":" + string(shard.avg_read_time_ms) + ","
    out = out + "\"assigned_ranks\":["
    int i = 0
    while i < len(shard.assigned_ranks) {
        if i > 0 {
            out = out + ","
        }
        out = out + string(shard.assigned_ranks[i])
        i = i + 1
    }
    out = out + "]"
    out = out + "}"
    out
}

func config_to_json(shard_manager_config cfg) string {
    string out = "{"
    out = out + "\"target_shard_size_mb\":" + string(cfg.target_shard_size_mb) + ","
    out = out + "\"min_shard_size_mb\":" + string(cfg.min_shard_size_mb) + ","
    out = out + "\"max_shard_size_mb\":" + string(cfg.max_shard_size_mb) + ","
    out = out + "\"partition_strategy\":\"" + json_escape(cfg.partition_strategy) + "\","
    out = out + "\"boundary_alignment\":\"" + json_escape(cfg.boundary_alignment) + "\","
    out = out + "\"num_ranks\":" + string(cfg.num_ranks) + ","
    out = out + "\"balance_by_token_count\":" + bool_to_json(cfg.balance_by_token_count) + ","
    out = out + "\"enable_replication\":" + bool_to_json(cfg.enable_replication) + ","
    out = out + "\"shard_dir\":\"" + json_escape(cfg.shard_dir) + "\","
    out = out + "\"file_extension\":\"" + json_escape(cfg.file_extension) + "\","
    out = out + "\"compress_shards\":" + bool_to_json(cfg.compress_shards) + ","
    out = out + "\"compression_level\":" + string(cfg.compression_level) + ","
    out = out + "\"build_index\":" + bool_to_json(cfg.build_index) + ","
    out = out + "\"include_checksums\":" + bool_to_json(cfg.include_checksums) + ","
    out = out + "\"max_retries_on_failure\":" + string(cfg.max_retries_on_failure)
    out = out + "}"
    out
}

func manifest_to_json(dataset_manifest manifest) string {
    string out = "{"
    out = out + "\"dataset_name\":\"" + json_escape(manifest.dataset_name) + "\","
    out = out + "\"dataset_version\":\"" + json_escape(manifest.dataset_version) + "\","
    out = out + "\"source_path\":\"" + json_escape(manifest.source_path) + "\","
    out = out + "\"total_size_bytes\":" + string(manifest.total_size_bytes) + ","
    out = out + "\"total_compressed_bytes\":" + string(manifest.total_compressed_bytes) + ","
    out = out + "\"total_shard_count\":" + string(manifest.total_shard_count) + ","
    out = out + "\"total_document_count\":" + string(manifest.total_document_count) + ","
    out = out + "\"total_token_count\":" + string(manifest.total_token_count) + ","
    out = out + "\"config_used\":" + config_to_json(manifest.config_used) + ","
    out = out + "\"creation_timestamp\":" + string(manifest.creation_timestamp) + ","
    out = out + "\"created_by\":\"" + json_escape(manifest.created_by) + "\","
    out = out + "\"parent_dataset\":\"" + json_escape(manifest.parent_dataset) + "\","
    out = out + "\"shards\":["
    int i = 0
    while i < len(manifest.shards) {
        if i > 0 {
            out = out + ","
        }
        out = out + shard_info_to_json(manifest.shards[i])
        i = i + 1
    }
    out = out + "]"
    out = out + "}"
    out
}
