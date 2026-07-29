package main

use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file}
use neurx.strings.{string_index_of, string_length, string_split, string_trim, substring}
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

func phase5_digit_value(string digit) int {
    if digit == "0" { return 0 }
    if digit == "1" { return 1 }
    if digit == "2" { return 2 }
    if digit == "3" { return 3 }
    if digit == "4" { return 4 }
    if digit == "5" { return 5 }
    if digit == "6" { return 6 }
    if digit == "7" { return 7 }
    if digit == "8" { return 8 }
    if digit == "9" { return 9 }
    0
}

func phase5_extract_json_string(string line, string key) string {
    int key_pos = string_index_of(line, key)
    if key_pos < 0 {
        return ""
    }
    string rest = string_trim(substring(line, key_pos + string_length(key), string_length(line)))
    int colon_pos = string_index_of(rest, ":")
    if colon_pos < 0 {
        return ""
    }
    rest = string_trim(substring(rest, colon_pos + 1, string_length(rest)))
    if string_length(rest) < 2 || substring(rest, 0, 1) != "\"" {
        return ""
    }
    string body = substring(rest, 1, string_length(rest))
    int end_quote = string_index_of(body, "\"")
    if end_quote < 0 {
        return ""
    }
    substring(body, 0, end_quote)
}

func phase5_extract_json_int(string line, string key) int {
    int key_pos = string_index_of(line, key)
    if key_pos < 0 {
        return -1
    }
    string rest = string_trim(substring(line, key_pos + string_length(key), string_length(line)))
    int colon_pos = string_index_of(rest, ":")
    if colon_pos < 0 {
        return -1
    }
    rest = string_trim(substring(rest, colon_pos + 1, string_length(rest)))
    int sign = 1
    if string_length(rest) > 0 && substring(rest, 0, 1) == "-" {
        sign = -1
        rest = substring(rest, 1, string_length(rest))
    }
    int i = 0
    int value = 0
    bool found = false
    while i < string_length(rest) {
        string digit = substring(rest, i, i + 1)
        if digit != "0" && digit != "1" && digit != "2" && digit != "3" && digit != "4" &&
           digit != "5" && digit != "6" && digit != "7" && digit != "8" && digit != "9" {
            break
        }
        value = value * 10 + phase5_digit_value(digit)
        found = true
        i = i + 1
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
    []string lines = string_split(runtime_read_text_file(path), "\n")
    phase5_prompt_entry current
    bool in_entry = false
    int i = 0
    while i < len(lines) {
        string line = string_trim(lines[i])
        if string_index_of(line, "\"default_prompt\"") >= 0 {
            catalog.default_prompt = phase5_extract_json_string(line, "\"default_prompt\"")
        }
        if string_index_of(line, "\"name\"") >= 0 {
            current = phase5_prompt_entry {
                name: phase5_extract_json_string(line, "\"name\""),
                text: "",
                category: "",
                tokens_count: -1,
            }
            in_entry = true
        } else if in_entry && string_index_of(line, "\"text\"") >= 0 {
            current.text = phase5_extract_json_string(line, "\"text\"")
        } else if in_entry && string_index_of(line, "\"category\"") >= 0 {
            current.category = phase5_extract_json_string(line, "\"category\"")
        } else if in_entry && string_index_of(line, "\"tokens_count\"") >= 0 {
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
    if string_length(catalog.default_prompt) == 0 {
        println("phase5-golden-prompt FAIL missing_default_prompt")
        return 1
    }
    phase5_prompt_entry default_entry = phase5_find_prompt(catalog, catalog.default_prompt)
    if string_length(default_entry.name) == 0 {
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
        if string_length(entry.name) == 0 || string_length(entry.text) == 0 || string_length(entry.category) == 0 {
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
