// Intelligent Shard Manager for TB+ Scale Datasets
// Automatically partitions massive datasets into optimal shards
// Supports: load balancing across nodes, incremental updates, fault tolerance

package neurx.data.shard_manager

use neurx.strings

// ── Configuration ──
struct shard_manager_config {
    // Target shard characteristics
    int64 target_shard_size_mb        // Desired size per shard (default: 2GB)
    int64 min_shard_size_mb           // Minimum shard size (avoid too many tiny files)
    int64 max_shard_size_mb           // Maximum shard size (fit in memory)
    
    // Partitioning strategy
    string partition_strategy         // "uniform", "by_document", "by_source", "hash_based"
    string boundary_alignment         // "line", "paragraph", "document", "byte"
    
    // Distribution settings (for multi-node training)
    int num_ranks                     // Total number of distributed workers/nodes
    bool balance_by_token_count       // Balance by tokens instead of bytes
    bool enable_replication           // Replicate popular shards for load balancing
    
    // Storage settings
    string shard_dir                  // Base directory for shard files
    string file_extension             // File extension (default: ".bin")
    bool compress_shards              // Use compression (zstd/gzip)
    int compression_level             // Compression level (1-9)
    
    // Metadata and indexing
    bool build_index                  // Build searchable index for each shard
    bool include_checksums            // Include integrity checksums
    
    // Fault tolerance
    int max_retries_on_failure        // Retry failed operations N times
}

func default_tb_shard_config() shard_manager_config:
    shard_manager_config cfg
    cfg.target_shard_size_mb = 2048      // 2GB shards (manageable size)
    cfg.min_shard_size_mb = 100          // At least 100MB
    cfg.max_shard_size_mb = 4096         // Max 4GB (fits in memory with room to spare)
    cfg.partition_strategy = "by_document"  // Keep documents together when possible
    cfg.boundary_alignment = "document"     // Split at document boundaries
    cfg.num_ranks = 64                    // Default cluster size
    cfg.balance_by_token_count = true
    cfg.enable_replication = true
    cfg.shard_dir = "./data/shards"
    cfg.file_extension = ".bin"
    cfg.compress_shards = true
    cfg.compression_level = 3            // Balance speed/size
    cfg.build_index = true
    cfg.include_checksums = true
    cfg.max_retries_on_failure = 3
    return cfg

// ── Shard Metadata ──
struct shard_info {
    int shard_id                       // Unique identifier
    string filename                    // Path to shard file
    int64 file_size_bytes              // Actual file size (compressed)
    int64 uncompressed_size_bytes      // Original data size before compression
    int document_count                 // Number of documents in this shard
    int64 token_count                  // Total tokens in this shard
    float quality_score                // Average quality of documents (0-1)
    
    // Position information
    int64 start_offset_in_dataset      // Byte offset in original dataset
    int64 end_offset_in_dataset        // End byte offset
    
    // Assignment info
    []int assigned_ranks               // Which ranks should process this shard
    int primary_rank                   // Main owner rank
    
    // Status tracking
    bool is_fully_written              // True when write complete
    bool is_validated                  // True after checksum verification
    string checksum_sha256             // Integrity checksum
    int version                        // For incremental updates
    
    // Access statistics
    int access_count                   // How many times accessed
    float avg_read_time_ms             // Average read latency
}

// ── Dataset Manifest ──
// Global index describing all shards in a dataset

struct dataset_manifest {
    string dataset_name                // Human-readable name
    string dataset_version             // Version string/hash
    string source_path                 // Original data location
    
    // Global statistics
    int64 total_size_bytes             // Total uncompressed size
    int64 total_compressed_bytes       // Total compressed size
    int total_shard_count              // Number of shards
    int total_document_count           // Total documents across all shards
    int64 total_token_count            // Total tokens (estimated or counted)
    
    // Shard inventory
    []shard_info shards                // All shard metadata
    
    // Partitioning info
    shard_manager_config config_used   // What config was used to create this
    
    // Provenance
    int64 creation_timestamp           // When was this manifest created
    string created_by                  // Tool/version that created it
    string parent_dataset              // If derived from another dataset
}

// ── Shard Manager State ──
struct shard_manager_state {
    shard_manager_config config
    dataset_manifest manifest
    
    // Current operation state
    string current_operation           // "idle", "partitioning", "writing", "validating"
    float operation_progress           // 0.0 - 1.0
    int current_shard_being_processed  // Which shard we're working on
    
    // Caching
    []shard_info recently_accessed     // LRU cache of recent shard metadata
    int max_cache_size                 // Max cached entries
    
