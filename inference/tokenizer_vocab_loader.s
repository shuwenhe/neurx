package neurx.inference.tokenizer_vocab_loader

use std.conv.int_to_string
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file}

extern "intrinsic" func __host_slice(string text, int start, int end) string

struct vocab_entry {
    int token_id
    string text
}

struct vocab_database {
    []vocab_entry entries
    int total_count
    bool loaded
}

var global_vocab vocab_database = vocab_database{entries: []vocab_entry{}, total_count: 0, loaded: false}

// 二分查找优化词表查询
func binary_search_vocab([]vocab_entry entries, int token_id) vocab_entry {
    int left = 0
    int right = len(entries) - 1
    
    while left <= right {
        int mid = left + (right - left) / 2
        vocab_entry mid_entry = entries[mid]
        
        if mid_entry.token_id == token_id {
            return mid_entry
        }
        
        if mid_entry.token_id < token_id {
            left = mid + 1
        } else {
            right = mid - 1
        }
    }
    
    // 未找到
    vocab_entry empty
    empty.token_id = -1
    empty.text = ""
    empty
}

// 从压缩的词表文件加载（文本格式优化）
func load_vocab_from_file(string vocab_file_path) bool {
    if global_vocab.loaded {
        return len(global_vocab.entries) > 0
    }
    
    if !runtime_file_exists(vocab_file_path) {
        return false
    }
    
    string content = runtime_read_text_file(vocab_file_path)
    if len(content) == 0 {
        return false
    }
    
    // 解析词表格式: "token_id|text\ntoken_id|text\n..."
    []vocab_entry entries = []vocab_entry{cap: 160000}
    int entry_count = 0
    
    int line_start = 0
    int i = 0
    
    while i < len(content) {
        int ch = content[i]
        
        if ch == 10 {  // '\n'
            if i > line_start {
                string line = __host_slice(content, line_start, i)
                vocab_entry entry = parse_vocab_line(line)
                
                if entry.token_id >= 0 {
                    entries[entry_count] = entry
                    entry_count = entry_count + 1
                }
            }
            line_start = i + 1
        }
        i = i + 1
    }
    
    // 处理最后一行
    if line_start < len(content) {
        string line = __host_slice(content, line_start, len(content))
        vocab_entry entry = parse_vocab_line(line)
        
        if entry.token_id >= 0 {
            entries[entry_count] = entry
            entry_count = entry_count + 1
        }
    }
    
    // 设置全局词表
    global_vocab.entries = entries
    global_vocab.total_count = entry_count
    global_vocab.loaded = true
    
    global_vocab.total_count > 0
}

// 解析单行词表条目
func parse_vocab_line(string line) vocab_entry {
    vocab_entry result
    result.token_id = -1
    result.text = ""
    
    // 格式: "123|hello"
    int pipe_pos = index_of(line, "|")
    if pipe_pos < 0 {
        return result
    }
    
    string token_str = __host_slice(line, 0, pipe_pos)
    string text_str = __host_slice(line, pipe_pos + 1, len(line))
    
    // 解析 token_id
    result.token_id = parse_int(token_str)
    result.text = unescape_string(text_str)
    
    result
}

// 简单的字符串查找
func index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    
    int i = 0
    while i <= len(text) - len(needle) {
        bool matched = true
        int j = 0
        while j < len(needle) {
            if __host_slice(text, i + j, i + j + 1) != __host_slice(needle, j, j + 1) {
                matched = false
                break
            }
            j = j + 1
        }
        
        if matched {
            return i
        }
        i = i + 1
    }
    
    -1
}

// 将字符串转换为整数
func parse_int(string text) int {
    int result = 0
    int i = 0
    
    while i < len(text) {
        int ch = text[i]
        if ch >= 48 && ch <= 57 {  // '0'-'9'
            result = result * 10 + (ch - 48)
        }
        i = i + 1
    }
    
    result
}

// 反转义字符串（处理转义序列）
func unescape_string(string text) string {
    string result = ""
    int i = 0
    
    while i < len(text) {
        if __host_slice(text, i, i + 1) == "\\" && i + 1 < len(text) {
            string next_char = __host_slice(text, i + 1, i + 2)
            
            if next_char == "n" {
                result = result + "\n"
                i = i + 2
            } else if next_char == "t" {
                result = result + "\t"
                i = i + 2
            } else if next_char == "r" {
                result = result + "\r"
                i = i + 2
            } else if next_char == "\\" {
                result = result + "\\"
                i = i + 2
            } else if next_char == "\"" {
                result = result + "\""
                i = i + 2
            } else {
                result = result + next_char
                i = i + 2
            }
        } else {
            result = result + __host_slice(text, i, i + 1)
            i = i + 1
        }
    }
    
    result
}

// 主要接口：查找 token 的文本
func get_token_text(int token_id) string {
    // 尝试加载词表
    if !global_vocab.loaded {
        string vocab_path = "/home/shuwen/shuwen/neurx/inference/qwen_vocab.txt"
        load_vocab_from_file(vocab_path)
    }
    
    if !global_vocab.loaded || len(global_vocab.entries) == 0 {
        return "<token_" + int_to_string(token_id) + ">"
    }
    
    // 二分查找
    vocab_entry found = binary_search_vocab(global_vocab.entries, token_id)
    
    if found.token_id == token_id {
        return found.text
    }
    
    // 未找到，返回占位符
    "<token_" + int_to_string(token_id) + ">"
}

// 获取词表统计信息
func get_vocab_stats() string {
    if !global_vocab.loaded {
        return "Vocabulary not loaded"
    }
    
    "Loaded " + int_to_string(global_vocab.total_count) + " vocabulary entries"
}
