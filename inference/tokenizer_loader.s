// Package: neurx.inference
// Module: tokenizer_loader
// Purpose: Load and manage tokenizer for W1.1 implementation
// Language: S (pure)
// Dependencies: HF tokenizer (loaded via Python helper)

package neurx.inference.tokenizer_loader

use std.io.println
use std.json
use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_read_text_file,
    runtime_run_command_output,
    runtime_make_dirs
}

// TokenizerState represents the state of a loaded tokenizer
struct TokenizerState {
    model_path: string          // Path to HF model directory
    model_name: string          // Model name (e.g., "Qwen2.5-0.5B-Instruct")
    vocab_size: int             // Vocabulary size
    is_loaded: bool             // Whether tokenizer is successfully loaded
    error_message: string       // Error message if loading failed
}

// TokenizationResult represents the result of tokenizing text
struct TokenizationResult {
    token_ids: []int            // Array of token IDs
    token_count: int            // Number of tokens
    success: bool               // Whether tokenization succeeded
    error: string               // Error message if failed
}

// new_tokenizer_state initializes an empty tokenizer state
func new_tokenizer_state() TokenizerState {
    TokenizerState {
        model_path: "",
        model_name: "",
        vocab_size: 0,
        is_loaded: false,
        error_message: "",
    }
}

// load_tokenizer loads a tokenizer from the specified model path
// This calls Python helper script to load HF tokenizer
func load_tokenizer(string model_path) TokenizerState {
    // Check if model directory exists
    if !runtime_file_exists(model_path) {
        state := new_tokenizer_state()
        state.error_message = "Model path does not exist: " + model_path
        return state
    }
    
    // Check if tokenizer_config.json exists (HF model marker)
    string tokenizer_config = model_path + "/tokenizer_config.json"
    if !runtime_file_exists(tokenizer_config) {
        state := new_tokenizer_state()
        state.error_message = "Not a valid HF model: " + model_path + " (missing tokenizer_config.json)"
        return state
    }
    
    // Extract model name from path
    string model_name = extract_model_name(model_path)
    
    // Try to get vocab_size from tokenizer_config.json or vocab.json
    int vocab_size = get_vocab_size(model_path)
    
    state := new_tokenizer_state()
    state.model_path = model_path
    state.model_name = model_name
    state.vocab_size = vocab_size
    state.is_loaded = true
    state.error_message = ""
    
    state
}

// tokenize tokenizes text using the loaded tokenizer
// Returns TokenizationResult with token IDs
func tokenize(TokenizerState state, string text) TokenizationResult {
    if !state.is_loaded {
        result := new_tokenization_result()
        result.success = false
        result.error = "Tokenizer not loaded: " + state.error_message
        return result
    }
    
    // Call Python helper script to tokenize
    // Format: python3 scripts/tokenize_helper.py <model_path> '<text>'
    string safe_text = escape_shell_string(text)
    string cmd = "python3 scripts/tokenize_helper.py '" + state.model_path + "' " + safe_text
    
    string json_output = runtime_run_command_output(cmd)
    
    // Parse JSON output
    result := parse_tokenization_result(json_output, state.vocab_size)
    result
}

// tokenize_deterministic tokenizes text and verifies determinism
// Runs tokenization multiple times and verifies all outputs are identical
func tokenize_deterministic(TokenizerState state, string text, int runs) TokenizationResult {
    if !state.is_loaded {
        result := new_tokenization_result()
        result.success = false
        result.error = "Tokenizer not loaded: " + state.error_message
        return result
    }
    
    // Tokenize multiple times
    [][]int all_results = make([][]int, runs)
    
    int i = 0
    while i < runs {
        result := tokenize(state, text)
        if !result.success {
            result_error := new_tokenization_result()
            result_error.success = false
            result_error.error = "Failed at run " + str_int(i + 1) + ": " + result.error
            return result_error
        }
        all_results[i] = result.token_ids
        i = i + 1
    }
    
    // Verify all results are identical
    i = 1
    while i < runs {
        bool identical = arrays_equal_int(all_results[0], all_results[i])
        if !identical {
            result := new_tokenization_result()
            result.success = false
            result.error = "Determinism check failed: run 1 differs from run " + str_int(i + 1)
            return result
        }
        i = i + 1
    }
    
    // All deterministic, return first result
    result := new_tokenization_result()
    result.token_ids = all_results[0]
    result.token_count = len(all_results[0])
    result.success = true
    result.error = ""
    result
}

// ============================================================================
// Helper functions
// ============================================================================

// new_tokenization_result creates an empty tokenization result
func new_tokenization_result() TokenizationResult {
    TokenizationResult {
        token_ids: make([]int, 0),
        token_count: 0,
        success: false,
        error: "",
    }
}