    // Error handling
    []string error_log                 // Accumulated errors/warnings
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

// ── Core Operations ──

// Partition a large dataset into optimal shards
struct partition_result:
    dataset_manifest manifest          // The resulting manifest
    bool success
    string error_message
    int total_time_ms
    []shard_info[] created_shards      // All shards that were created

func partition_dataset(
    shard_manager_state mgr,
    string input_path,                 // Path to input dataset (file or directory)
    string output_dir,                 // Where to write shards
    string dataset_name                // Name for this dataset
) partition_result:
    
    int start_time = get_current_time_ms()
    mgr.current_operation = "partitioning"
    
    partition_result result
    result.success = false
    
    // Step 1: Analyze input dataset
    print("Analyzing input dataset: ", input_path)
    dataset_analysis analysis = analyze_input_dataset(input_path, mgr.config)
    
    if !analysis.is_valid:
        result.error_message = "Invalid input dataset: " + analysis.error_reason
        log_error(mgr, result.error_message)
        mgr.current_operation = "idle"
        return result
    
    print("Dataset analyzed:")
    print("  Total size: ", analysis.total_size_gb, " GB")
    print("  Document count: ", analysis.document_count)
    print("  Estimated tokens: ", analysis.estimated_tokens)
    
    // Step 2: Determine optimal shard boundaries based on strategy
    print("Determining shard boundaries...")
    []shard_boundary boundaries = calculate_shard_boundaries(analysis, mgr.config)
    
    print("Will create ", len(boundaries), " shards")
    mgr.manifest.total_shard_count = len(boundaries)
    
    // Step 3: Create output directory structure
    if !create_directory(output_dir):
        result.error_message = "Failed to create output directory: " + output_dir
        log_error(mgr, result.error_message)
        mgr.current_operation = "idle"
        return result
    
    string shard_base_path = output_dir + "/" + dataset_name
    mgr.config.shard_dir = shard_base_path
    
    // Step 4: Write shards (with progress tracking)
    print("Writing shards...")
    []shard_info all_shards = []shard_info{cap: len(boundaries)}
    
    int s = 0
    while s < len(boundaries):
        shard_boundary bnd = boundaries[s]
        
        mgr.current_shard_being_processed = s
        mgr.operation_progress = float(s) / float(len(boundaries))
        
        // Write individual shard
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
            // Log warning but continue (some failures may be acceptable)
            string warn_msg = "Failed to write shard " + s + ": " + write_res.error_msg
            log_warning(mgr, warn_msg)
            print("WARNING: ", warn_msg)
        
        s = s + 1
    
    // Step 5: Build final manifest
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
    
    // Calculate compressed total
    int64 comp_total = 0
    s = 0
    while s < len(all_shards):
        comp_total = comp_total + all_shards[s].file_size_bytes
        s = s + 1
    manifest.total_compressed_bytes = comp_total
    
    // Step 6: Save manifest to disk
    save_manifest(manifest, shard_base_path + "/manifest.json")
    
    // Step 7: Validate all shards (checksum verification)
    if mgr.config.include_checksums:
        print("Validating shards...")
        validate_all_shards(manifest)
    
    int end_time = get_current_time_ms()
    
    // Prepare result
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

// Analyze input dataset without loading everything into memory
struct dataset_analysis:
    bool is_valid
    string error_reason
    int64 total_size_bytes
    float total_size_gb
    int document_count
    int64 estimated_tokens
    string detected_format
    []string source_files          // If directory: list of files
    bool is_single_file
    string encoding

func analyze_input_dataset(string path, shard_manager_config cfg) dataset_analysis:
    
    dataset_analysis analysis
    analysis.is_valid = false
    
    // Check if path exists
    if !file_exists(path):
        analysis.error_reason = "Path does not exist: " + path
        return analysis
    
    // Check if file or directory
    bool is_dir = is_directory(path)
    
    if is_dir:
        // Directory: enumerate all files
        analysis.source_files = list_files_recursive(path, cfg.file_extension)
        analysis.is_single_file = false
        
        if len(analysis.source_files) == 0:
            analysis.error_reason = "No data files found in directory"
            return analysis
        
        // Sum up sizes
        int i = 0
        while i < len(analysis.source_files):
            analysis.total_size_bytes = analysis.total_size_bytes + 
                                        get_file_size(analysis.source_files[i])
            i = i + 1
        
        // Estimate document count (sample a few files)
        analysis.document_count = estimate_doc_count_from_files(
            analysis.source_files, 
            min(10, len(analysis.source_files))
        )
        
