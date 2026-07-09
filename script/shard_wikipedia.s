// ============================================================================
// NeurX Wikipedia (enwiki) Shard Processing — S Language Implementation
//
// Replaces: shard_wikipedia_enwiki.py
//
// This script streams the compressed Wikipedia dump, extracts page text, and
// writes shard_00000.jsonl-style files plus a manifest under the pretrain
// shard directory.
//
// Features:
// - Decompresses .bz2 files using bzip2
// - Parses XML and extracts article text
// - Strips HTML/XML markup and entities
// - Splits into manageable shards
// - Generates manifest.json with metadata
// ============================================================================

package neurx.script.shard_wikipedia

use std.io.{println, eprint, printf}
use std.os.{command, getenv, getenv_int}
use std.path.{join, dirname}
use std.strings.{split, has_prefix, has_suffix, contains, trim, replace}
use std.json.{encode, object, array, string as json_string, number, null}

// ============================================================================
// Configuration
// ============================================================================

struct WikipediaConfig {
    string input_bz2_file      // Path to enwiki-latest-pages-articles.xml.bz2
    string output_dir          // Directory for output shards
    string manifest_file       // Output manifest.json path
    int docs_per_shard         // Documents per shard file
    int max_pages              // Optional test limit (0 = unlimited)
}

struct ShardMetadata {
    string shard_id
    string file_path
    i64 num_documents
    i64 size_bytes
}

// ============================================================================
// Helper Functions
// ============================================================================

fn log_info(msg: string) {
    eprint("[ℹ️ ] " + msg + "\n")
}

fn log_success(msg: string) {
    eprint("[✓ ] " + msg + "\n")
}

fn log_error(msg: string) {
    eprint("[✗ ] " + msg + "\n")
}

fn log_progress(msg: string) {
    eprint("[⏳] " + msg + "\n")
}

fn strip_xml_tags(text: string) -> string {
    // Remove <tag>...</tag> patterns
    let mut result = ""
    let mut in_tag = false
    
    for i = 0; i < len(text); i = i + 1 {
        let ch = text[i:i+1]
        if ch == "<" {
            in_tag = true
        } else if ch == ">" {
            in_tag = false
            result = result + " "
        } else if !in_tag {
            result = result + ch
        }
    }
    
    return result
}

fn html_unescape(text: string) -> string {
    let mut result = text
    
    // Replace common HTML entities
    result = replace(result, "&nbsp;", " ")
    result = replace(result, "&lt;", "<")
    result = replace(result, "&gt;", ">")
    result = replace(result, "&amp;", "&")
    result = replace(result, "&quot;", "\"")
    result = replace(result, "&apos;", "'")
    
    return result
}

fn normalize_whitespace(text: string) -> string {
    // Remove leading/trailing whitespace and collapse multiple spaces
    let trimmed = trim(text)
    
    let mut result = ""
    let mut prev_space = false
    
    for i = 0; i < len(trimmed); i = i + 1 {
        let ch = trimmed[i:i+1]
        let is_space = (ch == " " || ch == "\t" || ch == "\n" || ch == "\r")
        
        if is_space {
            if !prev_space {
                result = result + " "
                prev_space = true
            }
        } else {
            result = result + ch
            prev_space = false
        }
    }
    
    return result
}

fn shard_name(index: i64) -> string {
    // Format: shard_00000.jsonl
    let mut s = i64_to_string(index)
    while len(s) < 5 {
        s = "0" + s
    }
    return "shard_" + s + ".jsonl"
}

fn json_escape_string(s: string) -> string {
    let mut result = "\""
    
    for i = 0; i < len(s); i = i + 1 {
        let ch = s[i:i+1]
        
        if ch == "\"" {
            result = result + "\\\""
        } else if ch == "\\" {
            result = result + "\\\\"
        } else if ch == "\n" {
            result = result + "\\n"
        } else if ch == "\r" {
            result = result + "\\r"
        } else if ch == "\t" {
            result = result + "\\t"
        } else {
            result = result + ch
        }
    }
    
    result = result + "\""
    return result
}

fn json_object_entry(key: string, value: string) -> string {
    return json_escape_string(key) + ": " + value
}

