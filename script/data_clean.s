// ============================================================================
// NeurX Data Cleaning (S Language Implementation)
// 
// Replaces: clean_data.sh (Python portion)
// 
// Functionality:
// - Process raw data (JSONL, TXT, XML, XML.BZ2)
// - Normalize and deduplicate text
// - Split into train/val/test sets
// - Generate manifest with metadata
// ============================================================================

package neurx.script.data_clean

use neurx.script.data_utils.{
    file_read_text,
    file_write_text,
    file_append_text,
    file_delete,
    file_count_lines,
    path_join,
    path_dirname,
    path_basename,
    path_exists,
    ensure_dir,
    log_info,
    log_warn,
    log_error,
    log_success,
    get_env,
    dir_list_files,
    normalize_whitespace,
    hash_key,
}
use neurx.strings.{string_split, string_join, string_contains, string_trim}

// ============================================================================
// Configuration
// ============================================================================

struct clean_config {
    string raw_dir              // Directory with raw data
    string cleaned_dir          // Output cleaned directory
    string output_file          // Combined cleaned JSONL file
    string manifest_file        // Output manifest
    string checkpoint_file      // Checkpoint for resume
    int checkpoint_interval     // Save checkpoint every N items
}

struct clean_stats {
    i64 total_processed
    i64 total_written
    i64 duplicates_skipped
    i64 empty_records_skipped
    i64 errors
}

struct dataset_splits {
    string train_file
    string val_file
    string test_file
}

// ============================================================================
// Configuration
// ============================================================================

fn new_clean_config_from_env() -> clean_config {
    let neurx_home = get_env("NEURX_HOME", ".")
    
    clean_config{
        raw_dir: get_env("RAW_DIR", path_join([]string{neurx_home, "dataset", "pretrain", "raw"})),
        cleaned_dir: get_env("CLEANED_DIR", path_join([]string{neurx_home, "dataset", "pretrain", "cleaned"})),
        output_file: get_env("OUTPUT_FILE", path_join([]string{neurx_home, "dataset", "pretrain", "cleaned", "pretrain_data_cleaned.jsonl"})),
        manifest_file: get_env("MANIFEST_FILE", path_join([]string{neurx_home, "dataset", "pretrain", "manifest.json"})),
        checkpoint_file: get_env("CHECKPOINT_FILE", path_join([]string{neurx_home, "dataset", "pretrain", "cleaned", ".cleaning_checkpoint.json"})),
        checkpoint_interval: 200,
    }
}

// ============================================================================
// Main Cleaning Pipeline
// ============================================================================

pub fn clean_data(config: clean_config) -> bool {
    log_info("")
    log_info("╔════════════════════════════════════════════╗")
    log_info("║     NeurX Data Cleaning (S Lang)           ║")
    log_info("╚════════════════════════════════════════════╝")
    log_info("")
    
    // Prepare directories
    if !ensure_dir(config.cleaned_dir) {
        log_error("Failed to create cleaned directory")
        return false
    }
    
    log_info("📂 Configuration:")
    log_info("  • Raw data: " + config.raw_dir)
    log_info("  • Output: " + config.output_file)
    log_info("  • Manifest: " + config.manifest_file)
    log_info("")
    
    // Find source files
    let sources = find_source_files(config.raw_dir)
    if len(sources) == 0 {
        log_warn("No raw data files found in " + config.raw_dir)
        return write_empty_manifest(config)
    }
    
    log_info("📚 Found " + i64_to_string(i64(len(sources))) + " source files")
    log_info("")
    
    // Process files
    let mut stats = clean_stats{
        total_processed: 0,
        total_written: 0,
        duplicates_skipped: 0,
        empty_records_skipped: 0,
        errors: 0,
    }
    
    let mut seen_hashes = map[string]bool{}
    
    log_info("🔄 Processing files...")
    for _, source_file in sources {
        log_info("  Processing: " + path_basename(source_file))
        
        if !process_source_file(config, source_file, &stats, seen_hashes) {
            log_warn("Error processing file, continuing...")
        }
    }
    
    log_info("")
    log_success("Processing completed")
    log_info("📊 Statistics:")
    log_info("  • Total processed: " + i64_to_string(stats.total_processed))
    log_info("  • Successfully written: " + i64_to_string(stats.total_written))
    log_info("  • Duplicates skipped: " + i64_to_string(stats.duplicates_skipped))
    log_info("  • Empty records: " + i64_to_string(stats.empty_records_skipped))
    log_info("  • Errors: " + i64_to_string(stats.errors))
    log_info("")
    
    // Finalize: split into train/val/test
    if !finalize_dataset(config, &stats) {
        log_error("Failed to finalize dataset splits")
        return false
    }
    
    log_success("Data cleaning pipeline completed")
    true
}

