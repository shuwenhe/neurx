// ============================================================================
// NeurX Data Sharding (S Language Implementation)
// 
// Replaces: generate_shards.sh
// 
// Functionality:
// - Split train.jsonl into multiple shards
// - Generate manifest.json with metadata
// - Validate and count shards
// ============================================================================

package neurx.script.data_shard

use neurx.script.data_utils.{
    file_read_text,
    file_write_text,
    file_delete,
    file_size,
    file_count_lines,
    path_join,
    path_dirname,
    path_basename,
    path_exists,
    ensure_dir,
    clear_dir,
    log_info,
    log_warn,
    log_error,
    log_success,
    get_env,
    get_env_int,
    string_repeat,
    max,
    min,
    div_round_up,
    dir_list_files,
}
use neurx.strings.{string_split, string_join}

// ============================================================================
// Configuration
// ============================================================================

struct shard_config {
    string input_file          // Path to input JSONL file
    string shard_dir           // Directory for output shards
    string manifest_file       // Output manifest.json path
    int max_shards             // Maximum number of shards (e.g., 128)
    int min_lines_per_shard    // Minimum lines per shard (e.g., 100)
}

struct shard_metadata {
    string shard_id
    string file_path
    i64 num_documents
    i64 size_bytes
}

struct shard_manifest {
    string dataset_name
    string version
    string created_at
    i64 total_shards
    i64 total_documents
    i64 total_size_bytes
    i64 average_docs_per_shard
    []shard_metadata shards
}

// ============================================================================
// Shard Generation
// ============================================================================

// Create default shard configuration from environment
fn new_shard_config_from_env() -> shard_config {
    let neurx_home = get_env("NEURX_HOME", ".")
    let dataset_root = get_env("DATASET_ROOT", path_join([]string{neurx_home, "dataset", "pretrain"}))
    
    shard_config{
        input_file: get_env("INPUT_FILE", path_join([]string{dataset_root, "cleaned", "train.jsonl"})),
        shard_dir: get_env("SHARD_DIR", path_join([]string{dataset_root, "shard"})),
        manifest_file: get_env("MANIFEST_FILE", path_join([]string{dataset_root, "manifest.json"})),
        max_shards: get_env_int("MAX_SHARDS", 128),
        min_lines_per_shard: get_env_int("MIN_LINES_PER_SHARD", 100),
    }
}

// Generate shards from input file
fn generate_shards(config: shard_config) -> bool {
    log_info("")
    log_info("╔════════════════════════════════════════════╗")
    log_info("║     NeurX Shard Generation (S Lang)        ║")
    log_info("╚════════════════════════════════════════════╝")
    log_info("")
    
    // Verify input file exists
    if !path_exists(config.input_file) {
        log_error("Input file not found: " + config.input_file)
        return false
    }
    
    // Count total lines
    let (total_lines, ok) = file_count_lines(config.input_file)
    if !ok {
        log_error("Failed to count lines in " + config.input_file)
        return false
    }
    
    log_info("📋 Input file analysis:")
    log_info("  • Path: " + config.input_file)
    log_info("  • Total lines: " + i64_to_string(total_lines))
    log_info("")
    
    // Handle empty file
    if total_lines == 0 {
        log_warn("No documents found in input file")
        return write_empty_manifest(config)
    }
    
    // Calculate optimal shard count
    let ideal_shards = div_round_up(total_lines, i64(config.min_lines_per_shard))
    let actual_shards = i64(min(i64(config.max_shards), ideal_shards))
    let lines_per_shard = div_round_up(total_lines, actual_shards)
    
    log_info("📊 Shard calculation:")
    log_info("  • Ideal shards: " + i64_to_string(ideal_shards))
    log_info("  • Actual shards: " + i64_to_string(actual_shards))
    log_info("  • Lines per shard: " + i64_to_string(lines_per_shard))
    log_info("")
    
    // Prepare shard directory
    if !ensure_dir(config.shard_dir) {
        log_error("Failed to create shard directory: " + config.shard_dir)
        return false
    }
    
    // Clear existing shards
    if !clear_dir(config.shard_dir) {
        log_warn("Failed to clear existing shards")
    }
    
    log_info("✂️ Generating shards...")
    
    // Read input file and split into shards
    let (content, ok) = file_read_text(config.input_file)
    if !ok {
        log_error("Failed to read input file")
        return false
    }
    
    let lines = string_split(content, "\n")
    let mut shard_index = 0
    let mut shard_data = ""
    let mut shard_line_count = 0
    let mut all_shards = []shard_metadata{}
    
    for i = 0; i < len(lines); i = i + 1 {
        let line = lines[i]
        
        // Skip empty lines at end
        if line == "" && i == len(lines) - 1 {
            continue
        }
        
        shard_data = shard_data + line + "\n"
        shard_line_count = shard_line_count + 1
        
        // Write shard when it reaches target size or at end
        if i64(shard_line_count) >= lines_per_shard || i == len(lines) - 1 {
            let shard_file = format_shard_filename(config.shard_dir, shard_index)
            if !file_write_text(shard_file, shard_data) {
                log_error("Failed to write shard: " + shard_file)
                return false
            }
            
            let size = file_size(shard_file)
            all_shards = append(all_shards, shard_metadata{
                shard_id: format_shard_id(shard_index),
                file_path: shard_file,
                num_documents: i64(shard_line_count),
                size_bytes: size,
            })
            
            shard_data = ""
            shard_line_count = 0
            shard_index = shard_index + 1
        }
    }
    
    log_success("Generated " + i64_to_string(i64(shard_index)) + " shards")
    log_info("")
    
    // Generate manifest
    log_info("📋 Writing manifest...")
    let manifest = build_manifest(config, all_shards)
    if !write_manifest(config.manifest_file, manifest) {
        log_error("Failed to write manifest")
        return false
    }
    
    log_success("Manifest written to " + config.manifest_file)
    log_info("")
    
    // Summary
    log_info("📊 Summary:")
    log_info("  • Total shards: " + i64_to_string(i64(len(all_shards))))
    log_info("  • Total documents: " + i64_to_string(manifest.total_documents))
    log_info("  • Average docs/shard: " + i64_to_string(manifest.average_docs_per_shard))
    log_info("")
    
    log_success("Shard generation completed successfully")
    true
}

