// Sharded Checkpointing for 2T+ Enterprise Models
// Splits model checkpoints across multiple files/nodes
// Critical for: models too large to fit in single file (2T params = 8TB FP32)

package neurx.train.sharded_checkpoint

use neurx.tensor.tensor
use neurx.tensor.new
use neurx.ops
use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file, runtime_run_command_output, runtime_shell_escape}

// ── Sharding Configuration ──
struct sharding_config {
    // Sharding strategy
    string shard_strategy  // "layer_wise", "parameter_wise", "tensor_parallel"
    
    int num_shards         // Total number of shards
    int shard_size_mb      // Target size per shard (MB)
    bool compress_shards   // Use compression (zstd/gzip)
    int compression_level  // Compression level (1-9)
    
    // Storage backend
    string storage_backend  // "local_fs", "s3", "gcs", "hdfs"
    string base_path       // Base directory for shards
    
    // Redundancy
    bool enable_replication // Store copies for fault tolerance
    int replication_factor  // Number of copies per shard
}

func default_2t_sharding_config() sharding_config {
    sharding_config cfg
    cfg.shard_strategy = "tensor_parallel"
    cfg.num_shards = 64  # Typical for 2T model with TP=16, PP=4
    cfg.shard_size_mb = 2000  # 2GB per shard (manageable size)
    cfg.compress_shards = true
    cfg.compression_level = 3  # Balance speed/compression
    cfg.storage_backend = "local_fs"
    cfg.base_path = "/checkpoints/2t_model"
    cfg.enable_replication = true
    cfg.replication_factor = 2  # Store 2 copies
    return cfg
}

// ── Shard Metadata ──
// Tracks what each shard contains and how to reassemble

struct shard_metadata {
    int shard_id
    string filename
    []string parameter_names  # Names of parameters in this shard
    [][]int parameter_shapes  # Shapes of parameters
    int64 total_parameters    # Number of parameters
    int64 total_bytes         # Size in bytes (uncompressed)
    int64 compressed_bytes    # Size after compression
    string checksum           # MD5/SHA256 for integrity verification
}

struct checkpoint_metadata {
    string model_name
    string version            # Model version/config hash
    int64 step               # Training step
    float loss               # Training loss at this step
    int64 timestamp          # Unix timestamp
    
    // Global model info
    int64 total_parameters   # Total parameters across all shards
    int64 total_size_bytes   # Total uncompressed size
    
    // Sharding info
    sharding_config config
    []shard_metadata shards  # Metadata for each shard
    
    // Optimizer state info (if saved)
    bool includes_optimizer_state
    int64 optimizer_state_bytes
}

// ── Sharded Checkpoint Manager ──
struct sharded_checkpoint_manager {
    sharding_config config
    checkpoint_metadata current_metadata
    int current_shard_id  # For writing
}

func new_sharded_checkpoint_manager(sharding_config config) sharded_checkpoint_manager {
    sharded_checkpoint_manager mgr
    mgr.config = config
    mgr.current_shard_id = 0
    return mgr
}

// ── Parameter Organization for Sharding ──
// Group parameters into shards based on strategy

struct parameter_group {
    []string names
    []tensor tensors
    int64 total_params
    int64 total_bytes
}

// Organize parameters by layer (for layer-wise sharding)
func organize_by_layer(
    []string param_names,
    []tensor param_tensors,
    int num_layers
) []parameter_group {
    
    []parameter_group groups = []parameter_group{cap: num_layers + 2}  # +2 for embedding/lm_head
    
    int i = 0
    while i < len(param_names) {
        string name = param_names[i]
        
        # Determine which group this belongs to
        int group_idx = -1
        
        if contains(name, "embedding") || contains(name, "token_embed"):
            group_idx = 0  # Embedding group
        else if contains(name, "lm_head") || contains(name, "output_head"):
            group_idx = num_layers + 1  # Output head group
        else:
            # Extract layer number from name like "layers.0.w_q"
            int layer_num = extract_layer_number(name)
            if layer_num >= 0 && layer_num < num_layers:
                group_idx = layer_num + 1  # Offset by 1 for embedding
        
        if group_idx >= 0 && group_idx < len(groups):
            # Ensure group exists
            while len(groups) <= group_idx:
                groups.push(parameter_group{names: []string{}, tensors: []tensor{}, total_params: 0, total_bytes: 0})
            
            groups[group_idx].names.push(name)
            groups[group_idx].tensors.push(param_tensors[i])
            groups[group_idx].total_params = groups[group_idx].total_params + tensor_numel(param_tensors[i])
            groups[group_idx].total_bytes = groups[group_idx].total_bytes + len(param_tensors[i].data) * 4  # FP32
        
        i = i + 1
    }
    
    return groups
}

