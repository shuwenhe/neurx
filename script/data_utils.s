// ============================================================================
// NeurX Data Processing Utilities (S Language Implementation)
// 
// Provides common utilities for data cleaning and sharding:
// - JSON encode/decode (simplified)
// - File and directory operations
// - Path manipulation
// - String utilities
// ============================================================================

package neurx.script.data_utils

use std.io
use std.os
use std.strings

// ============================================================================
// JSON Helpers
// ============================================================================

// Simple JSON value wrapper for encoder/decoder
struct json_value {
    string type    // "null", "bool", "number", "string", "array", "object"
    string str_val
    []json_value array_val
    map[string]json_value obj_val
}

// Encode string for JSON
func json_encode_string(s: string) string {
    // Escape special characters
    let mut result = "\""
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
    result = result + "\""
    result
}

// Decode JSON string value
func json_decode_string(s: string) string {
    if !string_has_prefix(s, "\"") || !string_has_suffix(s, "\"") {
        ""
    }
    
    let inner = s[1 : len(s) - 1]
    let mut result = ""
    let mut i = 0
    
    while i < len(inner) {
        if inner[i] == '\\' && i + 1 < len(inner) {
            match inner[i + 1] {
                case '"':
                    result = result + "\""
                    i = i + 2
                case '\\':
                    result = result + "\\"
                    i = i + 2
                case 'n':
                    result = result + "\n"
                    i = i + 2
                case 'r':
                    result = result + "\r"
                    i = i + 2
                case 't':
                    result = result + "\t"
                    i = i + 2
                case _:
                    result = result + string(inner[i])
                    i = i + 1
            }
        } else {
            result = result + string(inner[i])
            i = i + 1
        }
    }
    
    result
}

// Simple JSON object builder (limited, for manifest generation)
func json_object_to_string(fields: map[string]string, indent: int) string {
    let mut result = "{\n"
    let pad = string_repeat(" ", indent)
    let mut first = true
    
    for k, v in fields {
        if !first {
            result = result + ",\n"
        }
        first = false
        result = result + pad + "  " + json_encode_string(k) + ": " + v
    }
    
    result = result + "\n" + pad + "}"
    result
}

// ============================================================================
// Path Operations
// ============================================================================

func path_join(parts: []string) string {
    string_join(parts, "/")
}

func path_dirname(path: string) string {
    let parts = string_split(path, "/")
    if len(parts) <= 1 {
        "."
    } else {
        string_join(parts[0 : len(parts) - 1], "/")
    }
}

func path_basename(path: string) string {
    let parts = string_split(path, "/")
    if len(parts) == 0 {
        ""
    } else {
        parts[len(parts) - 1]
    }
}

func path_exists(path: string) bool {
    runtime_file_exists(path)
}

func path_is_dir(path: string) bool {
    runtime_is_dir(path)
}

// ============================================================================
// File Operations
// ============================================================================

func file_read_text(path: string) (string, bool) {
    runtime_read_text_file(path)
}

func file_write_text(path: string, content: string) bool {
    // Ensure parent directory exists
    let dir = path_dirname(path)
    if !path_exists(dir) {
        _ = runtime_make_dirs(dir)
    }
    runtime_write_text_file(path, content)
}

func file_append_text(path: string, content: string) bool {
    let (existing, ok) = file_read_text(path)
    if !ok && path_exists(path) {
        return false  // file exists but can't read
    }
    let new_content = if ok { existing + content } else { content }
    file_write_text(path, new_content)
}

func file_delete(path: string) bool {
    runtime_remove_file(path)
}

func file_size(path: string) i64 {
    runtime_file_size(path)
}

// Count lines in a file
func file_count_lines(path: string) (i64, bool) {
    let (content, ok) = file_read_text(path)
    if !ok {
        (0, false)
    }
    
    let lines = string_split(content, "\n")
    (i64(len(lines)), true)
}

// List files in directory matching suffix
func dir_list_files(path: string, suffixes: []string) []string {
    if !path_is_dir(path) {
        return []string{}
    }
    
    let files = runtime_list_dir(path)
    let mut result = []string{}
    
    for _, file in files {
        let fname = path_basename(file)
        for _, suffix in suffixes {
            if string_has_suffix(string_to_lower(fname), suffix) {
                result = append(result, path_join([]string{path, fname}))
                break
            }
        }
    }
    
    result
}

// ============================================================================
// String Utilities
// ============================================================================

func string_repeat(s: string, count: int) string {
    let mut result = ""
    for i = 0; i < count; i = i + 1 {
        result = result + s
    }
    result
}

// Normalize whitespace (similar to Python's split/strip)
func normalize_whitespace(s: string) string {
    let parts = string_split(string_trim(s), " ")
    string_join(parts, " ")
}

// Hash a string (simplified - would use SHA256 in real impl)
func hash_key(s: string) string {
    // For now, return a placeholder - would integrate proper hash lib
    "hash_" + string_to_lower(s[0 : min(10, len(s))])
}

// ============================================================================
// Directory Utilities  
// ============================================================================

func ensure_dir(path: string) bool {
    if path_exists(path) {
        return path_is_dir(path)
    }
    runtime_make_dirs(path)
}

func clear_dir(path: string) bool {
    if !path_exists(path) {
        return ensure_dir(path)
    }
    
    let files = runtime_list_dir(path)
    for _, file in files {
        _ = file_delete(file)
    }
    true
}

// ============================================================================
// Environment and Config
// ============================================================================

func get_env(key: string, default_val: string) string {
    let val = runtime_env_get(key)
    if val == "" {
        default_val
    } else {
        val
    }
}

func get_env_int(key: string, default_val: int) int {
    let val = runtime_env_get(key)
    if val == "" {
        default_val
    } else {
        // Parse as int - would need proper parsing
        default_val
    }
}

// ============================================================================
// Logging
// ============================================================================

pub func log_info(msg: string) {
    println(msg)
}

pub func log_warn(msg: string) {
    println("⚠ " + msg)
}

pub func log_error(msg: string) {
    println("✗ " + msg)
}

pub func log_success(msg: string) {
    println("✓ " + msg)
}

// ============================================================================
// Math Helpers
// ============================================================================

func min(a: i64, b: i64) i64 {
    if a < b { a } else { b }
}

func max(a: i64, b: i64) i64 {
    if a > b { a } else { b }
}

func div_round_up(a: i64, b: i64) i64 {
    (a + b - 1) / b
}