// ============================================================================
// File Discovery
// ============================================================================

fn find_source_files(raw_dir: string) -> []string {
    let supported = []string{".jsonl", ".txt", ".xml", ".xml.bz2"}
    dir_list_files(raw_dir, supported)
}

// ============================================================================
// Source File Processing
// ============================================================================

fn process_source_file(config: clean_config, source_file: string, stats: &clean_stats, seen_hashes: map[string]bool) -> bool {
    let (content, ok) = file_read_text(source_file)
    if !ok {
        log_error("Failed to read: " + source_file)
        stats.errors = stats.errors + 1
        return false
    }
    
    let fname = path_basename(source_file)
    
    // Determine file type and process accordingly
    if string_contains(fname, ".jsonl") {
        process_jsonl(config, content, stats, seen_hashes)
    } else if string_contains(fname, ".txt") {
        process_text(config, content, stats, seen_hashes)
    } else if string_contains(fname, ".xml") {
        process_xml(config, content, stats, seen_hashes)
    } else {
        log_warn("Unknown file type: " + fname)
        false
    }
}

fn process_jsonl(config: clean_config, content: string, stats: &clean_stats, seen_hashes: map[string]bool) -> bool {
    let lines = string_split(content, "\n")
    
    for _, line in lines {
        let trimmed = string_trim(line)
        if trimmed == "" {
            continue
        }
        
        stats.total_processed = stats.total_processed + 1
        
        // Extract text field (simplified JSON parsing)
        let text = extract_text_from_jsonl(trimmed)
        if text == "" {
            stats.empty_records_skipped = stats.empty_records_skipped + 1
            continue
        }
        
        // Check for duplicates
        let hkey = hash_key(normalize_whitespace(text))
        if seen_hashes[hkey] {
            stats.duplicates_skipped = stats.duplicates_skipped + 1
            continue
        }
        seen_hashes[hkey] = true
        
        // Write cleaned record
        let record = create_cleaned_record(text, "jsonl")
        if file_append_text(config.output_file, record + "\n") {
            stats.total_written = stats.total_written + 1
        } else {
            stats.errors = stats.errors + 1
        }
    }
    
    true
}

fn process_text(config: clean_config, content: string, stats: &clean_stats, seen_hashes: map[string]bool) -> bool {
    // For TXT files, treat each paragraph (separated by double newlines) as a record
    let paragraphs = string_split(content, "\n\n")
    
    for _, para in paragraphs {
        let text = string_trim(para)
        if text == "" {
            continue
        }
        
        stats.total_processed = stats.total_processed + 1
        
        // Check for duplicates
        let hkey = hash_key(normalize_whitespace(text))
        if seen_hashes[hkey] {
            stats.duplicates_skipped = stats.duplicates_skipped + 1
            continue
        }
        seen_hashes[hkey] = true
        
        // Write cleaned record
        let record = create_cleaned_record(text, "txt")
        if file_append_text(config.output_file, record + "\n") {
            stats.total_written = stats.total_written + 1
        } else {
            stats.errors = stats.errors + 1
        }
    }
    
    true
}