fn create_json_record(title: string, page_id: string, text: string) -> string {
    let title_escaped = json_escape_string(title)
    let page_id_escaped = json_escape_string(page_id)
    let text_escaped = json_escape_string(text)
    
    return "{" +
        json_object_entry("title", title_escaped) + ", " +
        json_object_entry("page_id", page_id_escaped) + ", " +
        json_object_entry("text", text_escaped) + ", " +
        json_object_entry("source", json_escape_string("enwiki-latest-pages-articles.xml.bz2")) +
        "}"
}

// ============================================================================
// XML Parsing
// ============================================================================

struct PageRecord {
    string title
    string page_id
    string text
}

fn extract_xml_tag_value(xml: string, tag_name: string) -> string {
    let open_tag = "<" + tag_name + ">"
    let close_tag = "</" + tag_name + ">"
    
    let start_idx = contains_index(xml, open_tag)
    if start_idx < 0 {
        return ""
    }
    
    let end_idx = contains_index(xml, close_tag)
    if end_idx < 0 {
        return ""
    }
    
    let value_start = start_idx + len(open_tag)
    let value = xml[value_start:end_idx]
    
    return value
}

fn contains_index(haystack: string, needle: string) -> i64 {
    if len(needle) == 0 {
        return 0
    }
    
    for i = 0; i <= len(haystack) - len(needle); i = i + 1 {
        if haystack[i:i+len(needle)] == needle {
            return i64(i)
        }
    }
    
    return -1
}

fn extract_page_record(page_xml: string) -> PageRecord | null {
    // Check if page is in namespace 0 (main article namespace)
    let ns_str = extract_xml_tag_value(page_xml, "ns")
    if ns_str != "0" {
        return null
    }
    
    // Skip redirects
    if contains_index(page_xml, "<redirect") >= 0 {
        return null
    }
    
    // Extract fields
    let title = extract_xml_tag_value(page_xml, "title")
    let page_id = extract_xml_tag_value(page_xml, "id")
    let text = extract_xml_tag_value(page_xml, "text")
    
    if len(title) == 0 || len(text) == 0 {
        return null
    }
    
    // Clean up text
    let title_clean = normalize_whitespace(html_unescape(title))
    let text_clean = normalize_whitespace(html_unescape(strip_xml_tags(text)))
    
    if len(text_clean) == 0 {
        return null
    }
    
    return PageRecord{
        title: title_clean,
        page_id: page_id,
        text: text_clean,
    }
}

// ============================================================================
// File Operations
// ============================================================================

fn file_exists(path: string) -> bool {
    let (_, code) = command("test -f \"" + path + "\"")
    return code == 0
}

fn dir_exists(path: string) -> bool {
    let (_, code) = command("test -d \"" + path + "\"")
    return code == 0
}

fn get_file_size(path: string) -> i64 {
    if !file_exists(path) {
        return 0
    }
    
    let (output, code) = command("stat -c '%s' \"" + path + "\" 2>/dev/null || stat -f '%z' \"" + path + "\"")
    if code != 0 {
        return 0
    }
    
    // Parse the size from output
    let lines = split(output, "\n")
    if len(lines) > 0 {
        let size_str = trim(lines[0])
        // Simple string to i64 conversion
        let mut size: i64 = 0
        for i = 0; i < len(size_str); i = i + 1 {
            let ch = size_str[i:i+1]
            if ch >= "0" && ch <= "9" {
                size = size * 10 + i64(ch[0] - "0"[0])
            }
        }
        return size
    }
    
    return 0
}

// ============================================================================
// Main Shard Processing
// ============================================================================

