// ============================================================================
// NeurX Wikipedia Shard Processing
//
// S implementation that actually shards the Wikipedia dump.
// It streams the bz2 input through awk and writes shard_*.jsonl files plus a
// manifest directly from this entry point.
// ============================================================================

package neurx.shard.shard_wikipedia

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}
use std.io.println

func string_char(int c) string {
    string(c)
}

func trim(string s) string {
    int begin = 0
    while begin < len(s) {
        string ch = string_char(s[begin])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            begin = begin + 1
        } else {
            break
        }
    }

    int end = len(s)
    while end > begin {
        string ch = string_char(s[end - 1])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            end = end - 1
        } else {
            break
        }
    }

    string out = ""
    int i = begin
    while i < end {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
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
    out = out + "'"
    out
}

func get_neurx_home() string {
    runtime_env_get("NEURX_HOME", ".")
}

func get_input_file() string {
    string neurx_home = get_neurx_home()
    string dataset_root = neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_BZ2_FILE", dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2")
}

func get_output_dir() string {
    string neurx_home = get_neurx_home()
    string dataset_root = neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_SHARD_DIR", dataset_root + "/shard")
}

func get_manifest_file() string {
    string neurx_home = get_neurx_home()
    string dataset_root = neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_MANIFEST_FILE", dataset_root + "/manifest.json")
}

func get_docs_per_shard() string {
    runtime_env_get("DOCS_PER_SHARD", "5000")
}

func emit_progress(string message) {
    // 输出到标准错误，带换行符
    runtime_run_command_output("printf '%s\\n' " + shell_escape(message) + " >&2")
}

func get_max_pages() string {
    runtime_env_get("MAX_PAGES", "0")
}