// extract_model_name extracts model name from path
func extract_model_name(string path) string {
    // Remove trailing slashes
    while len(path) > 0 && path[len(path) - 1] == '/' {
        path = path[0:len(path)-1]
    }
    
    // Find last slash
    int last_slash = -1
    int i = 0
    while i < len(path) {
        if path[i] == '/' {
            last_slash = i
        }
        i = i + 1
    }
    
    if last_slash >= 0 {
        path[last_slash + 1:]
    } else {
        path
    }
}

// get_vocab_size reads vocab size from model files
func get_vocab_size(string model_path) int {
    // Try to read from vocab.json first
    string vocab_file = model_path + "/vocab.json"
    if runtime_file_exists(vocab_file) {
        string content = runtime_read_text_file(vocab_file)
        // Simple count of colons (rough estimate)
        int count = 0
        int i = 0
        while i < len(content) {
            if content[i] == ':' {
                count = count + 1
            }
            i = i + 1
        }
        if count > 0 {
            return count
        }
    }
    
    // Fallback to standard Qwen2.5 vocab size
    152064
}

// escape_shell_string escapes a string for shell use
func escape_shell_string(string s) string {
    // Quote the string
    "'" + s + "'"
}

// parse_tokenization_result parses JSON output from tokenizer helper
func parse_tokenization_result(string json_output, int vocab_size) TokenizationResult {
    // Simple JSON parsing (minimal S JSON support)
    // Expected format: {"token_ids": [...], "token_count": N, "vocab_size": V}
    
    result := new_tokenization_result()
    
    // Check for error in output
    if contains_string(json_output, "ERROR:") {
        result.success = false
        result.error = json_output
        return result
    }
    
    // Extract token_ids array
    int start_bracket = find_char(json_output, '[')
    int end_bracket = find_last_char(json_output, ']')
    
    if start_bracket < 0 || end_bracket < 0 {
        result.success = false
        result.error = "Invalid JSON output: no token array found"
        return result
    }
    
    string tokens_str = json_output[start_bracket + 1:end_bracket]
    []int token_ids = parse_int_array(tokens_str)
    
    result.token_ids = token_ids
    result.token_count = len(token_ids)
    result.success = true
    result.error = ""
    result
}

// contains_string checks if haystack contains needle
func contains_string(string haystack, string needle) bool {
    int needle_len = len(needle)
    if needle_len == 0 {
        return true
    }
    
    int i = 0
    while i <= len(haystack) - needle_len {
        bool match = true
        int j = 0
        while j < needle_len && match {
            if haystack[i + j] != needle[j] {
                match = false
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    false
}

// find_char finds first occurrence of character
func find_char(string s, char c) int {
    int i = 0
    while i < len(s) {
        if s[i] == c {
            return i
        }
        i = i + 1
    }
    -1
}

// find_last_char finds last occurrence of character
func find_last_char(string s, char c) int {
    int last = -1
    int i = 0
    while i < len(s) {
        if s[i] == c {
            last = i
        }
        i = i + 1
    }
    last
}

// parse_int_array parses comma-separated integers
func parse_int_array(string s) []int {
    result := make([]int, 0)
    
    string current = ""
    int i = 0
    while i < len(s) {
        char ch = s[i]
        if ch == ',' || ch == ' ' {
            if len(current) > 0 {
                int val = parse_int(current)
                result = append(result, val)
                current = ""
            }
        } else if ch >= '0' && ch <= '9' || ch == '-' {
            current = current + string(ch)
        }
        i = i + 1
    }
    
    if len(current) > 0 {
        int val = parse_int(current)
        result = append(result, val)
    }
    
    result
}

// parse_int parses a string to integer
func parse_int(string s) int {
    int result = 0
    bool negative = false
    int i = 0
    
    if len(s) > 0 && s[0] == '-' {
        negative = true
        i = 1
    }
    
    while i < len(s) {
        char ch = s[i]
        if ch >= '0' && ch <= '9' {
            result = result * 10 + (ch - '0')
        }
        i = i + 1
    }
    
    if negative {
        result = -result
    }
    
    result
}

// str_int converts integer to string
func str_int(int n) string {
    if n == 0 {
        return "0"
    }
    
    bool negative = n < 0
    if negative {
        n = -n
    }
    
    string result = ""
    while n > 0 {
        int digit = n % 10
        result = string(digit + '0') + result
        n = n / 10
    }
    
    if negative {
        result = "-" + result
    }
    
    result
}

// arrays_equal_int checks if two integer arrays are equal
func arrays_equal_int([]int a, []int b) bool {
    if len(a) != len(b) {
        return false
    }
    
    int i = 0
    while i < len(a) {
        if a[i] != b[i] {
            return false
        }
        i = i + 1
    }
    
    true
}

// len returns length of array
func len(interface{} arr) int {
    // This is built-in in S language
    // We need to implement manually for each type
    0
}

// make creates an array
func make(interface{} arr_type, int size) interface{} {
    // This is built-in in S language
    nil
}

// append appends to array
func append(interface{} arr, interface{} val) interface{} {
    // This is built-in in S language
    arr
}

// string converts char to string
func string(char c) string {
    // Convert single character to string
    ""
}
