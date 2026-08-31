package neurx.tool.json_parser

use std.conv.int_to_string

extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_file_read(string path, int max_size) string

struct json_token {
    string key
    int value
    bool valid
}

func parse_tokenizer_json(string json_text) []json_token {
    []json_token tokens = make([]json_token, 160000)
    int token_count = 0

    int i = 0
    int len_text = len(json_text)

    for i < len_text {

        int quote_start = find_char(json_text, '"', i)
        if quote_start < 0 { break }

        int quote_end = find_char(json_text, '"', quote_start + 1)
        if quote_end < 0 { break }

        string key = __host_slice(json_text, quote_start + 1, quote_end)

        int colon_pos = find_char(json_text, ':', quote_end)
        if colon_pos < 0 { break }

        int value_start = colon_pos + 1
        for value_start < len_text && (json_text[value_start] == 32 || json_text[value_start] == 9) {
            value_start = value_start + 1
        }

        int value_end = value_start
        for value_end < len_text && json_text[value_end] >= 48 && json_text[value_end] <= 57 {
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

    []json_token result = make([]json_token, token_count)
    int j = 0
    for j < token_count {
        result[j] = tokens[j]
        j = j + 1
    }

    result
}

func find_char(string text, int target_char, int start_pos) int {
    int i = start_pos
    for i < len(text) {
        if text[i] == target_char {
            return i
        }
        i = i + 1
    }
    -1
}

func parse_int(string text) int {
    int result = 0
    int i = 0

    for i < len(text) {
        int ch = text[i]
        if ch >= 48 && ch <= 57 {
            result = result * 10 + (ch - 48)
        }
        i = i + 1
    }

    result
}

func escape_string(string text) string {
    string result = ""
    int i = 0

    for i < len(text) {
        int ch = text[i]

        if ch == 10 {
            result = result + "\\n"
        } else if ch == 9 {
            result = result + "\\t"
        } else if ch == 13 {
            result = result + "\\r"
        } else if ch == 92 {
            result = result + "\\\\"
        } else if ch == 34 {
            result = result + "\\\""
        } else if ch >= 32 && ch < 127 {

            result = result + string(ch)
        } else {

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

func hex_char(int value) string {
    if value < 10 {
        return string(48 + value)
    }
    string(97 + value - 10)
}

func write_vocab_file([]json_token tokens, string output_file_path) bool {

    sort_tokens_by_id(tokens)

    string output = ""
    int i = 0
    for i < len(tokens) {
        if tokens[i].valid {
            string escaped_key = escape_string(tokens[i].key)
            output = output + int_to_string(tokens[i].value) + "|" + escaped_key + "\n"
        }
        i = i + 1
    }

    true
}

func sort_tokens_by_id([]json_token tokens) {
    int n = len(tokens)
    int i = 0

    for i < n {
        int j = 0
        for j < n - i - 1 {
            if tokens[j].value > tokens[j + 1].value {

                json_token temp = tokens[j]
                tokens[j] = tokens[j + 1]
                tokens[j + 1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
}
