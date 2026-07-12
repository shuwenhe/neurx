package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command, runtime_run_command_output, runtime_shell_escape, runtime_write_text_file, trim}
use std.strings
use std.io.println

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

    string shard_output = trim(runtime_run_command_output("find " + runtime_shell_escape(shard_dir) + " -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort"))
    []string shard_paths = split_lines(shard_output)
    if len(shard_paths) == 0 {
        println("❌ no shard files found in: " + shard_dir)
        return 1
    }

    string manifest_dir = trim(runtime_run_command_output("dirname " + runtime_shell_escape(manifest_file)))
    if manifest_dir != "" {
        _ = runtime_run_command("mkdir -p " + runtime_shell_escape(manifest_dir))
    }

    int total_documents = 0
    int total_size_bytes = 0
    string json = "{\n"
    json = json + "  \"dataset_name\": \"neurx-pretrain-wikipedia\",\n"
    json = json + "  \"version\": \"1.0\",\n"
    json = json + "  \"source_dir\": " + json_escape(shard_dir) + ",\n"
    json = json + "  \"total_shards\": "

    int shard_count = 0
    int i = 0
    string shards_json = ""
    while i < len(shard_paths) {
        string shard_path = trim(shard_paths[i])
        if shard_path != "" {
            int doc_count = parse_int(trim(runtime_run_command_output("wc -l < " + runtime_shell_escape(shard_path))), 0)
            int size_bytes = parse_int(trim(runtime_run_command_output("stat -c%s " + runtime_shell_escape(shard_path) + " 2>/dev/null || stat -f%z " + runtime_shell_escape(shard_path))), 0)
            total_documents = total_documents + doc_count
            total_size_bytes = total_size_bytes + size_bytes
            if shard_count > 0 {
                shards_json = shards_json + ",\n"
            }
            shards_json = shards_json + "    {\n"
            shards_json = shards_json + "      \"shard_id\": " + json_escape(path_basename(shard_path)) + ",\n"
            shards_json = shards_json + "      \"file_path\": " + json_escape(shard_path) + ",\n"
            shards_json = shards_json + "      \"num_documents\": " + strings.from_i64(doc_count) + ",\n"
            shards_json = shards_json + "      \"size_bytes\": " + strings.from_i64(size_bytes) + "\n"
            shards_json = shards_json + "    }"
            shard_count = shard_count + 1
        }
        i = i + 1
    }

    json = json + strings.from_i64(shard_count) + ",\n"
    json = json + "  \"total_documents\": " + strings.from_i64(total_documents) + ",\n"
    json = json + "  \"total_size_bytes\": " + strings.from_i64(total_size_bytes) + ",\n"
    if shard_count > 0 {
        json = json + "  \"average_docs_per_shard\": " + strings.from_i64(total_documents / shard_count) + ",\n"
    } else {
        json = json + "  \"average_docs_per_shard\": 0,\n"
    }
    json = json + "  \"shards\": [\n"
    json = json + shards_json + "\n"
    json = json + "  ]\n"
    json = json + "}\n"

    runtime_write_text_file(manifest_file, json)
    println("[pretrain-manifest] wrote manifest: " + manifest_file)
    println("[pretrain-manifest] shard files: " + strings.from_i64(shard_count))
    println("[pretrain-manifest] documents  : " + strings.from_i64(total_documents))
    println("[pretrain-manifest] bytes      : " + strings.from_i64(total_size_bytes))
    0
}

func split_lines(string text) []string {
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = char_at(text, i)
        if ch == "\n" {
            string line = trim(current)
            if line != "" {
                lines.push(line)
            }
            current = ""
        } else if ch != "\r" {
            current = current + ch
        }
        i = i + 1
    }
    string tail = trim(current)
    if tail != "" {
        lines.push(tail)
    }
    lines
}

func json_escape(string s) string {
    string out = "\""
    int i = 0
    while i < len(s) {
        string ch = char_at(s, i)
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
    slice(path, last + 1, len(path))
}
