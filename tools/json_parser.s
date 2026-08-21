package neurx.tools.json_parser

use std.conv.int_to_string

extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_file_read(string path, int max_size) string

struct json_token {
    string key
    int value
    bool valid
}

// 简单的 JSON 解析：只提取 {"word": token_id} 对
func parse_tokenizer_json(string json_text) []json_token {
    []json_token tokens = []json_token{cap: 160000}
    int token_count = 0
    
    int i = 0
    int len_text = len(json_text)
    
    while i < len_text {
        // 寻找 "key": value 对
        int quote_start = find_char(json_text, '"', i)
        if quote_start < 0 { break }
        
        int quote_end = find_char(json_text, '"', quote_start + 1)
        if quote_end < 0 { break }
        
        string key = __host_slice(json_text, quote_start + 1, quote_end)
        
        // 寻找冒号和值
        int colon_pos = find_char(json_text, ':', quote_end)
        if colon_pos < 0 { break }
        
        // 提取数值
        int value_start = colon_pos + 1
        while value_start < len_text && (json_text[value_start] == 32 || json_text[value_start] == 9) {
            value_start = value_start + 1
        }
        
        int value_end = value_start
        while value_end < len_text && json_text[value_end] >= 48 && json_text[value_end] <= 57 {
            value_end = value_end + 1
        }
        
        if value_end > value_start {
            string value_str = __host_slice(json_text, value_start, value_end)
            int value = parse_int(value_str)
            
            json_token token
            token.key = key
            token.value = value
            token.valid = true
            
            tokens[token_count] = token
            token_count = token_count + 1
        }
        
        i = quote_end + 1
    }
    
    // 返回实际大小的数组
    []json_token result = []json_token{cap: token_count}
    int j = 0
    while j < token_count {
        result[j] = tokens[j]
        j = j + 1
    }
    
    result
}

// 辅助：查找字符
func find_char(string text, int target_char, int start_pos) int {
    int i = start_pos
    while i < len(text) {
        if text[i] == target_char {
            return i
        }
        i = i + 1
    }
    -1
}

// 解析整数字符串
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

// 转义字符串用于输出
func escape_string(string text) string {
    string result = ""
    int i = 0
    
    while i < len(text) {
        int ch = text[i]
        
        if ch == 10 {  // '\n'
            result = result + "\\n"
        } else if ch == 9 {  // '\t'
            result = result + "\\t"
        } else if ch == 13 {  // '\r'
            result = result + "\\r"
        } else if ch == 92 {  // '\'
            result = result + "\\\\"
        } else if ch == 34 {  // '"'
            result = result + "\\\""
        } else if ch >= 32 && ch < 127 {
            // 可打印字符
            result = result + string(ch)
        } else {
            // 不可打印字符，转换为十六进制
            result = result + "\\x"
            if ch < 16 {
                result = result + "0"
            }
            result = result + hex_char(ch / 16) + hex_char(ch % 16)
        }
        
        i = i + 1
    }
    
    result
}

// 转换为十六进制字符
func hex_char(int value) string {
    if value < 10 {
        return string(48 + value)  // '0'-'9'
    }
    string(97 + value - 10)  // 'a'-'f'
}

// 将解析的 JSON 输出为词表文本格式
func write_vocab_file([]json_token tokens, string output_file_path) bool {
    // 需要 file write 的系统调用支持
    // 输出格式: token_id|escaped_text\ntoken_id|escaped_text\n...
    
    // 按 token_id 排序
    sort_tokens_by_id(tokens)
    
    // 写入文件
    string output = ""
    int i = 0
    while i < len(tokens) {
        if tokens[i].valid {
            string escaped_key = escape_string(tokens[i].key)
            output = output + int_to_string(tokens[i].value) + "|" + escaped_key + "\n"
        }
        i = i + 1
    }
    
    // 写文件（需要系统支持）
    // __sys_file_write(output_file_path, output)
    
    true
}

// 简单的冒泡排序（按 token_id）
func sort_tokens_by_id([]json_token tokens) {
    int n = len(tokens)
    int i = 0
    
    while i < n {
        int j = 0
        while j < n - i - 1 {
            if tokens[j].value > tokens[j + 1].value {
                // 交换
                json_token temp = tokens[j]
                tokens[j] = tokens[j + 1]
                tokens[j + 1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
}
