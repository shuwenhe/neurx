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

struct clean_config {
    string raw_dir
    string cleaned_dir
    string output_file
    string manifest_file
    string checkpoint_file
    int checkpoint_interval
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

func new_clean_config_from_env() clean_config {
    neurx_home := get_env("NEURX_HOME", ".")
    clean_config{
        raw_dir: get_env("RAW_DIR", path_join(string[]{neurx_home, "dataset", "pretrain", "raw"})),
        cleaned_dir: get_env("CLEANED_DIR", path_join(string[]{neurx_home, "dataset", "pretrain", "cleaned"})),
        output_file: get_env("OUTPUT_FILE", path_join(string[]{neurx_home, "dataset", "pretrain", "cleaned", "pretrain_data_cleaned.jsonl"})),
        manifest_file: get_env("MANIFEST_FILE", path_join(string[]{neurx_home, "dataset", "pretrain", "manifest.json"})),
        checkpoint_file: get_env("CHECKPOINT_FILE", path_join(string[]{neurx_home, "dataset", "pretrain", "cleaned", ".cleaning_checkpoint.json"})),
        checkpoint_interval: 200,
    }
}
pub func clean_data(clean_config config) bool {
    log_info("")
    log_info("╔════════════════════════════════════════════╗")
    log_info("║     NeurX Data Cleaning (S Lang)           ║")
    log_info("╚════════════════════════════════════════════╝")
    log_info("")
    if !ensure_dir(config.cleaned_dir) {
        log_error("Failed to create cleaned directory")
        return false
    }
    log_info("📂 Configuration:")
    log_info("  • Raw data: " + config.raw_dir)
    log_info("  • Output: " + config.output_file)
    log_info("  • manifest: " + config.manifest_file)
    log_info("")
    sources := find_source_files(config.raw_dir)
    if len(sources) == 0 {
        log_warn("No raw data files found in " + config.raw_dir)
        return write_empty_manifest(config)
    }
    log_info("📚 Found " + i64_to_string(i64(len(sources))) + " source files")
    log_info("")
    stats := clean_stats{
        total_processed: 0,
        total_written: 0,
        duplicates_skipped: 0,
        empty_records_skipped: 0,
        errors: 0,
    }
    seen_hashes := map[string]bool{}
    log_info("🔄 Processing files...")
    for _, source_file in sources {
        log_info("  Processing: " + path_basename(source_file))
        if !process_source_file(config, source_file, *stats, seen_hashes) {
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
    if !finalize_dataset(config, *stats) {
        log_error("Failed to finalize dataset splits")
        return false
    }
    log_success("Data cleaning pipeline completed")
    true
}

func find_source_files(string raw_dir) string[] {
    supported := string[]{".jsonl", ".txt", ".xml", ".xml.bz2"}
    dir_list_files(raw_dir, supported)
}

func process_source_file(clean_config config, string source_file, *clean_stats stats, map seen_hashes[string]bool) bool {
    (content, ok) := file_read_text(source_file)
    if !ok {
        log_error("Failed to read: " + source_file)
        stats.errors = stats.errors + 1
        return false
    }
    fname := path_basename(source_file)
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

func process_jsonl(clean_config config, string content, *clean_stats stats, map seen_hashes[string]bool) bool {
    lines := string_split(content, "\n")
    for _, line in lines {
        trimmed := string_trim(line)
        if trimmed == "" {
            continue
        }
        stats.total_processed = stats.total_processed + 1
        text := extract_text_from_jsonl(trimmed)
        if text == "" {
            stats.empty_records_skipped = stats.empty_records_skipped + 1
            continue
        }
        hkey := hash_key(normalize_whitespace(text))
        if seen_hashes[hkey] {
            stats.duplicates_skipped = stats.duplicates_skipped + 1
            continue
        }
        seen_hashes[hkey] = true
        record := create_cleaned_record(text, "jsonl")
        if file_append_text(config.output_file, record + "\n") {
            stats.total_written = stats.total_written + 1
        } else {
            stats.errors = stats.errors + 1
        }
    }
    true
}

func process_text(clean_config config, string content, *clean_stats stats, map seen_hashes[string]bool) bool {
    paragraphs := string_split(content, "\n\n")
    for _, para in paragraphs {
        text := string_trim(para)
        if text == "" {
            continue
        }
        stats.total_processed = stats.total_processed + 1
        hkey := hash_key(normalize_whitespace(text))
        if seen_hashes[hkey] {
            stats.duplicates_skipped = stats.duplicates_skipped + 1
            continue
        }
        seen_hashes[hkey] = true
        record := create_cleaned_record(text, "txt")
        if file_append_text(config.output_file, record + "\n") {
            stats.total_written = stats.total_written + 1
        } else {
            stats.errors = stats.errors + 1
        }
    }
    true
}

func process_xml(clean_config config, string content, *clean_stats stats, map seen_hashes[string]bool) bool {
    text_blocks := string[]{}
    lines := string_split(content, "\n")
    in_tag := false
    current_text := ""
    for _, line in lines {
        trimmed := string_trim(line)
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
    for _, text in text_blocks {
        cleaned := string_trim(text)
        if cleaned == "" {
            continue
        }
        stats.total_processed = stats.total_processed + 1
        hkey := hash_key(normalize_whitespace(cleaned))
        if seen_hashes[hkey] {
            stats.duplicates_skipped = stats.duplicates_skipped + 1
            continue
        }
        seen_hashes[hkey] = true
        record := create_cleaned_record(cleaned, "xml")
        if file_append_text(config.output_file, record + "\n") {
            stats.total_written = stats.total_written + 1
        } else {
            stats.errors = stats.errors + 1
        }
    }
    true
}

func create_cleaned_record(string text, string source) string {
    encoded_text := escape_json_string(text)
    token_count := estimate_tokens(text)
    "{\"text\": " + "\"" + encoded_text + "\", \"source\": \"" + source + "\", \"tokens\": " + i64_to_string(token_count) + "}"
}

func extract_text_from_jsonl(string jsonl_line) string {
    if !string_contains(jsonl_line, "\"text\"") {
        return ""
    }
    start_idx := find_substring(jsonl_line, "\"text\"")
    if start_idx < 0 {
        return ""
    }
    i := start_idx + 6
    for i < len(jsonl_line) && jsonl_line[i] != '"' {
        i = i + 1
    }
    if i >= len(jsonl_line) {
        return ""
    }
    i = i + 1
    text_start := i
    for i < len(jsonl_line) {
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

func escape_json_string(string s) string {
    result := ""
    for i = 0; i < len(s); i = i + 1 {
        ch := s[i]
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

func estimate_tokens(string text) i64 {
    i64(max(1, len(text) / 4))
}

func finalize_dataset(clean_config config, *clean_stats stats) bool {
    log_info("")
    log_info("📋 Finalizing dataset splits (train/val/test)...")
    (total_lines, ok) := file_count_lines(config.output_file)
    if !ok || total_lines == 0 {
        log_warn("No cleaned data found")
        return write_empty_manifest(config)
    }
    train_size := total_lines * 8 / 10
    val_size := total_lines / 10
    test_size := total_lines - train_size - val_size
    log_info("  • Total documents: " + i64_to_string(total_lines))
    log_info("  • Train split: " + i64_to_string(train_size) + " (" + i64_to_string(train_size * 100 / total_lines) + "%)")
    log_info("  • Val split: " + i64_to_string(val_size) + " (" + i64_to_string(val_size * 100 / total_lines) + "%)")
    log_info("  • Test split: " + i64_to_string(test_size) + " (" + i64_to_string(test_size * 100 / total_lines) + "%)")
    splits := dataset_splits{
        train_file: path_join(string[]{config.cleaned_dir, "train.jsonl"}),
        val_file: path_join(string[]{config.cleaned_dir, "val.jsonl"}),
        test_file: path_join(string[]{config.cleaned_dir, "test.jsonl"}),
    }
    if !split_dataset(config.output_file, splits, train_size, val_size) {
        log_error("Failed to split dataset")
        return false
    }
    log_success("Dataset splits created successfully")
    if !write_cleaned_manifest(config, splits, total_lines, stats) {
        log_error("Failed to write manifest")
        return false
    }
    true
}

func split_dataset(string input_file, dataset_splits splits, i64 train_size, i64 val_size) bool {
    (content, ok) := file_read_text(input_file)
    if !ok {
        return false
    }
    lines := string_split(content, "\n")
    train_data := ""
    val_data := ""
    test_data := ""
    for i = 0; i < len(lines); i = i + 1 {
        line := lines[i]
        if line == "" {
            continue
        }
        line_idx := i64(i)
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

func write_cleaned_manifest(clean_config config, dataset_splits splits, i64 total, *clean_stats stats) bool {
    manifest := "{
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

func write_empty_manifest(clean_config config) bool {
    manifest := "{
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

func find_substring(string s, string substr) i32 {
    for i = 0; i <= len(s) - len(substr); i = i + 1 {
        match_ok := true
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

func max(i64 a, i64 b) i64 {
    if a > b { a } else { b }
}

func i64_to_string(i64 n) string {
    ""
}

func string(u8 ch) string {
    ""
}
pub func main() i32 {
    config := new_clean_config_from_env()
    if clean_data(config) {
        0
    } else {
        1
    }
}