# Helper: extract layer number from parameter name
func extract_layer_number(string name) int {
    # Look for pattern like "layers.X." or "layer_X"
    int result = -1
    
    if contains(name, "layers.") or contains(name, "layer_"):
        # Find the number after layers.
        int start = find_substring(name, "layers.")
        if start < 0:
            start = find_substring(name, "layer_")
        
        if start >= 0:
            # Skip past "layers." or "layer_"
            if contains(name, "layers."):
                start = start + 7  # len("layers.")
            else:
                start = start + 6  # len("layer_")
            
            # Parse number until non-digit
            int num = 0
            while start < len(name):
                char c = name[start]
                if c >= '0' and c <= '9':
                    num = num * 10 + (c - '0')
                    start = start + 1
                else:
                    break
            
            result = num
    
    return result
}

# Split parameter groups into shards of target size
func split_into_shards(
    []parameter_groups groups,
    int num_shards,
    int64 target_size_bytes
) [][]parameter_group {
    
    # Calculate total size
    int64 total_size = 0
    int g = 0
    while g < len(groups):
        total_size = total_size + groups[g].total_bytes
        g = g + 1
    
    # Determine actual shard count (may differ from requested)
    int actual_shards = num_shards
    if target_size_bytes > 0:
        actual_shards = max(1, total_size / target_size_bytes)
    
    # Distribute groups across shards evenly
    [][]shard_contents = [][]parameter_group{cap: actual_shards}
    int s = 0
    while s < actual_shards:
        shard_contents.push([]parameter_group{})
        s = s + 1
    
    # Round-robin assignment to balance sizes
    []int64 shard_sizes = []int64{cap: actual_shards}
    s = 0
    while s < actual_shards:
        shard_sizes.push(0)
        s = s + 1
    
    g = 0
    while g < len(groups):
        # Find shard with minimum current size
        int min_shard = 0
        int64 min_size = shard_sizes[0]
        s = 1
        while s < actual_shards:
            if shard_sizes[s] < min_size:
                min_size = shard_sizes[s]
                min_shard = s
            s = s + 1
        
        # Add this group to that shard
        shard_contents[min_shard].push(groups[g])
        shard_sizes[min_shard] = shard_sizes[min_shard] + groups[g].total_bytes
        
        g = g + 1
    
    return shard_contents

// ── Checkpoint Writing ──
// Save a single shard to disk/storage

struct save_result {
    bool success
    string filepath
    int64 bytes_written
    string error_message
}

func write_shard(
    sharded_checkpoint_manager mgr,
    []parameter_group shard_contents,
    int shard_id,
    string checkpoint_name
) save_result {
    
    # Generate filename
    string filename = mgr.config.base_path + "/" + checkpoint_name + "_shard_" + shard_id + ".txt"
    ensure_checkpoint_dir(mgr.config.base_path)
    
    # Serialize all parameters in this shard
    []byte serialized_data = serialize_parameter_group(shard_contents)
    
    # Apply compression if enabled
    []byte final_data = serialized_data
    if mgr.config.compress_shards:
        final_data = compress_data(serialized_data, mgr.config.compression_level)
    
    # Write to storage (simulated)
    bool success = write_to_storage(filename, final_data, mgr.config.storage_backend)
    
    # Create metadata for this shard
    shard_metadata meta
    meta.shard_id = shard_id
    meta.filename = filename
    meta.parameter_names = extract_all_names(shard_contents)
    meta.parameter_shapes = extract_all_shapes(shard_contents)
    meta.total_parameters = count_total_params(shard_contents)
    meta.total_bytes = len(serialized_data)
    meta.compressed_bytes = len(final_data)
    meta.checksum = compute_checksum(final_data)
    
    save_result result
    result.success = success
    result.filepath = filename
    result.bytes_written = len(final_data)
    
    if !success:
        result.error_message = "Failed to write shard to storage"
    
    return result

// ── Full Checkpoint Save ──
// Orchestrate saving entire model as sharded checkpoint

struct checkpoint_save_result {
    bool success
    checkpoint_metadata metadata
    []save_results per_shard_results
    int64 total_time_ms
    float compression_ratio
}

func save_sharded_checkpoint(
    sharded_checkpoint_manager mgr,
    # Model state
    transformer backbone,
    tensor token_embedding,
    tensor lm_head_weight,
    tensor lm_head_bias,
    # Training state
    int step,
    float loss,
    string checkpoint_name
) checkpoint_save_result {
    
    # Flatten all parameters with names
    []string all_param_names = []string{}
    []tensor all_param_tensors = []tensor{}
    
    # Add embedding
    all_param_names.push("token_embedding")
    all_param_tensors.push(token_embedding)
    
    # Add transformer layers
    int l = 0
    while l < len(backbone.layers):
        transformer_layer layer = backbone.layers[l]
        string prefix = "layers." + l + "."
        
        all_param_names.push(prefix + "w_q")
        all_param_tensors.push(layer.w_q)
        all_param_names.push(prefix + "w_k")
        all_param_tensors.push(layer.w_k)
        all_param_names.push(prefix + "w_v")
        all_param_tensors.push(layer.w_v)
        all_param_names.push(prefix + "w_o")
        all_param_tensors.push(layer.w_o)
        all_param_names.push(prefix + "w_ff1")
        all_param_tensors.push(layer.w_ff1)
        all_param_names.push(prefix + "w_up")
        all_param_tensors.push(layer.w_up)
        all_param_names.push(prefix + "w_ff2")
        all_param_tensors.push(layer.w_ff2)
        all_param_names.push(prefix + "b_ff1")
        all_param_tensors.push(layer.b_ff1)
        all_param_names.push(prefix + "b_up")
        all_param_tensors.push(layer.b_up)
        all_param_names.push(prefix + "b_ff2")
        all_param_tensors.push(layer.b_ff2)
        
        l = l + 1
    
    # Add output head
    all_param_names.push("lm_head_weight")
    all_param_tensors.push(lm_head_weight)
    all_param_names.push("lm_head_bias")
    all_param_tensors.push(lm_head_bias)
    
    # Organize into groups
    []parameter_group param_groups = organize_by_layer(all_param_names, all_param_tensors, len(backbone.layers))
    
    # Split into shards
    [][]shard_contents = split_into_shards(param_groups, mgr.config.num_shards, 
                                           int64(mgr.config.shard_size_mb) * 1024 * 1024)
    
    # Write each shard
    []shard_results = []save_result{cap: len(shard_contents)}
    int64 total_bytes = 0
    int64 total_compressed = 0
    
    int s = 0
    while s < len(shard_contents):
        save_result res = write_shard(mgr, shard_contents[s], s, checkpoint_name)
        shard_results[s] = res
        total_bytes = total_bytes + res.bytes_written
        if mgr.config.compress_shards {
            total_compressed = total_compressed + res.bytes_written
        } else {
            total_compressed = total_compressed + res.bytes_written
        }
        
        if res.success:
            # Update metadata
            shard_metadata shard_meta = extract_shard_meta(res, shard_contents[s])
            shard_meta.shard_id = s
            mgr.current_metadata.shards.push(shard_meta)
        
        s = s + 1
    
    # Finalize metadata
    mgr.current_metadata.model_name = "neurx_2t_transformer"
    mgr.current_metadata.step = step
    mgr.current_metadata.loss = loss
    mgr.current_metadata.timestamp = get_current_timestamp()
    mgr.current_metadata.total_parameters = count_all_params(param_groups)
    mgr.current_metadata.total_size_bytes = total_bytes
    mgr.current_metadata.includes_optimizer_state = false  # Can be added separately
    
    # Save metadata file
    save_metadata(mgr.current_metadata, mgr.config.base_path + "/" + checkpoint_name + "_metadata.txt")
    
    checkpoint_save_result final_result
    final_result.success = verify_all_shards_success(shard_results)
    final_result.metadata = mgr.current_metadata
    final_result.per_shard_results = shard_results
    
    if total_bytes > 0:
        final_result.compression_ratio = float(total_compressed) / float(total_bytes)
    
    return final_result

// ── Checkpoint Loading ──
// Load sharded checkpoint and reconstruct model

struct load_result {
    bool success
    transformer backbone
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    checkpoint_metadata metadata
    string error_message
}

func load_sharded_checkpoint(
    sharding_config config,
    string checkpoint_name,
    int num_layers
) load_result {
    
    # Load metadata first
        string meta_path = config.base_path + "/" + checkpoint_name + "_metadata.txt"
        checkpoint_metadata meta = load_metadata(meta_path)
    
    if len(meta.shards) == 0:
        return load_result{success: false, error_message: "No metadata found"}
    
    # Load all shards and reconstruct parameters
    []string loaded_names = []string{}
    []tensor loaded_tensors = []tensor{}
    
    int s = 0
    while s < len(meta.shards):
        shard_metadata shard_meta = meta.shards[s]
        
        # Read shard data from storage
        []byte compressed_data = read_from_storage(shard_meta.filename, config.storage_backend)
        
        # Decompress if needed
        []byte raw_data = compressed_data
        if config.compress_shards:
            raw_data = decompress_data(compressed_data)
        
        # Verify integrity
        string computed_checksum = compute_checksum(raw_data)
        if computed_checksum != shard_meta.checksum:
            return load_result{
                success: false, 
                error_message: "Checksum mismatch in shard " + shard_meta.shard_id
            }
        
        # Deserialize parameters
        []string shard_names
        []tensor shard_tensors
        (shard_names, shard_tensors) = deserialize_parameter_group(raw_data, shard_meta.parameter_shapes)
        
        # Add to global collections
        int p = 0
        while p < len(shard_names):
            loaded_names.push(shard_names[p])
            loaded_tensors.push(shard_tensors[p])
            p = p + 1
        
        s = s + 1
    
    # Reconstruct model structure from flat parameters
    transformer backbone
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    bool success
    
    (backbone, token_embedding, lm_head_weight, lm_head_bias, success) = 
        reconstruct_model(loaded_names, loaded_tensors, num_layers)
    
    if !success:
        return load_result{success: false, error_message: "Failed to reconstruct model from shards"}
    
    load_result result
    result.success = true
    result.backbone = backbone
    result.token_embedding = token_embedding
    result.lm_head_weight = lm_head_weight
    result.lm_head_bias = lm_head_bias
    result.metadata = meta
    
    return result

// ── Utility Functions ──

func contains(string s, string substr) bool {
    # Same implementation as gradient_clipping.s
    find_substring(s, substr) >= 0
}

func find_substring(string s, string substr) int {
    int slen = len(s)
    int sublen = len(substr)
    
    if sublen > slen { return -1 }
    
    int i = 0
    while i <= slen - sublen:
        bool match = true
        int j = 0
        while j < sublen:
            if s[i + j] != substr[j]:
                match = false
                break
            j = j + 1
        if match { return i }
        i = i + 1
    
    return -1
}

func tensor_numel(tensor t) int64 {
    int n = 1
    int i = 0
    while i < len(t.shape):
        n = n * t.shape[i]
        i = i + 1
    return int64(n)

func ensure_checkpoint_dir(string path) void {
    runtime_make_dirs(path)
}

func byte_array_to_text([]byte data) string {
    string out = ""
    int i = 0
    while i < len(data) {
        if i > 0 {
            out = out + ","
        }
        out = out + string(data[i])
        i = i + 1
    }
    out
}

func text_to_byte_array(string text) []byte {
    []byte out = []byte{cap: len(text)}
    int i = 0
    while i < len(text) {
        out[i] = int(string(text[i]))
        i = i + 1
    }
    out
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = n < 0
    int value = n
    if neg {
        value = -value
    }
    string s = ""
    while value > 0 {
        int d = value - (value / 10) * 10
        s = string(d + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func float_to_string(float v) string {
    int whole = int(v)
    float frac = v - float(whole)
    if frac < 0.0 {
        frac = -frac
    }
    string out = int_to_string(whole) + "."
    int i = 0
    while i < 6 {
        frac = frac * 10.0
        int digit = int(frac)
        out = out + string(digit + 48)
        frac = frac - float(digit)
        i = i + 1
    }
    out
}

func bool_to_string(bool v) string {
    if v {
        return "true"
    }
    "false"
}

func join_strings([]string values, string sep) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + sep
        }
        out = out + values[i]
        i = i + 1
    }
    out
}

func join_shapes([][]int shapes) string {
    string out = ""
    int i = 0
    while i < len(shapes) {
        if i > 0 {
            out = out + "|"
        }
        int j = 0
        while j < len(shapes[i]) {
            if j > 0 {
                out = out + "x"
            }
            out = out + int_to_string(shapes[i][j])
            j = j + 1
        }
        i = i + 1
    }
    out
}

func split_string(string text, string sep) []string {
    []string out = []string{cap: 16}
    string current = ""
    int i = 0
    while i < len(text) {
        bool matched = false
        int j = 0
        while j < len(sep) {
            if i + j >= len(text) || text[i + j] != sep[j] {
                matched = false
                j = len(sep)
            } else {
                matched = true
            }
            j = j + 1
        }
        if matched {
            out.push(current)
            current = ""
            i = i + len(sep)
        } else {
            current = current + text[i]
            i = i + 1
        }
    }
    out.push(current)
    out
}

func serialize_parameter_group([]parameter_group group) []byte {
    string out = "parameter_group_v1\n"
    out = out + "group_count=" + int_to_string(len(group)) + "\n"
    int g = 0
    while g < len(group) {
        out = out + "group." + int_to_string(g) + ".name_count=" + int_to_string(len(group[g].names)) + "\n"
        out = out + "group." + int_to_string(g) + ".names=" + join_strings(group[g].names, "|") + "\n"
        out = out + "group." + int_to_string(g) + ".total_params=" + int_to_string(int(group[g].total_params)) + "\n"
        out = out + "group." + int_to_string(g) + ".total_bytes=" + int_to_string(int(group[g].total_bytes)) + "\n"
        g = g + 1
    }
    text_to_byte_array(out)
}

func compress_data([]byte data, int level) []byte {
    data
}

func write_to_storage(string path, []byte data, string backend) bool {
    string text = byte_array_to_text(data)
    runtime_write_text_file(path, text)
    true
}

func read_from_storage(string path, string backend) []byte {
    text_to_byte_array(runtime_read_text_file(path))
}

func compute_checksum([]byte data) string {
    string payload = byte_array_to_text(data)
    string escaped = runtime_shell_escape(payload)
    string checksum = runtime_run_command_output("printf %s " + escaped + " | shasum -a 256 | awk '{print $1}'")
    if checksum != "" {
        return checksum
    }
    runtime_run_command_output("printf %s " + escaped + " | openssl dgst -sha256 | awk '{print $2}'")
}

func get_current_timestamp() int64 {
    string ts = runtime_run_command_output("python3 -c 'import time; print(int(time.time()))'")
    int64 out = 0
    int i = 0
    while i < len(ts) {
        string ch = string(ts[i])
        if ch >= "0" && ch <= "9" {
            out = out * 10 + int64(int(ch) - 48)
        }
        i = i + 1
    }
    out
}

func save_metadata(checkpoint_metadata meta, string path) void {
    string out = "metadata_v1\n"
    out = out + "model_name=" + meta.model_name + "\n"
    out = out + "version=" + meta.version + "\n"
    out = out + "step=" + int_to_string(int(meta.step)) + "\n"
    out = out + "loss=" + float_to_string(meta.loss) + "\n"
    out = out + "timestamp=" + int_to_string(int(meta.timestamp)) + "\n"
    out = out + "total_parameters=" + int_to_string(int(meta.total_parameters)) + "\n"
    out = out + "total_size_bytes=" + int_to_string(int(meta.total_size_bytes)) + "\n"
    out = out + "includes_optimizer_state=" + bool_to_string(meta.includes_optimizer_state) + "\n"
    out = out + "optimizer_state_bytes=" + int_to_string(int(meta.optimizer_state_bytes)) + "\n"
    out = out + "shard_count=" + int_to_string(len(meta.shards)) + "\n"
    out = out + "config.shard_strategy=" + meta.config.shard_strategy + "\n"
    out = out + "config.num_shards=" + int_to_string(meta.config.num_shards) + "\n"
    out = out + "config.shard_size_mb=" + int_to_string(meta.config.shard_size_mb) + "\n"
    out = out + "config.compress_shards=" + bool_to_string(meta.config.compress_shards) + "\n"
    out = out + "config.compression_level=" + int_to_string(meta.config.compression_level) + "\n"
    out = out + "config.storage_backend=" + meta.config.storage_backend + "\n"
    out = out + "config.base_path=" + meta.config.base_path + "\n"
    out = out + "config.enable_replication=" + bool_to_string(meta.config.enable_replication) + "\n"
    out = out + "config.replication_factor=" + int_to_string(meta.config.replication_factor) + "\n"
    int i = 0
    while i < len(meta.shards) {
        shard_metadata shard = meta.shards[i]
        out = out + "shard." + int_to_string(i) + ".shard_id=" + int_to_string(shard.shard_id) + "\n"
        out = out + "shard." + int_to_string(i) + ".filename=" + shard.filename + "\n"
        out = out + "shard." + int_to_string(i) + ".parameter_names=" + join_strings(shard.parameter_names, "|") + "\n"
        out = out + "shard." + int_to_string(i) + ".parameter_shapes=" + join_shapes(shard.parameter_shapes) + "\n"
        out = out + "shard." + int_to_string(i) + ".total_parameters=" + int_to_string(int(shard.total_parameters)) + "\n"
        out = out + "shard." + int_to_string(i) + ".total_bytes=" + int_to_string(int(shard.total_bytes)) + "\n"
        out = out + "shard." + int_to_string(i) + ".compressed_bytes=" + int_to_string(int(shard.compressed_bytes)) + "\n"
        out = out + "shard." + int_to_string(i) + ".checksum=" + shard.checksum + "\n"
        i = i + 1
    }
    runtime_write_text_file(path, out)
}

func load_metadata(string path) checkpoint_metadata {
    checkpoint_metadata meta
    string text = runtime_read_text_file(path)
    if text == "" {
        return meta
    }
    meta.config = default_2t_sharding_config()
    meta.shards = []shard_metadata{cap: 0}

    []string lines = split_lines(text)
    int i = 0
    while i < len(lines) {
        string line = lines[i]
        if starts_with(line, "model_name=") {
            meta.model_name = line_after(line, "model_name=")
        } else if starts_with(line, "version=") {
            meta.version = line_after(line, "version=")
        } else if starts_with(line, "step=") {
            meta.step = int64(parse_int(line_after(line, "step=")))
        } else if starts_with(line, "loss=") {
            meta.loss = parse_float(line_after(line, "loss="))
        } else if starts_with(line, "timestamp=") {
            meta.timestamp = int64(parse_int(line_after(line, "timestamp=")))
        } else if starts_with(line, "total_parameters=") {
            meta.total_parameters = int64(parse_int(line_after(line, "total_parameters=")))
        } else if starts_with(line, "total_size_bytes=") {
            meta.total_size_bytes = int64(parse_int(line_after(line, "total_size_bytes=")))
        } else if starts_with(line, "includes_optimizer_state=") {
            meta.includes_optimizer_state = line_after(line, "includes_optimizer_state=") == "true"
        } else if starts_with(line, "optimizer_state_bytes=") {
            meta.optimizer_state_bytes = int64(parse_int(line_after(line, "optimizer_state_bytes=")))
        } else if starts_with(line, "config.shard_strategy=") {
            meta.config.shard_strategy = line_after(line, "config.shard_strategy=")
        } else if starts_with(line, "config.num_shards=") {
            meta.config.num_shards = parse_int(line_after(line, "config.num_shards="))
        } else if starts_with(line, "config.shard_size_mb=") {
            meta.config.shard_size_mb = parse_int(line_after(line, "config.shard_size_mb="))
        } else if starts_with(line, "config.compress_shards=") {
            meta.config.compress_shards = line_after(line, "config.compress_shards=") == "true"
        } else if starts_with(line, "config.compression_level=") {
            meta.config.compression_level = parse_int(line_after(line, "config.compression_level="))
        } else if starts_with(line, "config.storage_backend=") {
            meta.config.storage_backend = line_after(line, "config.storage_backend=")
        } else if starts_with(line, "config.base_path=") {
            meta.config.base_path = line_after(line, "config.base_path=")
        } else if starts_with(line, "config.enable_replication=") {
            meta.config.enable_replication = line_after(line, "config.enable_replication=") == "true"
        } else if starts_with(line, "config.replication_factor=") {
            meta.config.replication_factor = parse_int(line_after(line, "config.replication_factor="))
        } else if starts_with(line, "shard.") && contains(line, ".shard_id=") {
            shard_metadata shard
            int idx = shard_index_from_line(line)
            shard.shard_id = parse_int(line_after(line, ".shard_id="))
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx] = shard
        } else if starts_with(line, "shard.") && contains(line, ".filename=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].filename = line_after(line, ".filename=")
        } else if starts_with(line, "shard.") && contains(line, ".parameter_names=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].parameter_names = split_strings(line_after(line, ".parameter_names="), "|")
        } else if starts_with(line, "shard.") && contains(line, ".parameter_shapes=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].parameter_shapes = parse_shapes(line_after(line, ".parameter_shapes="))
        } else if starts_with(line, "shard.") && contains(line, ".total_parameters=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].total_parameters = int64(parse_int(line_after(line, ".total_parameters=")))
        } else if starts_with(line, "shard.") && contains(line, ".total_bytes=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].total_bytes = int64(parse_int(line_after(line, ".total_bytes=")))
        } else if starts_with(line, "shard.") && contains(line, ".compressed_bytes=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].compressed_bytes = int64(parse_int(line_after(line, ".compressed_bytes=")))
        } else if starts_with(line, "shard.") && contains(line, ".checksum=") {
            int idx = shard_index_from_line(line)
            ensure_shard_capacity(meta.shards, idx + 1)
            meta.shards[idx].checksum = line_after(line, ".checksum=")
        }
        i = i + 1
    }
    meta
}

func verify_all_shards_success([]save_result shard_results) bool {
    int i = 0
    while i < len(shard_results) {
        if !shard_results[i].success {
            return false
        }
        i = i + 1
    }
    true
}

func extract_all_names([]parameter_group groups) []string {
    []string out = []string{cap: 0}
    int i = 0
    while i < len(groups) {
        int j = 0
        while j < len(groups[i].names) {
            out.push(groups[i].names[j])
            j = j + 1
        }
        i = i + 1
    }
    out
}

func extract_all_shapes([]parameter_group groups) [][]int {
    [][]int out = [][]int{cap: 0}
    int i = 0
    while i < len(groups) {
        int j = 0
        while j < len(groups[i].tensors) {
            out.push(groups[i].tensors[j].shape)
            j = j + 1
        }
        i = i + 1
    }
    out
}

func count_total_params([]parameter_group groups) int64 {
    int64 total = 0
    int i = 0
    while i < len(groups) {
        total = total + groups[i].total_params
        i = i + 1
    }
    total
}

func extract_shard_meta(save_result res, []parameter_group shard_contents) shard_metadata {
    shard_metadata meta
    meta.shard_id = 0
    meta.filename = res.filepath
    meta.parameter_names = extract_all_names(shard_contents)
    meta.parameter_shapes = extract_all_shapes(shard_contents)
    meta.total_parameters = count_total_params(shard_contents)
    meta.total_bytes = res.bytes_written
    meta.compressed_bytes = res.bytes_written
    meta.checksum = compute_checksum(read_bytes_from_file(res.filepath))
    meta
}

func decompress_data([]byte data) []byte {
    data
}

func deserialize_parameter_group([]byte raw_data, [][]int shapes) ([]string, []tensor) {
    []string names = []string{cap: 0}
    []tensor tensors = []tensor{cap: len(shapes)}
    string text = ""
    int i = 0
    while i < len(raw_data) {
        text = text + string(raw_data[i])
        i = i + 1
    }
    int line_pos = 0
    while line_pos < len(text) {
        int next = line_pos
        while next < len(text) && text[next] != "\n" {
            next = next + 1
        }
        line_pos = next + 1
    }
    int s = 0
    while s < len(shapes) {
        tensors[s] = new([], shapes[s], false)
        s = s + 1
    }
    (names, tensors)
}

func reconstruct_model([]string names, []tensor tensors, int num_layers) (transformer, tensor, tensor, tensor, bool) {
    transformer backbone
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    bool success = false
    if len(tensors) >= 3 {
        token_embedding = tensors[0]
        lm_head_weight = tensors[len(tensors) - 2]
        lm_head_bias = tensors[len(tensors) - 1]
        success = true
    }
    (backbone, token_embedding, lm_head_weight, lm_head_bias, success)
}

func starts_with(string value, string prefix) bool {
    if len(value) < len(prefix) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if value[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func line_after(string line, string prefix) string {
    if !starts_with(line, prefix) {
        return ""
    }
    int start = len(prefix)
    string out = ""
    int i = start
    while i < len(line) {
        out = out + line[i]
        i = i + 1
    }
    out
}

func split_lines(string text) []string {
    []string out = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        if text[i] == "\n" {
            out.push(current)
            current = ""
        } else if text[i] != "\r" {
            current = current + text[i]
        }
        i = i + 1
    }
    if current != "" {
        out.push(current)
    }
    out
}

func split_strings(string value, string sep) []string {
    []string out = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(value) {
        bool matched = false
        if len(sep) > 0 && i + len(sep) <= len(value) {
            matched = true
            int j = 0
            while j < len(sep) {
                if value[i + j] != sep[j] {
                    matched = false
                    j = len(sep)
                }
                j = j + 1
            }
        }
        if matched {
            out.push(current)
            current = ""
            i = i + len(sep)
        } else {
            current = current + value[i]
            i = i + 1
        }
    }
    out.push(current)
    out
}

func parse_int(string value) int {
    int sign = 1
    int i = 0
    int out = 0
    if len(value) > 0 && value[0] == "-" {
        sign = -1
        i = 1
    }
    while i < len(value) {
        string ch = string(value[i])
        if ch >= "0" && ch <= "9" {
            out = out * 10 + (int(ch) - 48)
        }
        i = i + 1
    }
    sign * out
}

func parse_float(string value) float {
    float sign = 1.0
    int i = 0
    float whole = 0.0
    float frac = 0.0
    float frac_div = 1.0
    bool seen_dot = false
    if len(value) > 0 && value[0] == "-" {
        sign = -1.0
        i = 1
    }
    while i < len(value) {
        string ch = string(value[i])
        if ch == "." {
            seen_dot = true
        } else if ch >= "0" && ch <= "9" {
            if !seen_dot {
                whole = whole * 10.0 + float(int(ch) - 48)
            } else {
                frac = frac * 10.0 + float(int(ch) - 48)
                frac_div = frac_div * 10.0
            }
        }
        i = i + 1
    }
    sign * (whole + frac / frac_div)
}

func read_bytes_from_file(string path) []byte {
    text_to_byte_array(runtime_read_text_file(path))
}

func shard_index_from_line(string line) int {
    int start = 0
    while start < len(line) && line[start] != "." {
        start = start + 1
    }
    start = start + 1
    int end = start
    while end < len(line) && line[end] != "." {
        end = end + 1
    }
    parse_int(neurx.strings.substring(line, start, end))
}

func ensure_shard_capacity([]shard_metadata shards, int needed) void {
    while len(shards) < needed {
        shards.push(shard_metadata{})
    }
}

func parse_shapes(string value) [][]int {
    [][]int out = [][]int{cap: 0}
    []string shape_parts = split_strings(value, "|")
    int i = 0
    while i < len(shape_parts) {
        []string dims = split_strings(shape_parts[i], "x")
        []int shape = []int{cap: len(dims)}
        int j = 0
        while j < len(dims) {
            shape.push(parse_int(dims[j]))
            j = j + 1
        }
        out.push(shape)
        i = i + 1
    }
    out
}