// ============================================================================
// Helper Functions
// ============================================================================

fn format_shard_filename(shard_dir: string, index: int) -> string {
    path_join([]string{shard_dir, format_shard_id(index) + ".jsonl"})
}

fn format_shard_id(index: int) -> string {
    // Format as "shard_00000"
    let idx_str = i64_to_string(i64(index))
    let mut padded = ""
    for i = len(idx_str); i < 5; i = i + 1 {
        padded = padded + "0"
    }
    "shard_" + padded + idx_str
}

fn write_empty_manifest(config: shard_config) -> bool {
    let manifest = shard_manifest{
        dataset_name: "neurx-pretrain-dataset",
        version: "1.0",
        created_at: get_timestamp(),
        total_shards: 0,
        total_documents: 0,
        total_size_bytes: 0,
        average_docs_per_shard: 0,
        shards: []shard_metadata{},
    }
    write_manifest(config.manifest_file, manifest)
}

fn build_manifest(config: shard_config, shards: []shard_metadata) -> shard_manifest {
    let mut total_docs = i64(0)
    let mut total_size = i64(0)
    
    for _, shard in shards {
        total_docs = total_docs + shard.num_documents
        total_size = total_size + shard.size_bytes
    }
    
    let avg_docs = if len(shards) > 0 { total_docs / i64(len(shards)) } else { 0 }
    
    shard_manifest{
        dataset_name: "neurx-pretrain-dataset",
        version: "1.0",
        created_at: get_timestamp(),
        total_shards: i64(len(shards)),
        total_documents: total_docs,
        total_size_bytes: total_size,
        average_docs_per_shard: avg_docs,
        shards: shards,
    }
}

fn write_manifest(path: string, manifest: shard_manifest) -> bool {
    let mut json = "{\n"
    json = json + "  \"dataset_name\": \"" + manifest.dataset_name + "\",\n"
    json = json + "  \"version\": \"" + manifest.version + "\",\n"
    json = json + "  \"created_at\": \"" + manifest.created_at + "\",\n"
    json = json + "  \"total_shards\": " + i64_to_string(manifest.total_shards) + ",\n"
    json = json + "  \"total_documents\": " + i64_to_string(manifest.total_documents) + ",\n"
    json = json + "  \"total_size_bytes\": " + i64_to_string(manifest.total_size_bytes) + ",\n"
    json = json + "  \"average_docs_per_shard\": " + i64_to_string(manifest.average_docs_per_shard) + ",\n"
    json = json + "  \"shards\": [\n"
    
    for i = 0; i < len(manifest.shards); i = i + 1 {
        let shard = manifest.shards[i]
        json = json + "    {\n"
        json = json + "      \"shard_id\": \"" + shard.shard_id + "\",\n"
        json = json + "      \"file_path\": \"" + shard.file_path + "\",\n"
        json = json + "      \"num_documents\": " + i64_to_string(shard.num_documents) + ",\n"
        json = json + "      \"size_bytes\": " + i64_to_string(shard.size_bytes) + "\n"
        json = json + "    }"
        
        if i < len(manifest.shards) - 1 {
            json = json + ","
        }
        json = json + "\n"
    }
    
    json = json + "  ]\n"
    json = json + "}\n"
    
    file_write_text(path, json)
}

// ============================================================================
// Timestamp and String Conversion
// ============================================================================

fn get_timestamp() -> string {
    // Placeholder - would use proper datetime library
    // Format: 2026-07-07T12:34:56Z
    "2026-07-07T00:00:00Z"
}

fn i64_to_string(n: i64) -> string {
    // Placeholder for integer to string conversion
    // Would need proper implementation in S
    ""
}

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() -> i32 {
    let config = new_shard_config_from_env()
    
    if generate_shards(config) {
        0  // success
    } else {
        1  // error
    }
}