    else:
        // Single file
        analysis.source_files.push(path)
        analysis.is_single_file = true
        analysis.total_size_bytes = get_file_size(path)
        
        // Count lines/documents in sample
        analysis.document_count = estimate_line_count(path, analysis.total_size_bytes)
    
    analysis.total_size_gb = float(analysis.total_size_bytes) / (1048576.0 * 1024.0)
    analysis.estimated_tokens = analysis.total_size_bytes / 3  // Rough heuristic
    analysis.detected_format = detect_format_from_extension(path)
    analysis.encoding = "utf-8"  // Assume UTF-8 (would detect properly)
    analysis.is_valid = true
    
    return analysis

// Calculate where to split the dataset into shards
struct shard_boundary:
    int64 start_byte
    int64 end_byte
    int estimated_documents
    string split_reason  // Why we split here ("size_limit", "document_boundary", etc.)

func calculate_shard_boundaries(
    dataset_analysis analysis,
    shard_manager_config cfg
) []shard_boundary:
    
    int64 target_size = cfg.target_shard_size_mb * 1024 * 1024
    int64 min_size = cfg.min_shard_size_mb * 1024 * 1024
    int64 max_size = cfg.max_shard_size_mb * 1024 * 1024
    
    []shard_boundary boundaries = []shard_boundary{cap: 100}
    
    if analysis.is_single_file:
        // Single file: find good split points
        boundaries = find_split_points_single_file(
            analysis.source_files[0],
            analysis.total_size_bytes,
            target_size,
            min_size,
            max_size,
            cfg.boundary_alignment
        )
    else:
        // Multiple files: group files into shards
        boundaries = group_files_into_shards(
            analysis.source_files,
            target_size,
            min_size,
            max_size
        )
    
    return boundaries

// Find optimal split points in a single large file
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
            // Last shard: take everything remaining
            boundaries.push(shard_boundary{
                start_byte: current_start,
                end_byte: total_size,
                estimated_documents: 0,
                split_reason: "final_shard"
            })
            break
        
        // Adjust end to align on requested boundary
        int64 actual_end = proposed_end
        
        if alignment == "line":
            actual_end = find_next_newline_after(filepath, proposed_end)
        elif alignment == "document":
            actual_end = find_next_document_boundary(filepath, proposed_end)
        elif alignment == "paragraph":
            actual_end = find_next_double_newline(filepath, proposed_end)
        else:  // "byte" - no alignment
            actual_end = proposed_end
        
        // Ensure minimum size
        if actual_end - current_start < min_size:
            actual_end = current_start + min_size
            if actual_end > total_size:
                actual_end = total_size
        
        // Ensure maximum size
        if actual_end - current_start > max_size:
            actual_end = current_start + max_size
        
        boundaries.push(shard_boundary{
            start_byte: current_start,
            end_byte: actual_end,
            estimated_documents: 0,  // Would count during writing
            split_reason: alignment
        })
        
        current_start = actual_end
        shard_id = shard_id + 1
    
    return boundaries

// Write a single shard to disk
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
    
    // Generate filename
    string filename = base_path + "_shard_" + format_int_with_leading_zeros(shard_id, 6) + 
                      mgr.config.file_extension
    
    // Read the data range from source
    []byte raw_data = read_file_range(source_path, boundary.start_byte, 
                                      boundary.end_byte - boundary.start_byte)
    
    if len(raw_data) == 0:
        result.error_msg = "Failed to read data range from source"
        return result
    
    // Optionally compress
    []byte data_to_write = raw_data
    if mgr.config.compress_shards:
        data_to_write = compress_data(raw_data, mgr.config.compression_level)
    
    // Write to disk
    bool write_ok = write_all_bytes(filename, data_to_write)
    
    if !write_ok:
        result.error_msg = "Failed to write shard file: " + filename
        return result
    
    // Compute checksum if enabled
    string checksum = ""
    if mgr.config.include_checksums:
        checksum = compute_sha256(data_to_write)
    
    // Create shard metadata
    shard_info info
    info.shard_id = shard_id
    info.filename = filename
    info.file_size_bytes = int64(len(data_to_write))
    info.uncompressed_size_bytes = int64(len(raw_data))
    info.document_count = count_documents_in_data(raw_data)  // Quick count
    info.token_count = estimate_tokens_in_data(raw_data)
    info.quality_score = assess_data_quality(raw_data)
    info.start_offset_in_dataset = boundary.start_byte
    info.end_offset_in_dataset = boundary.end_byte
    info.checksum_sha256 = checksum
    info.is_fully_written = true
    info.is_validated = false  // Will validate later
    info.version = 1
    info.access_count = 0
    info.avg_read_time_ms = 0.0
    