fn process_xml(config: clean_config, content: string, stats: &clean_stats, seen_hashes: map[string]bool) -> bool {
    // Simplified XML processing: extract text between tags
    // In real implementation, would use proper XML parser
    
    let mut text_blocks = []string{}
    let lines = string_split(content, "\n")
    let mut in_tag = false
    let mut current_text = ""
    
    for _, line in lines {
        let trimmed = string_trim(line)
        
        // Detect XML tags
        if string_contains(trimmed, "<") && string_contains(trimmed, ">") {
            if current_text != "" {
                text_blocks = append(text_blocks, current_text)
                current_text = ""
            }
        } else if trimmed != "" {
            current_text = current_text + " " + trimmed
        }
    }
    
    if current_text != "" {
        text_blocks = append(text_blocks, current_text)
    }
    
    // Process extracted text blocks
    for _, text in text_blocks {
        let cleaned = string_trim(text)
        if cleaned == "" {
            continue
        }
        
        stats.total_processed = stats.total_processed + 1
        
        let hkey = hash_key(normalize_whitespace(cleaned))
        if seen_hashes[hkey] {
            stats.duplicates_skipped = stats.duplicates_skipped + 1
            continue
        }
        seen_hashes[hkey] = true
        
        let record = create_cleaned_record(cleaned, "xml")
        if file_append_text(config.output_file, record + "\n") {
            stats.total_written = stats.total_written + 1
        } else {
            stats.errors = stats.errors + 1
        }
    }
    
    true
}

// ============================================================================
// JSON Record Creation
// ============================================================================

fn create_cleaned_record(text: string, source: string) -> string {
    // Create JSONL record: {"text": "...", "source": "...", "tokens": ...}
    let encoded_text = escape_json_string(text)
    let token_count = estimate_tokens(text)
    
    "{\"text\": " + "\"" + encoded_text + "\", \"source\": \"" + source + "\", \"tokens\": " + i64_to_string(token_count) + "}"
}

fn extract_text_from_jsonl(jsonl_line: string) -> string {
    // Simplified: extract "text" field from JSONL
    // In real impl, would use proper JSON parser
    
    if !string_contains(jsonl_line, "\"text\"") {
        return ""
    }
    
    // Find the value after "text":
    let start_idx = find_substring(jsonl_line, "\"text\"")
    if start_idx < 0 {
        return ""
    }
    
    // Skip to opening quote
    let mut i = start_idx + 6  // len("\"text\"")
    while i < len(jsonl_line) && jsonl_line[i] != '"' {
        i = i + 1
    }
    
    if i >= len(jsonl_line) {
        return ""
    }
    
    i = i + 1  // skip opening quote
    let text_start = i
    
    // Find closing quote (handling escapes)
    while i < len(jsonl_line) {
        if jsonl_line[i] == '"' && (i == 0 || jsonl_line[i - 1] != '\\') {
            break
        }
        i = i + 1
    }
    
    if i > text_start {
        jsonl_line[text_start : i]
    } else {
        ""
    }
}

fn escape_json_string(s: string) -> string {
    let mut result = ""
    
    for i = 0; i < len(s); i = i + 1 {
        let ch = s[i]
        match ch {
            case '"':
                result = result + "\\\""
            case '\\':
                result = result + "\\\\"
            case '\n':
                result = result + "\\n"
            case '\r':
                result = result + "\\r"
            case '\t':
                result = result + "\\t"
            case _:
                result = result + string(ch)
        }
    }
    
    result
}

fn estimate_tokens(text: string) -> i64 {
    // Rough estimate: tokens ≈ characters / 4
    i64(max(1, len(text) / 4))
}

// ============================================================================
// Dataset Finalization
// ============================================================================

