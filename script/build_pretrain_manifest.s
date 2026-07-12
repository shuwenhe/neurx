package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, trim}
use std.io.println

func string_char(int c) string {
    string(c)
}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string shard_dir = runtime_env_get("NEURX_PRETRAIN_SHARD_DIR", project_root + "/dataset/pretrain/shard")
    string manifest_file = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    string force_rebuild = runtime_env_get("NEURX_PRETRAIN_REBUILD_MANIFEST", "0")

    println("NeurX Pretrain Manifest Builder (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("Shard dir    : " + shard_dir)
    println("Manifest     : " + manifest_file)
    println("")

    if !runtime_file_exists(shard_dir) {
        println("❌ shard directory not found: " + shard_dir)
        return 1
    }

    if force_rebuild != "1" && runtime_file_exists(manifest_file) {
        println("[pretrain-manifest] using existing manifest: " + manifest_file)
        return 0
    }

    string shard_output = trim(runtime_run_command_output("find " + shell_escape(shard_dir) + " -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort"))
    if shard_output == "" {
        println("❌ no shard files found in: " + shard_dir)
        return 1
    }

    string manifest_dir = trim(runtime_run_command_output("dirname " + shell_escape(manifest_file)))
    if manifest_dir != "" {
        _ = runtime_run_command_output("mkdir -p " + shell_escape(manifest_dir))
    }

    int total_documents = 0
    int total_size_bytes = 0
    string json_header = "{\n"
    json_header = json_header + "  \"dataset_name\": \"neurx-pretrain-wikipedia\",\n"
    json_header = json_header + "  \"version\": \"1.0\",\n"
    json_header = json_header + "  \"source_dir\": " + json_escape(shard_dir) + ",\n"
    json_header = json_header + "  \"shards\": [\n"
    _ = runtime_run_command_output("printf %s " + shell_escape(json_header) + " > " + shell_escape(manifest_file))

    int shard_count = 0
    int i = 0
    string current_path = ""
    while i <= len(shard_output) {
        bool at_end = i == len(shard_output)
        bool at_newline = !at_end && shard_output[i] == 10
        if at_end || at_newline {
            string shard_path = trim(current_path)
            current_path = ""
            if shard_path != "" {
                int doc_count = parse_int(trim(runtime_run_command_output("wc -l < " + shell_escape(shard_path))), 0)
                int size_bytes = parse_int(trim(runtime_run_command_output("stat -c%s " + shell_escape(shard_path) + " 2>/dev/null || stat -f%z " + shell_escape(shard_path))), 0)
                total_documents = total_documents + doc_count
                total_size_bytes = total_size_bytes + size_bytes
                string shard_json = ""
                if shard_count > 0 {
                    shard_json = ",\n"
                }
                shard_json = shard_json + "    {\n"
                shard_json = shard_json + "      \"shard_id\": " + json_escape(path_basename(shard_path)) + ",\n"
                shard_json = shard_json + "      \"file_path\": " + json_escape(shard_path) + ",\n"
                shard_json = shard_json + "      \"num_documents\": " + int_to_string(doc_count) + ",\n"
                shard_json = shard_json + "      \"size_bytes\": " + int_to_string(size_bytes) + "\n"
                shard_json = shard_json + "    }"
                _ = runtime_run_command_output("printf %s " + shell_escape(shard_json) + " >> " + shell_escape(manifest_file))
                shard_count = shard_count + 1
            }
        } else if shard_output[i] != 13 {
            current_path = current_path + string_char(shard_output[i])
        }
        i = i + 1
    }

    string json_footer = "\n  ],\n"
    json_footer = json_footer + "  \"total_shards\": " + int_to_string(shard_count) + ",\n"
    json_footer = json_footer + "  \"total_documents\": " + int_to_string(total_documents) + ",\n"
    json_footer = json_footer + "  \"total_size_bytes\": " + int_to_string(total_size_bytes) + ",\n"
    if shard_count > 0 {
        json_footer = json_footer + "  \"average_docs_per_shard\": " + int_to_string(total_documents / shard_count) + "\n"
    } else {
        json_footer = json_footer + "  \"average_docs_per_shard\": 0\n"
    }
    json_footer = json_footer + "}\n"
    _ = runtime_run_command_output("printf %s " + shell_escape(json_footer) + " >> " + shell_escape(manifest_file))
    println("[pretrain-manifest] wrote manifest: " + manifest_file)
    println("[pretrain-manifest] shard files: " + int_to_string(shard_count))
    println("[pretrain-manifest] documents  : " + int_to_string(total_documents))
    println("[pretrain-manifest] bytes      : " + int_to_string(total_size_bytes))
    0
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    while i < len(s) {
        string ch = string_char(s[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}

func json_escape(string s) string {
    string out = "\""
    int i = 0
    while i < len(s) {
        string ch = string_char(s[i])
        if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\\" {
            out = out + "\\\\"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "\""
    out
}

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if text == "" {
        return fallback
    }
    int sign = 1
    int i = 0
    if text[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    bool negative = value < 0
    int remaining = value
    if negative {
        remaining = -remaining
    }
    string out = ""
    while remaining > 0 {
        int digit = remaining - (remaining / 10) * 10
        out = string_char(digit + 48) + out
        remaining = remaining / 10
    }
    if negative {
        out = "-" + out
    }
    out
}

func path_basename(string path) string {
    int last = -1
    int i = 0
    while i < len(path) {
        if path[i] == 47 {
            last = i
        }
        i = i + 1
    }
    if last < 0 {
        return path
    }
    if last + 1 >= len(path) {
        return ""
    }
    string out = ""
    int j = last + 1
    while j < len(path) {
        out = out + string_char(path[j])
        j = j + 1
    }
    out
}
