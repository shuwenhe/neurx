use std.text.parse_int_default

package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, runtime_write_text_file, trim}

func manifest_log(string s) int {
    println(s)
    0
}

func string_char(int c) string {
    string(c)
}

func count_lines(string text) int {
    if text == "" {
        return 0
    }
    int lines = 0
    int i = 0
    while i < len(text) {
        if text[i] == 10 {
            lines = lines + 1
        }
        i = i + 1
    }
    if text[len(text) - 1] != 10 {
        lines = lines + 1
    }
    lines
}

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let shard_dir = runtime_env_get("NEURX_PRETRAIN_SHARD_DIR", project_root + "/dataset/pretrain/shard")
    let manifest_file = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    let force_rebuild = runtime_env_get("NEURX_PRETRAIN_REBUILD_MANIFEST", "0")
    let work_dir = project_root + "/artifacts/build/build_pretrain_manifest"
    let shard_list_file = runtime_env_get("NEURX_PRETRAIN_SHARD_LIST_FILE", work_dir + "/shard_list.txt")
    manifest_log("NeurX Pretrain manifest Builder (S Lang)")
    manifest_log("")
    manifest_log("Project root : " + project_root)
    manifest_log("Shard dir    : " + shard_dir)
    manifest_log("manifest     : " + manifest_file)
    manifest_log("")
    if !runtime_file_exists(shard_dir) {
        manifest_log("❌ shard directory not found: " + shard_dir)
        return 1
    }
    if force_rebuild != "1" && runtime_file_exists(manifest_file) {
        manifest_log("[pretrain-manifest] using existing manifest: " + manifest_file)
        return 0
    }
    if !runtime_file_exists(shard_list_file) {
        manifest_log("❌ shard list file not found: " + shard_list_file)
        return 1
    }
    let shard_output = trim(runtime_read_text_file(shard_list_file))
    if shard_output == "" {
        manifest_log("❌ no shard files found in: " + shard_dir)
        return 1
    }
    int total_documents = 0
    int total_size_bytes = 0
    int shard_count = 0
    string manifest_text = "{\n"
    manifest_text = manifest_text + "  \"dataset_name\": \"neurx-pretrain-wikipedia\",\n"
    manifest_text = manifest_text + "  \"version\": \"1.0\",\n"
    manifest_text = manifest_text + "  \"source_dir\": " + json_escape(shard_dir) + ",\n"
    manifest_text = manifest_text + "  \"shards\": [\n"
    int i = 0
    let current_path = ""
    while i <= len(shard_output) {
        bool at_end = i == len(shard_output)
        bool at_newline = !at_end && shard_output[i] == 10
        if at_end || at_newline {
            let shard_path = trim(current_path)
            current_path = ""
            if shard_path != "" {
                string shard_text = runtime_read_text_file(shard_path)
                int doc_count = count_lines(shard_text)
                int size_bytes = len(shard_text)
                total_documents = total_documents + doc_count
                total_size_bytes = total_size_bytes + size_bytes
                string shard_json = ""
                if shard_count > 0 {
                    shard_json = ",\n"
                }
                shard_json = shard_json + "    {\n"
                shard_json = shard_json + "      \"shard_id\": " + json_escape(path_basename(shard_path)) + ",\n"
                shard_json = shard_json + "      \"file_path\": " + json_escape(shard_path) + ",\n"
                shard_json = shard_json + "      \"num_documents\": " + int_to_str(doc_count) + ",\n"
                shard_json = shard_json + "      \"size_bytes\": " + int_to_str(size_bytes) + "\n"
                shard_json = shard_json + "    }"
                manifest_text = manifest_text + shard_json
                shard_count = shard_count + 1
            }
        } else if shard_output[i] != 13 {
            current_path = current_path + string_char(shard_output[i])
        }
        i = i + 1
    }
    int average_docs = 0
    if shard_count > 0 {
        average_docs = total_documents / shard_count
    }
    manifest_text = manifest_text + "\n  ],\n"
    manifest_text = manifest_text + "  \"total_shards\": " + int_to_str(shard_count) + ",\n"
    manifest_text = manifest_text + "  \"total_documents\": " + int_to_str(total_documents) + ",\n"
    manifest_text = manifest_text + "  \"total_size_bytes\": " + int_to_str(total_size_bytes) + ",\n"
    manifest_text = manifest_text + "  \"average_docs_per_shard\": " + int_to_str(average_docs) + "\n"
    manifest_text = manifest_text + "}\n"
    runtime_write_text_file(manifest_file, manifest_text)
    manifest_log("[pretrain-manifest] wrote manifest: " + manifest_file)
    manifest_log("[pretrain-manifest] shard files: " + int_to_str(shard_count))
    manifest_log("[pretrain-manifest] documents  : " + int_to_str(total_documents))
    manifest_log("[pretrain-manifest] bytes      : " + int_to_str(total_size_bytes))
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

func path_dirname(string path) string {
    int last = -1
    int i = 0
    while i < len(path) {
        if path[i] == 47 {
            last = i
        }
        i = i + 1
    }
    if last < 0 {
        return "."
    }
    if last == 0 {
        return "/"
    }
    string out = ""
    int j = 0
    while j < last {
        out = out + string_char(path[j])
        j = j + 1
    }
    out
}