fn finalize_dataset(config: clean_config, stats: &clean_stats) -> bool {
    log_info("")
    log_info("📋 Finalizing dataset splits (train/val/test)...")
    
    let (total_lines, ok) = file_count_lines(config.output_file)
    if !ok || total_lines == 0 {
        log_warn("No cleaned data found")
        return write_empty_manifest(config)
    }
    
    // Calculate split sizes: 80% train, 10% val, 10% test
    let train_size = total_lines * 8 / 10
    let val_size = total_lines / 10
    let test_size = total_lines - train_size - val_size
    
    log_info("  • Total documents: " + i64_to_string(total_lines))
    log_info("  • Train split: " + i64_to_string(train_size) + " (" + i64_to_string(train_size * 100 / total_lines) + "%)")
    log_info("  • Val split: " + i64_to_string(val_size) + " (" + i64_to_string(val_size * 100 / total_lines) + "%)")
    log_info("  • Test split: " + i64_to_string(test_size) + " (" + i64_to_string(test_size * 100 / total_lines) + "%)")
    
    let splits = dataset_splits{
        train_file: path_join([]string{config.cleaned_dir, "train.jsonl"}),
        val_file: path_join([]string{config.cleaned_dir, "val.jsonl"}),
        test_file: path_join([]string{config.cleaned_dir, "test.jsonl"}),
    }
    
    // Split file
    if !split_dataset(config.output_file, splits, train_size, val_size) {
        log_error("Failed to split dataset")
        return false
    }
    
    log_success("Dataset splits created successfully")
    
    // Generate manifest
    if !write_cleaned_manifest(config, splits, total_lines, stats) {
        log_error("Failed to write manifest")
        return false
    }
    
    true
}

fn split_dataset(input_file: string, splits: dataset_splits, train_size: i64, val_size: i64) -> bool {
    let (content, ok) = file_read_text(input_file)
    if !ok {
        return false
    }
    
    let lines = string_split(content, "\n")
    let mut train_data = ""
    let mut val_data = ""
    let mut test_data = ""
    
    for i = 0; i < len(lines); i = i + 1 {
        let line = lines[i]
        if line == "" {
            continue
        }
        
        let line_idx = i64(i)
        if line_idx < train_size {
            train_data = train_data + line + "\n"
        } else if line_idx < train_size + val_size {
            val_data = val_data + line + "\n"
        } else {
            test_data = test_data + line + "\n"
        }
    }
    
    file_write_text(splits.train_file, train_data) &&
    file_write_text(splits.val_file, val_data) &&
    file_write_text(splits.test_file, test_data)
}

fn write_cleaned_manifest(config: clean_config, splits: dataset_splits, total: i64, stats: &clean_stats) -> bool {
    let manifest = "{
  \"dataset_name\": \"neurx-pretrain-dataset\",
  \"version\": \"1.0\",
  \"status\": \"cleaned\",
  \"total_documents\": " + i64_to_string(total) + ",
  \"total_processed\": " + i64_to_string(stats.total_processed) + ",
  \"duplicates_removed\": " + i64_to_string(stats.duplicates_skipped) + ",
  \"cleaned_file\": \"cleaned/pretrain_data_cleaned.jsonl\",
  \"cleaned_splits\": {
    \"train\": \"cleaned/train.jsonl\",
    \"val\": \"cleaned/val.jsonl\",
    \"test\": \"cleaned/test.jsonl\"
  }
}
"
    file_write_text(config.manifest_file, manifest)
}

fn write_empty_manifest(config: clean_config) -> bool {
    let manifest = "{
  \"dataset_name\": \"neurx-pretrain-dataset\",
  \"version\": \"1.0\",
  \"status\": \"empty\",
  \"total_documents\": 0,
  \"cleaned_splits\": {
    \"train\": null,
    \"val\": null,
    \"test\": null
  }
}
"
    file_write_text(config.manifest_file, manifest)
}

// ============================================================================
// Utility Functions
// ============================================================================

fn find_substring(s: string, substr: string) -> i32 {
    for i = 0; i <= len(s) - len(substr); i = i + 1 {
        let mut match_ok = true
        for j = 0; j < len(substr); j = j + 1 {
            if s[i + j] != substr[j] {
                match_ok = false
                break
            }
        }
        if match_ok {
            return i32(i)
        }
    }
    -1
}

fn max(a: i64, b: i64) -> i64 {
    if a > b { a } else { b }
}

fn i64_to_string(n: i64) -> string {
    // Placeholder - needs proper implementation
    ""
}

fn string(ch: u8) -> string {
    // Convert byte to string - placeholder
    ""
}

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() -> i32 {
    let config = new_clean_config_from_env()
    
    if clean_data(config) {
        0  // success
    } else {
        1  // error
    }
}