fn process_wikipedia(config: WikipediaConfig) -> i32 {
    println("")
    println("╔════════════════════════════════════════════════════════════╗")
    println("║    NeurX Wikipedia Shard Processing (S Language)           ║")
    println("╚════════════════════════════════════════════════════════════╝")
    println("")
    
    // Log configuration
    log_info("Configuration:")
    printf("  Input      : %s\n", []interface{}{config.input_bz2_file})
    printf("  Output dir : %s\n", []interface{}{config.output_dir})
    printf("  Manifest   : %s\n", []interface{}{config.manifest_file})
    printf("  Docs/shard : %d\n", []interface{}{config.docs_per_shard})
    println("")
    
    // Step 1: Verify input file
    log_progress("Checking input file...")
    if !file_exists(config.input_bz2_file) {
        log_error("Input file not found: " + config.input_bz2_file)
        return 1
    }
    log_success("Input file exists")
    println("")
    
    // Step 2: Create output directories
    log_progress("Creating output directories...")
    let (_, code) = command("mkdir -p \"" + config.output_dir + "\" \"" + dirname(config.manifest_file) + "\"")
    if code != 0 {
        log_error("Failed to create directories")
        return 1
    }
    log_success("Directories created")
    println("")
    
    // Step 3: Clean old shard files
    log_progress("Cleaning old shard files...")
    command("rm -f \"" + config.output_dir + "/shard_\"*.jsonl")
    log_success("Cleanup complete")
    println("")
    
    // Step 4: Process Wikipedia dump using bzcat piped to Python helper
    // For now, we'll use a hybrid approach with bzcat and awk for parsing
    log_progress("Processing Wikipedia dump...")
    
    let mut shard_index: i64 = 0
    let mut docs_in_shard: i64 = 0
    let mut total_pages: i64 = 0
    let mut total_docs: i64 = 0
    let mut shard_file: string = ""
    let mut shards: []ShardMetadata = []
    
    // Use bzcat to decompress and process
    let bzcat_cmd = "bzcat \"" + config.input_bz2_file + "\" 2>/dev/null || bzip2 -dc \"" + config.input_bz2_file + "\""
    
    // We need to invoke the bzcat command and process line by line
    // This is a simplified version - in production, consider a more robust implementation
    
    let (output, code) = command(bzcat_cmd)
    if code != 0 {
        log_error("Failed to decompress input file")
        return 1
    }
    
    let lines = split(output, "\n")
    let mut page_lines: []string = []
    let mut in_page = false
    
    for i = 0; i < len(lines); i = i + 1 {
        let line = lines[i]
        
        if contains_index(line, "<page>") >= 0 {
            in_page = true
            page_lines = []string{line}
            continue
        }
        
        if in_page {
            page_lines = append(page_lines, line)
            
            if contains_index(line, "</page>") >= 0 {
                in_page = false
                total_pages = total_pages + 1
                
                let page_xml = join(page_lines, "\n")
                let record = extract_page_record(page_xml)
                
                if record != null {
                    // Create output filename
                    if len(shard_file) == 0 {
                        shard_file = join([]string{config.output_dir, shard_name(shard_index)}, "/")
                    }
                    
                    // Write record to shard file
                    let json_record = create_json_record(record.title, record.page_id, record.text)
                    let (_, code) = command("echo '" + json_record + "' >> \"" + shard_file + "\"")
                    if code == 0 {
                        docs_in_shard = docs_in_shard + 1
                        total_docs = total_docs + 1
                    }
                    
                    // Rotate shard if needed
                    if docs_in_shard >= i64(config.docs_per_shard) {
                        if file_exists(shard_file) {
                            let size = get_file_size(shard_file)
                            shards = append(shards, ShardMetadata{
                                shard_id: shard_name(shard_index),
                                file_path: shard_file,
                                num_documents: docs_in_shard,
                                size_bytes: size,
                            })
                            log_success("Completed: " + shard_name(shard_index) + " (docs=" + i64_to_string(docs_in_shard) + ", bytes=" + i64_to_string(size) + ")")
                        }
                        
                        shard_index = shard_index + 1
                        docs_in_shard = 0
                        shard_file = join([]string{config.output_dir, shard_name(shard_index)}, "/")
                    }
                }
                
                page_lines = []
                
                if config.max_pages > 0 && total_pages >= i64(config.max_pages) {
                    break
                }
                
                if total_pages % 1000 == 0 {
                    printf("Processed pages: %d | current shard: %s | docs: %d\n", 
                        []interface{}{total_pages, shard_name(shard_index), docs_in_shard})
                }
            }
        }
    }
    
    // Finalize last shard
    if len(shard_file) > 0 && file_exists(shard_file) {
        let size = get_file_size(shard_file)
        if size > 0 {
            shards = append(shards, ShardMetadata{
                shard_id: shard_name(shard_index),
                file_path: shard_file,
                num_documents: docs_in_shard,
                size_bytes: size,
            })
        }
    }
    
    // Calculate totals
    let mut total_size_bytes: i64 = 0
    for i = 0; i < len(shards); i = i + 1 {
        total_size_bytes = total_size_bytes + shards[i].size_bytes
    }
    
    let avg_docs_per_shard: i64 = 0
    if len(shards) > 0 {
        avg_docs_per_shard = total_docs / i64(len(shards))
    }
    
    // Generate manifest
    log_progress("Generating manifest...")
    let manifest_json = generate_manifest_json(config, shards, total_pages, total_docs, total_size_bytes, avg_docs_per_shard)
    
    // Write manifest file
    let write_cmd = "cat > \"" + config.manifest_file + "\" << 'EOF'\n" + manifest_json + "\nEOF"
    let (_, code) = command(write_cmd)
    if code != 0 {
        log_error("Failed to write manifest file")
        return 1
    }
    
    log_success("Manifest saved: " + config.manifest_file)
    println("")
    
    // Print summary
    println("Summary:")
    printf("  Total pages   : %d\n", []interface{}{total_pages})
    printf("  Total shards  : %d\n", []interface{}{len(shards)})
    printf("  Total docs    : %d\n", []interface{}{total_docs})
    printf("  Total size    : %d bytes\n", []interface{}{total_size_bytes})
    println("")
    
    println("✅ Wikipedia sharding complete")
    return 0
}

