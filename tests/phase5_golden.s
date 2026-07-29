package main

use neurx.runtime.io.{runtime_read_text_file, runtime_file_exists}
use std.io.println

struct phase5_prompt_entry {
    string name
    string text
    string category
    int tokens_count
}

struct phase5_prompt_catalog {
    []phase5_prompt_entry prompts
    string default_prompt
}

func phase5_trim(string text) string {
    int start = 0
    int end = phase5_length(text)
    while start < end && phase5_is_space(text[start]) {
        start = start + 1
    }
    while end > start && phase5_is_space(text[end - 1]) {
        end = end - 1
    }
    phase5_substring(text, start, end)
}

func phase5_length(string text) int {
    int i = 0
    while i < 1000000 {
        if i >= len(text) {
            break
        }
        i = i + 1
    }
    i
}

func phase5_is_space(int ch) bool {
    ch == 32 || ch == 9 || ch == 10 || ch == 13
}

func phase5_substring(string text, int start, int end) string {
    string out = ""
    int i = start
    int n = phase5_length(text)
    while i < end && i < n {
        out = out + string(text[i])
        i = i + 1
    }
    out
}

func phase5_index_of(string text, string needle) int {
    int text_len = phase5_length(text)
    int needle_len = phase5_length(needle)
    if needle_len == 0 {
        return 0
    }
    if needle_len > text_len {
        return -1
    }
    int i = 0
    while i <= text_len - needle_len {
        int j = 0
        bool match = true
        while j < needle_len {
            if text[i + j] != needle[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func phase5_split_lines(string text) []string {
    []string lines = []string{cap: 16}
    string current = ""
    int i = 0
    int n = phase5_length(text)
    while i < n {
        int ch = text[i]
        if ch == 10 {
            lines.push(current)
            current = ""
        } else if ch != 13 {
            current = current + string(ch)
        }
        i = i + 1
    }
    if phase5_length(current) > 0 {
        lines.push(current)
    }
    lines
}

func phase5_extract_json_string(string line, string key) string {
    int key_pos = phase5_index_of(line, key)
    if key_pos < 0 {
        return ""
    }
    int colon_pos = phase5_index_of(phase5_substring(line, key_pos, phase5_length(line)), ":")
    if colon_pos < 0 {
        return ""
    }
    int cursor = key_pos + colon_pos + 1
    while cursor < phase5_length(line) && phase5_is_space(line[cursor]) {
        cursor = cursor + 1
    }
    if cursor >= phase5_length(line) || line[cursor] != 34 {
        return ""
    }
    cursor = cursor + 1
    string out = ""
    while cursor < phase5_length(line) {
        int ch = line[cursor]
        if ch == 34 {
            break
        }
        if ch == 92 && cursor + 1 < phase5_length(line) {
            int next = line[cursor + 1]
            if next == 34 || next == 92 {
                out = out + string(next)
                cursor = cursor + 2
                continue
            }
            if next == 110 {
                out = out + "\n"
                cursor = cursor + 2
                continue
            }
            if next == 116 {
                out = out + "\t"
                cursor = cursor + 2
                continue
            }
        }
        out = out + string(ch)
        cursor = cursor + 1
    }
    out
}

func phase5_extract_json_int(string line, string key) int {
    int key_pos = phase5_index_of(line, key)
    if key_pos < 0 {
        return -1
    }
    int colon_pos = phase5_index_of(phase5_substring(line, key_pos, phase5_length(line)), ":")
    if colon_pos < 0 {
        return -1
    }
    int cursor = key_pos + colon_pos + 1
    while cursor < phase5_length(line) && phase5_is_space(line[cursor]) {
        cursor = cursor + 1
    }
    int sign = 1
    if cursor < phase5_length(line) && line[cursor] == 45 {
        sign = -1
        cursor = cursor + 1
    }
    int value = 0
    bool found = false
    while cursor < phase5_length(line) {
        int ch = line[cursor]
        if ch < 48 || ch > 57 {
            break
        }
        value = value * 10 + (ch - 48)
        found = true
        cursor = cursor + 1
    }
    if !found {
        return -1
    }
    sign * value
}

func phase5_load_prompt_catalog(string path) phase5_prompt_catalog {
    phase5_prompt_catalog catalog
    catalog.prompts = []phase5_prompt_entry{cap: 16}
    catalog.default_prompt = ""
    if !runtime_file_exists(path) {
        println("phase5-golden-prompt FAIL missing_file=" + path)
        return catalog
    }
    []string lines = phase5_split_lines(runtime_read_text_file(path))
    phase5_prompt_entry current
    bool in_entry = false
    int i = 0
    while i < len(lines) {
        string line = phase5_trim(lines[i])
        if phase5_index_of(line, "\"default_prompt\"") >= 0 {
            catalog.default_prompt = phase5_extract_json_string(line, "\"default_prompt\"")
        }
        if phase5_index_of(line, "\"name\"") >= 0 {
            current = phase5_prompt_entry {
                name: phase5_extract_json_string(line, "\"name\""),
                text: "",
                category: "",
                tokens_count: -1,
            }
            in_entry = true
        } else if in_entry && phase5_index_of(line, "\"text\"") >= 0 {
            current.text = phase5_extract_json_string(line, "\"text\"")
        } else if in_entry && phase5_index_of(line, "\"category\"") >= 0 {
            current.category = phase5_extract_json_string(line, "\"category\"")
        } else if in_entry && phase5_index_of(line, "\"tokens_count\"") >= 0 {
            current.tokens_count = phase5_extract_json_int(line, "\"tokens_count\"")
            catalog.prompts.push(current)
            in_entry = false
        }
        i = i + 1
    }
    catalog
}

func phase5_find_prompt(phase5_prompt_catalog catalog, string text) phase5_prompt_entry {
    phase5_prompt_entry empty
    int i = 0
    while i < len(catalog.prompts) {
        if catalog.prompts[i].text == text {
            return catalog.prompts[i]
        }
        i = i + 1
    }
    empty
}

func main() int {
    string prompt_path = "tests/golden/prompts.json"
    phase5_prompt_catalog catalog = phase5_load_prompt_catalog(prompt_path)
    if phase5_length(catalog.default_prompt) == 0 {
        println("phase5-golden-prompt FAIL missing_default_prompt")
        return 1
    }
    phase5_prompt_entry default_entry = phase5_find_prompt(catalog, catalog.default_prompt)
    if phase5_length(default_entry.name) == 0 {
        println("phase5-golden-prompt FAIL default_prompt_not_listed")
        return 1
    }
    if len(catalog.prompts) == 0 {
        println("phase5-golden-prompt FAIL empty_prompt_list")
        return 1
    }
    int i = 0
    while i < len(catalog.prompts) {
        phase5_prompt_entry entry = catalog.prompts[i]
        if phase5_length(entry.name) == 0 || phase5_length(entry.text) == 0 || phase5_length(entry.category) == 0 {
            println("phase5-golden-prompt FAIL invalid_entry=" + string(i))
            return 1
        }
        if entry.tokens_count <= 0 {
            println("phase5-golden-prompt FAIL invalid_tokens=" + entry.name)
            return 1
        }
        i = i + 1
    }
    println("phase5-golden-prompt PASS prompts=" + string(len(catalog.prompts)) + " default=" + default_entry.name + " tokens=" + string(default_entry.tokens_count))
    0
}