func main() int {
    println("")
    println("[*] NeurX Wikipedia Shard Processing")
    println("")

    string input_file = get_input_file()
    string output_dir = get_output_dir()
    string manifest_file = get_manifest_file()
    string docs_per_shard = get_docs_per_shard()
    string max_pages = get_max_pages()
    string progress_log = runtime_env_get("NEURX_SHARD_PROGRESS_LOG", "")

    println("Configuration:")
    println("  Input file    : " + input_file)
    println("  Output dir    : " + output_dir)
    println("  Manifest file : " + manifest_file)
    println("  Docs/shard    : " + docs_per_shard)
    println("  Max pages     : " + max_pages)
    println("")

    if !runtime_file_exists(input_file) {
        println("Error: input file not found: " + input_file)
        return 1
    }

    string mkdir_out = runtime_run_command_output("mkdir -p " + shell_escape(output_dir))
    if len(trim(mkdir_out)) > 0 {
        println(mkdir_out)
    }

    string cleanup_cmd = "rm -f " + shell_escape(output_dir) + "/shard_*.jsonl " +
        shell_escape(output_dir + "/.wikipedia_dump.xml") + " " + shell_escape(manifest_file)
    string cleanup_out = runtime_run_command_output("sh -c " + shell_escape(cleanup_cmd))
    if len(trim(cleanup_out)) > 0 {
        println(cleanup_out)
    }

    string created_at = trim(runtime_run_command_output("date -u +%Y-%m-%dT%H:%M:%SZ"))

    string awk_program = ""
    awk_program = awk_program + "function json_escape(s,   t) { "
    awk_program = awk_program + "t = s; "
    awk_program = awk_program + "gsub(/\\\\/, \"\\\\\\\\\", t); "
    awk_program = awk_program + "gsub(/\"/, \"\\\\\\\"\", t); "
    awk_program = awk_program + "gsub(/\\r/, \"\\\\r\", t); "
    awk_program = awk_program + "gsub(/\\t/, \"\\\\t\", t); "
    awk_program = awk_program + "gsub(/\\n/, \"\\\\n\", t); "
    awk_program = awk_program + "return \"\\\"\" t \"\\\"\" "
    awk_program = awk_program + "} "
    awk_program = awk_program + "function emit(msg) { if (progress_log != \"\") { print msg >> progress_log; fflush(progress_log) } else { print msg > \"/dev/stderr\"; fflush(\"/dev/stderr\") } } "
    awk_program = awk_program + "function emit_line(msg) { emit(msg \"\\n\") } "
    awk_program = awk_program + "function progress_bar(done, total, width,   filled, i, out) { "
    awk_program = awk_program + "if (total < 1) total = 1; "
    awk_program = awk_program + "filled = int((done * width) / total); "
    awk_program = awk_program + "if (filled < 0) filled = 0; "
    awk_program = awk_program + "if (filled > width) filled = width; "
    awk_program = awk_program + "out = \"[\"; "
    awk_program = awk_program + "for (i = 0; i < filled; i = i + 1) out = out \"#\"; "
    awk_program = awk_program + "for (i = filled; i < width; i = i + 1) out = out \"-\"; "
    awk_program = awk_program + "out = out \"]\"; "
    awk_program = awk_program + "out "
    awk_program = awk_program + "} "
    awk_program = awk_program + "function shard_status(prefix, shard_no, shard_done, shard_total, shard_file) { "
    awk_program = awk_program + "emit_line(prefix \" shard \" shard_no \" file=\" shard_file \" \" progress_bar(shard_done, shard_total, 40) \" \" shard_done \"/\" shard_total \" docs\") "
    awk_program = awk_program + "} "
    awk_program = awk_program + "function shard_path(idx) { return sprintf(\"%s/shard_%05d.jsonl\", out_dir, idx) } "
    awk_program = awk_program + "BEGIN { "
    awk_program = awk_program + "RS = \"</page>\"; ORS = \"\"; "
    awk_program = awk_program + "docs_per_shard = docs_per_shard + 0; "
    awk_program = awk_program + "max_pages = max_pages + 0; "
    awk_program = awk_program + "if (docs_per_shard < 1) docs_per_shard = 1; "
    awk_program = awk_program + "doc_count = 0; shard_index = 0; in_shard = 0; current = shard_path(0); "
    awk_program = awk_program + "emit_line(\"[shard] shard 0 started processing Wikipedia dump\") "
    awk_program = awk_program + "} "
    awk_program = awk_program + "{ "
    awk_program = awk_program + "page = $0; "
    awk_program = awk_program + "if (page !~ /<page>/) next; "
    awk_program = awk_program + "if (max_pages > 0 && doc_count >= max_pages) next; "
    awk_program = awk_program + "page = page \"</page>\"; "
    awk_program = awk_program + "if (doc_count == 0) { shard_status(\"[shard] active\", shard_index, in_shard, docs_per_shard, current) } "
    awk_program = awk_program + "if (in_shard >= docs_per_shard) { shard_index = shard_index + 1; in_shard = 0; current = shard_path(shard_index); shard_status(\"[shard] switching to\", shard_index, in_shard, docs_per_shard, current) } "
    awk_program = awk_program + "print \"{\\\"document_index\\\":\" doc_count \",\\\"shard_index\\\":\" shard_index \",\\\"xml\\\":\" json_escape(page) \"}\\n\" >> current; "
    awk_program = awk_program + "doc_count = doc_count + 1; in_shard = in_shard + 1; "
    awk_program = awk_program + "if (doc_count % 100 == 0 || in_shard == 1) { shard_status(\"[shard] progress\", shard_index, in_shard, docs_per_shard, current) } "
    awk_program = awk_program + "} "
    awk_program = awk_program + "END { "
    awk_program = awk_program + "total_shards = (doc_count == 0) ? 0 : (shard_index + 1); "
    awk_program = awk_program + "print \"{\" > manifest; "
    awk_program = awk_program + "print \"  \\\"dataset_name\\\": \\\"neurx-wikipedia\\\",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"source_file\\\": \\\"\" input_file \"\\\",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"shard_dir\\\": \\\"\" out_dir \"\\\",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"manifest_file\\\": \\\"\" manifest \"\\\",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"created_at\\\": \\\"\" created_at \"\\\",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"docs_per_shard\\\": \" docs_per_shard \",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"max_pages\\\": \" max_pages \",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"total_documents\\\": \" doc_count \",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"total_shards\\\": \" total_shards \",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"format\\\": \\\"jsonl\\\",\" >> manifest; "
    awk_program = awk_program + "print \"  \\\"shards\\\": [\" >> manifest; "
    awk_program = awk_program + "for (i = 0; i < total_shards; i = i + 1) { "
    awk_program = awk_program + "if (i > 0) print \",\" >> manifest; "
    awk_program = awk_program + "print \"    {\\\"shard_id\\\": \" i \", \\\"path\\\": \\\"\" shard_path(i) \"\\\"}\" >> manifest; "
    awk_program = awk_program + "} "
    awk_program = awk_program + "print \"  ]\" >> manifest; "
    awk_program = awk_program + "print \"}\" >> manifest; "
    awk_program = awk_program + "emit_line(\"[shard] generated \" doc_count \" documents into \" total_shards \" shards\") "
    awk_program = awk_program + "} "

    string process_cmd = ""
    process_cmd = process_cmd + "set -e; "
    process_cmd = process_cmd + "created_at=" + shell_escape(created_at) + "; "
    process_cmd = process_cmd + "echo '[shard] decoding Wikipedia dump...' >&2; "
    process_cmd = process_cmd + "bzip2 -dc " + shell_escape(input_file) + " | awk "
    process_cmd = process_cmd + "-v out_dir=" + shell_escape(output_dir) + " "
    process_cmd = process_cmd + "-v manifest=" + shell_escape(manifest_file) + " "
    process_cmd = process_cmd + "-v docs_per_shard=" + shell_escape(docs_per_shard) + " "
    process_cmd = process_cmd + "-v max_pages=" + shell_escape(max_pages) + " "
    process_cmd = process_cmd + "-v input_file=" + shell_escape(input_file) + " "
    process_cmd = process_cmd + "-v created_at=\"$created_at\" "
    process_cmd = process_cmd + "-v progress_log=" + shell_escape(progress_log) + " "
    process_cmd = process_cmd + shell_escape(awk_program)

    println("[shard] launching Wikipedia shard pipeline")
    runtime_run_command_output(process_cmd)
    if !runtime_file_exists(manifest_file) {
        println("Error: shard generation command failed")
        return 1
    }

    println("")
    println("[+] Wikipedia sharding complete")
    println("[+] Manifest : " + manifest_file)
    println("")

    0
}