fn generate_manifest_json(config: WikipediaConfig, shards: []ShardMetadata, total_pages: i64, total_docs: i64, total_size_bytes: i64, avg_docs: i64) -> string {
    let mut json = "{\n"
    json = json + "  \"dataset_name\": \"neurx-pretrain-wikipedia\",\n"
    json = json + "  \"version\": \"1.0\",\n"
    json = json + "  \"created_at\": \"2026-07-09T00:00:00Z\",\n"
    json = json + "  \"source_file\": \"" + config.input_bz2_file + "\",\n"
    json = json + "  \"total_shards\": " + i64_to_string(i64(len(shards))) + ",\n"
    json = json + "  \"total_documents\": " + i64_to_string(total_docs) + ",\n"
    json = json + "  \"total_size_bytes\": " + i64_to_string(total_size_bytes) + ",\n"
    json = json + "  \"average_docs_per_shard\": " + i64_to_string(avg_docs) + ",\n"
    json = json + "  \"shards\": [\n"
    
    for i = 0; i < len(shards); i = i + 1 {
        json = json + "    {\n"
        json = json + "      \"shard_id\": \"" + shards[i].shard_id + "\",\n"
        json = json + "      \"file_path\": \"" + shards[i].file_path + "\",\n"
        json = json + "      \"num_documents\": " + i64_to_string(shards[i].num_documents) + ",\n"
        json = json + "      \"size_bytes\": " + i64_to_string(shards[i].size_bytes) + "\n"
        json = json + "    }"
        
        if i < len(shards) - 1 {
            json = json + ","
        }
        json = json + "\n"
    }
    
    json = json + "  ]\n"
    json = json + "}\n"
    
    return json
}

// ============================================================================
// Main Entry Point
// ============================================================================

fn main() -> i32 {
    // Parse configuration from environment
    let neurx_home = getenv("NEURX_HOME", ".")
    let dataset_root = neurx_home + "/dataset/pretrain"
    
    let config = WikipediaConfig{
        input_bz2_file: getenv("ENWIKI_BZ2_FILE",
            dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2"),
        output_dir: getenv("ENWIKI_SHARD_DIR",
            dataset_root + "/shard"),
        manifest_file: getenv("ENWIKI_MANIFEST_FILE",
            dataset_root + "/manifest.json"),
        docs_per_shard: getenv_int("DOCS_PER_SHARD", 5000),
        max_pages: getenv_int("MAX_PAGES", 0),
    }
    
    return process_wikipedia(config)
}
