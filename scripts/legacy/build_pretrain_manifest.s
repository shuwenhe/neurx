package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_run_command_output, trim}
func manifest_log(string s) int {
    _ = runtime_run_command_output("printf '%s\\n' " + shell_escape(s))
    0
}
extern "intrinsic" func __host_write_text_file(string path, string content) int
func runtime_write_text_file(string path, string content) () {
    _ = __host_write_text_file(path, content)
}

func string_char(int c) string {
    string(c)
}

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let shard_dir = runtime_env_get("NEURX_PRETRAIN_SHARD_DIR", project_root + "/dataset/pretrain/shard")
    let manifest_file = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    let force_rebuild = runtime_env_get("NEURX_PRETRAIN_REBUILD_MANIFEST", "0")
    let work_dir = project_root + "/artifacts/build/build_pretrain_manifest"
    let shard_list_file = work_dir + "/shard_list.txt"
    let doc_count_file = work_dir + "/doc_count.txt"
    let size_bytes_file = work_dir + "/size_bytes.txt"
    let shard_count_file = work_dir + "/shard_count.txt"
    let total_documents_file = work_dir + "/total_documents.txt"
    let total_size_bytes_file = work_dir + "/total_size_bytes.txt"
    let average_docs_file = work_dir + "/average_docs.txt"
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
    _ = runtime_run_command_output("mkdir -p " + shell_escape(work_dir) + "; printf ok")
    _ = runtime_run_command_output("mkdir -p " + shell_escape(path_dirname(manifest_file)) + "; printf ok")
    runtime_write_text_file(shard_list_file, "")
    runtime_write_text_file(doc_count_file, "0\n")
    runtime_write_text_file(size_bytes_file, "0\n")
    runtime_write_text_file(shard_count_file, "0\n")
    runtime_write_text_file(total_documents_file, "0\n")
    runtime_write_text_file(total_size_bytes_file, "0\n")
    runtime_write_text_file(average_docs_file, "0\n")
    if trim(runtime_run_command_output("find " + shell_escape(shard_dir) + " -maxdepth 1 -type f -name 'shard_*.jsonl' -print | sort > " + shell_escape(shard_list_file) + "; printf ok")) != "ok" {
        manifest_log("❌ failed to enumerate shards in: " + shard_dir)
        return 1
    }
    let shard_output = trim(runtime_read_text_file(shard_list_file))
    if shard_output == "" {
        manifest_log("❌ no shard files found in: " + shard_dir)
        return 1
    }
    int total_documents = 0
    int total_size_bytes = 0
    let json_header = "{\n"
    json_header = json_header + "  \"dataset_name\": \"neurx-pretrain-wikipedia\",\n"
    json_header = json_header + "  \"version\": \"1.0\",\n"
    json_header = json_header + "  \"source_dir\": " + json_escape(shard_dir) + ",\n"
    json_header = json_header + "  \"shards\": [\n"
    runtime_write_text_file(manifest_file, json_header)
    int shard_count = 0
    int i = 0
    let current_path = ""
    while i <= len(shard_output) {
        bool at_end = i == len(shard_output)
        bool at_newline = !at_end && shard_output[i] == 10
        if at_end || at_newline {
            let shard_path = trim(current_path)
            current_path = ""
            if shard_path != "" {
                _ = runtime_run_command_output("wc -l < " + shell_escape(shard_path) + " > " + shell_escape(doc_count_file) + "; printf ok")
                _ = runtime_run_command_output("wc -c < " + shell_escape(shard_path) + " > " + shell_escape(size_bytes_file) + "; printf ok")
                let doc_count_text = trim(runtime_read_text_file(doc_count_file))
                let size_bytes_text = trim(runtime_read_text_file(size_bytes_file))
                if doc_count_text == "" {
                    doc_count_text = "0"
                }
                if size_bytes_text == "" {
                    size_bytes_text = "0"
                }
                total_documents = total_documents + parse_int(doc_count_text, 0)
                total_size_bytes = total_size_bytes + parse_int(size_bytes_text, 0)
                _ = runtime_run_command_output("sh -c " + shell_escape("count=$(cat " + shell_escape(shard_count_file) + "); new=$((count + 1)); printf '%s\\n' \"$new\" > " + shell_escape(shard_count_file) + "; printf ok"))
                _ = runtime_run_command_output("sh -c " + shell_escape("total=$(cat " + shell_escape(total_documents_file) + "); new=$((total + " + doc_count_text + ")); printf '%s\\n' \"$new\" > " + shell_escape(total_documents_file) + "; printf ok"))
                _ = runtime_run_command_output("sh -c " + shell_escape("total=$(cat " + shell_escape(total_size_bytes_file) + "); new=$((total + " + size_bytes_text + ")); printf '%s\\n' \"$new\" > " + shell_escape(total_size_bytes_file) + "; printf ok"))
                let shard_json = ""
                if shard_count > 0 {
                    shard_json = ",\n"
                }
                shard_json = shard_json + "    {\n"
                shard_json = shard_json + "      \"shard_id\": " + json_escape(path_basename(shard_path)) + ",\n"
                shard_json = shard_json + "      \"file_path\": " + json_escape(shard_path) + ",\n"
                shard_json = shard_json + "      \"num_documents\": " + doc_count_text + ",\n"
                shard_json = shard_json + "      \"size_bytes\": " + size_bytes_text + "\n"
                shard_json = shard_json + "    }"
                runtime_write_text_file(manifest_file, runtime_read_text_file(manifest_file) + shard_json)
                shard_count = shard_count + 1
            }
        } else if shard_output[i] != 13 {
            current_path = current_path + string_char(shard_output[i])
        }
        i = i + 1
    }
    let shard_count_text = trim(runtime_read_text_file(shard_count_file))
    let total_documents_text = trim(runtime_read_text_file(total_documents_file))
    let total_size_bytes_text = trim(runtime_read_text_file(total_size_bytes_file))
    if shard_count_text == "" {
        shard_count_text = "0"
    }
    if total_documents_text == "" {
        total_documents_text = "0"
    }
    if total_size_bytes_text == "" {
        total_size_bytes_text = "0"
    }
    if parse_int(shard_count_text, 0) > 0 {
        _ = runtime_run_command_output("sh -c " + shell_escape("total=$(cat " + shell_escape(total_documents_file) + "); count=$(cat " + shell_escape(shard_count_file) + "); avg=$((total / count)); printf '%s\\n' \"$avg\" > " + shell_escape(average_docs_file) + "; printf ok"))
    }
    let average_docs_text = trim(runtime_read_text_file(average_docs_file))
    if average_docs_text == "" {
        average_docs_text = "0"
    }
    let json_footer = "\n  ],\n"
    json_footer = json_footer + "  \"total_shards\": " + shard_count_text + ",\n"
    json_footer = json_footer + "  \"total_documents\": " + total_documents_text + ",\n"
    json_footer = json_footer + "  \"total_size_bytes\": " + total_size_bytes_text + ",\n"
    json_footer = json_footer + "  \"average_docs_per_shard\": " + average_docs_text + "\n"
    json_footer = json_footer + "}\n"
    runtime_write_text_file(manifest_file, runtime_read_text_file(manifest_file) + json_footer)
    manifest_log("[pretrain-manifest] wrote manifest: " + manifest_file)
    manifest_log("[pretrain-manifest] shard files: " + shard_count_text)
    manifest_log("[pretrain-manifest] documents  : " + total_documents_text)
    manifest_log("[pretrain-manifest] bytes      : " + total_size_bytes_text)
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