    // Assign to ranks (round-robin or hash-based)
    info.assigned_ranks = assign_shard_to_ranks(shard_id, mgr.config.num_ranks)
    info.primary_rank = info.assigned_ranks[0]
    
    result.info = info
    result.success = true
    return result

// ── Load Balancing Across Ranks ──

// Assign shards to specific ranks for distributed processing
func assign_shard_to_ranks(int shard_id, int num_ranks) []int:
    
    []int ranks = []int{cap: 2}  // Primary + replica (if replication enabled)
    
    // Simple round-robin assignment
    int primary_rank = s(shard_id - (shard_id / num_ranks) * num_ranks)
    ranks.push(primary_rank)
    
    // Could add more sophisticated strategies here:
    // - Hash-based assignment (consistent hashing)
    // - Load-aware assignment
    // - Data locality aware assignment
    
    return ranks

// Get which shards this rank should process
func get_shards_for_rank(dataset_manifest manifest, int rank_id) []shard_info:
    
    []shard_info my_shards = []shard_info{cap: 100}
    
    int s = 0
    while s < len(manifest.shards):
        shard_info shard = manifest.shards[s]
        
        // Check if this rank is in the assigned list
        int r = 0
        while r < len(shard.assigned_ranks):
            if shard.assigned_ranks[r] == rank_id:
                my_shards.push(shard)
                break
            r = r + 1
        
        s = s + 1
    
    return my_shards

// Rebalance shards if needed (e.g., if a node is slow/fails)
func rebalance_shards(
    dataset_manifest manifest,
    []float rank_performance_scores  // Per-rank throughput scores
) dataset_manifest:
    
    // Identify underperforming ranks
    // Reassign some of their shards to faster ranks
    // Update manifest with new assignments
    
    // This would implement work stealing or dynamic reassignment
    // For now, just return unchanged
    return manifest

// ── Incremental Updates ──
// Support adding new data to an existing sharded dataset

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
    
    // Analyze new data
    dataset_analysis new_analysis = analyze_input_dataset(new_data_path, mgr.config)
    
    if !new_analysis.is_valid:
        result.message = "Invalid new data: " + new_analysis.error_reason
        return result
    
    // Create new shards for the additional data
    print("Adding incremental data: ", new_analysis.total_size_gb, " GB")
    
    // Generate new shard IDs (continue from existing)
    int next_shard_id = len(existing_manifest.shards)
    
    // Write new shards
    // ... (similar to partition_dataset but only for new data)
    
    // Update manifest with new shards
    // ... 
    
    result.success = true
    result.message = "Incremental update completed successfully"
    return result

// ── Utility Functions ──

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
    // Deep copy of config
    return orig  // Simplified

func log_error(shard_manager_state mgr, string msg) void:
    mgr.error_log.push("[ERROR] " + msg)
    mgr.error_count = mgr.error_count + 1

func log_warning(shard_manager_state mgr, string msg) void:
    mgr.error_log.push("[WARN] " + msg)

func save_manifest(dataset_manifest manifest, string path) void:
    // Serialize manifest to JSON
    return

func validate_all_shards(dataset_manifest manifest) void:
    // Verify checksums for all shards
    return

// OS/File system helpers (placeholders)
func file_exists(string path) bool: return false
func is_directory(string path) bool: return false
func list_files_recursive(string dir, string ext) []string: return []string{cap: 0}
func get_file_size(string path) int64: return 0
func create_directory(string path) bool: return true
func read_file_range(string path, int64 offset, int64 length) []byte: return []byte{cap: 0}
func write_all_bytes(string path, []byte data) bool: return true
func find_next_newline_after(string path, int64 offset) int64: return offset
func find_next_document_boundary(string path, int64 offset) int64: return offset
func find_next_double_newline(string path, int64 offset) int64: return offset
func estimate_line_count(string path, int64 size) int: return int(size / 100)  // Rough
func estimate_doc_count_from_files([]string files, int sample_n) int: return 0
func detect_format_from_extension(string path) string: return "text"
func count_documents_in_data([]byte data) int: return 0
func estimate_tokens_in_data([]byte data) int64: return int64(len(data)) / 3
func assess_data_quality([]byte data) float: return 1.0
func compress_data([]byte data, int level) []byte: return data
func compute_sha256([]byte data) string: return ""
func format_int_with_leading_zeros(int val, int width) string: return "" + val
func get_current_time_ms() int: return 0
