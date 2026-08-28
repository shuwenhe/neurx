package neurx.shard.shard_wikipedia
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}
func string_char(int c) string {
    string(c)
}
func trim(string s) string {
    begin := 0
    for begin < len(s) {
        ch := string_char(s[begin])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            begin = begin + 1
        } else {
            break
        }
    }
    end := len(s)
    for end > begin {
        ch := string_char(s[end - 1])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            end = end - 1
        } else {
            break
        }
    }
    out := ""
    i := begin
    for i < end {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}
func shell_escape(string s) string {
    out := "'"
    i := 0
    for i < len(s) {
        ch := string_char(s[i])
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
    neurx_home := get_neurx_home()
    dataset_root := neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_BZ2_FILE", dataset_root + "/raw/enwiki-latest-pages-articles.xml.bz2")
}
func get_output_dir() string {
    neurx_home := get_neurx_home()
    dataset_root := neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_SHARD_DIR", dataset_root + "/shard")
}
func get_manifest_file() string {
    neurx_home := get_neurx_home()
    dataset_root := neurx_home + "/dataset/pretrain"
    runtime_env_get("ENWIKI_MANIFEST_FILE", dataset_root + "/manifest.json")
}
func get_docs_per_shard() string {
    runtime_env_get("DOCS_PER_SHARD", "5000")
}
func emit_progress(string message) {
    runtime_run_command_output("printf '%s\\n' " + shell_escape(message) + " >&2")
}
func get_max_pages() string {
    runtime_env_get("MAX_PAGES", "0")
}
func main() {
    println("")
    println("[*] NeurX Wikipedia Shard Processing")
    println("")
    input_file := get_input_file()
    output_dir := get_output_dir()
    manifest_file := get_manifest_file()
    docs_per_shard := get_docs_per_shard()
    max_pages := get_max_pages()
    progress_log := runtime_env_get("NEURX_SHARD_PROGRESS_LOG", "")
    resume := runtime_env_get("NEURX_SHARD_RESUME", "1")
    force_rebuild := runtime_env_get("NEURX_SHARD_FORCE_REBUILD", "0")
    completion_file := output_dir + "/.wikipedia_shard_complete"
    state_file := output_dir + "/.wikipedia_shard_state"
    println("Configuration:")
    println("  Input file    : " + input_file)
    println("  Output dir    : " + output_dir)
        println("  manifest file : " + manifest_file)
        println("  Docs/shard    : " + docs_per_shard)
        println("  Max pages     : " + max_pages)
    println("  Resume        : " + resume)
    println("  Force rebuild : " + force_rebuild)
    println("")
    if !runtime_file_exists(input_file) {
        println("Error: input file not found: " + input_file)
        return 1
    }
    mkdir_out := runtime_run_command_output("mkdir -p " + shell_escape(output_dir))
    if len(trim(mkdir_out)) > 0 {
        println(mkdir_out)
    }
    if force_rebuild == "1" || resume != "1" {
          cleanup_cmd := "rm -f " + shell_escape(output_dir) + "/shard_*.jsonl " +
              shell_escape(output_dir + "/.wikipedia_dump.xml") + " " + shell_escape(manifest_file) + " " +
              shell_escape(state_file) + " " + shell_escape(completion_file)
          cleanup_out := runtime_run_command_output("sh -c " + shell_escape(cleanup_cmd))
          if len(trim(cleanup_out)) > 0 {
              println(cleanup_out)
          }
    }
    created_at := trim(runtime_run_command_output("date -u +%Y-%m-%dT%H:%M:%SZ"))
    awk_program := ""
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
    awk_program = awk_program + "doc_count = resume_docs + 0; seen_pages = 0; shard_index = start_shard + 0; in_shard = start_in_shard + 0; last_written_shard = start_last_shard + 0; current = shard_path(shard_index); "
    awk_program = awk_program + "emit_line(\"[shard] resume documents=\" doc_count \" next_shard=\" shard_index \" in_shard=\" in_shard) "
    awk_program = awk_program + "} "
    awk_program = awk_program + "{ "
    awk_program = awk_program + "page = $0; "
    awk_program = awk_program + "if (page !~ /<page>/) next; "
    awk_program = awk_program + "if (seen_pages < resume_docs) { seen_pages = seen_pages + 1; next } "
    awk_program = awk_program + "if (max_pages > 0 && doc_count >= max_pages) next; "
    awk_program = awk_program + "seen_pages = seen_pages + 1; "
    awk_program = awk_program + "page = page \"</page>\"; "
    awk_program = awk_program + "if (doc_count == 0) { shard_status(\"[shard] active\", shard_index, in_shard, docs_per_shard, current) } "
    awk_program = awk_program + "if (in_shard >= docs_per_shard) { shard_index = shard_index + 1; in_shard = 0; current = shard_path(shard_index); shard_status(\"[shard] switching to\", shard_index, in_shard, docs_per_shard, current) } "
    awk_program = awk_program + "print \"{\\\"document_index\\\":\" doc_count \",\\\"shard_index\\\":\" shard_index \",\\\"xml\\\":\" json_escape(page) \"}\\n\" >> current; "
    awk_program = awk_program + "last_written_shard = shard_index; "
    awk_program = awk_program + "doc_count = doc_count + 1; in_shard = in_shard + 1; "
    awk_program = awk_program + "if (doc_count % 100 == 0 || in_shard == 1) { shard_status(\"[shard] progress\", shard_index, in_shard, docs_per_shard, current) } "
    awk_program = awk_program + "} "
    awk_program = awk_program + "END { "
    awk_program = awk_program + "total_shards = last_written_shard + 1; "
    awk_program = awk_program + "print \"{\" > manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"dataset_name\\\": \\\"neurx-wikipedia\\\",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"source_file\\\": \\\"\" input_file \"\\\",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"shard_dir\\\": \\\"\" out_dir \"\\\",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"manifest_file\\\": \\\"\" manifest \"\\\",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"created_at\\\": \\\"\" created_at \"\\\",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"docs_per_shard\\\": \" docs_per_shard \",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"max_pages\\\": \" max_pages \",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"total_documents\\\": \" doc_count \",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"total_shards\\\": \" total_shards \",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"format\\\": \\\"jsonl\\\",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"  \\\"shards\\\": [\" >> manifest_tmp; "
    awk_program = awk_program + "for (i = 0; i < total_shards; i = i + 1) { "
    awk_program = awk_program + "if (i > 0) print \",\" >> manifest_tmp; "
    awk_program = awk_program + "print \"    {\\\"shard_id\\\": \" i \", \\\"path\\\": \\\"\" shard_path(i) \"\\\"}\" >> manifest_tmp; "
    awk_program = awk_program + "} "
    awk_program = awk_program + "print \"  ]\" >> manifest_tmp; "
    awk_program = awk_program + "print \"}\" >> manifest_tmp; "
    awk_program = awk_program + "emit_line(\"[shard] generated \" doc_count \" documents into \" total_shards \" shards\") "
    awk_program = awk_program + "} "
    process_cmd := ""
    process_cmd = process_cmd + "set -e; "
    process_cmd = process_cmd + "rm -f " + shell_escape(completion_file) + " " + shell_escape(completion_file + ".tmp") + " " + shell_escape(manifest_file + ".tmp") + "; "
    process_cmd = process_cmd + "created_at=" + shell_escape(created_at) + "; "
    process_cmd = process_cmd + "resume_docs=0; start_shard=0; start_in_shard=0; start_last_shard=-1; shard_count=0; "
    process_cmd = process_cmd + "if [ " + shell_escape(resume) + " = 1 ]; then "
    process_cmd = process_cmd + "for shard_file in " + shell_escape(output_dir) + "/shard_*.jsonl; do "
    process_cmd = process_cmd + "[ -f \"$shard_file\" ] || continue; "
    process_cmd = process_cmd + "expected_name=$(printf 'shard_%05d.jsonl' \"$shard_count\"); "
    process_cmd = process_cmd + "if [ \"$(basename \"$shard_file\")\" != \"$expected_name\" ]; then echo \"non-contiguous shard sequence at $shard_file (expected $expected_name)\" >&2; exit 2; fi; "
    process_cmd = process_cmd + "if [ \"$shard_count\" -gt 0 ] && [ \"$start_in_shard\" -ne " + shell_escape(docs_per_shard) + " ]; then echo 'only the final shard may be partial' >&2; exit 2; fi; "
    process_cmd = process_cmd + "line_count=$(wc -l < \"$shard_file\"); "
    process_cmd = process_cmd + "if [ \"$line_count\" -gt 0 ] && [ -n \"$(tail -c 1 \"$shard_file\")\" ]; then echo \"partial final JSONL line in $shard_file; use NEURX_SHARD_FORCE_REBUILD=1\" >&2; exit 2; fi; "
    process_cmd = process_cmd + "if [ \"$line_count\" -gt " + shell_escape(docs_per_shard) + " ]; then echo \"invalid oversized shard: $shard_file\" >&2; exit 2; fi; "
    process_cmd = process_cmd + "resume_docs=$((resume_docs + line_count)); start_in_shard=$line_count; start_last_shard=$shard_count; shard_count=$((shard_count + 1)); "
    process_cmd = process_cmd + "done; "
    process_cmd = process_cmd + "if [ \"$start_in_shard\" -ge " + shell_escape(docs_per_shard) + " ]; then start_shard=$shard_count; start_in_shard=0; else start_shard=$start_last_shard; fi; "
    process_cmd = process_cmd + "if [ \"$start_shard\" -lt 0 ]; then start_shard=0; fi; "
    process_cmd = process_cmd + "fi; "
    process_cmd = process_cmd + "echo \"[shard] resume scan: documents=$resume_docs shards=$shard_count next_shard=$start_shard offset=$start_in_shard\" >&2; "
    process_cmd = process_cmd + "source_identity=$(stat -c '%s:%Y' " + shell_escape(input_file) + " 2>/dev/null || stat -f '%z:%m' " + shell_escape(input_file) + "); "
    process_cmd = process_cmd + "expected_state=\"$source_identity:" + docs_per_shard + "\"; "
    process_cmd = process_cmd + "if [ -f " + shell_escape(state_file) + " ]; then saved_state=$(cat " + shell_escape(state_file) + "); if [ \"$saved_state\" != \"$expected_state\" ]; then echo 'shard resume configuration/source mismatch; use NEURX_SHARD_FORCE_REBUILD=1' >&2; exit 2; fi; "
    process_cmd = process_cmd + "else printf '%s\\n' \"$expected_state\" > " + shell_escape(state_file + ".tmp") + "; mv " + shell_escape(state_file + ".tmp") + " " + shell_escape(state_file) + "; fi; "
    process_cmd = process_cmd + "echo '[shard] decoding Wikipedia dump...' >&2; "
    process_cmd = process_cmd + "bzip2 -dc " + shell_escape(input_file) + " | awk "
    process_cmd = process_cmd + "-v out_dir=" + shell_escape(output_dir) + " "
    process_cmd = process_cmd + "-v manifest=" + shell_escape(manifest_file) + " "
    process_cmd = process_cmd + "-v manifest_tmp=" + shell_escape(manifest_file + ".tmp") + " "
    process_cmd = process_cmd + "-v docs_per_shard=" + shell_escape(docs_per_shard) + " "
    process_cmd = process_cmd + "-v max_pages=" + shell_escape(max_pages) + " "
    process_cmd = process_cmd + "-v input_file=" + shell_escape(input_file) + " "
    process_cmd = process_cmd + "-v created_at=\"$created_at\" "
    process_cmd = process_cmd + "-v progress_log=" + shell_escape(progress_log) + " "
    process_cmd = process_cmd + "-v resume_docs=\"$resume_docs\" "
    process_cmd = process_cmd + "-v start_shard=\"$start_shard\" "
    process_cmd = process_cmd + "-v start_in_shard=\"$start_in_shard\" "
    process_cmd = process_cmd + "-v start_last_shard=\"$start_last_shard\" "
    process_cmd = process_cmd + shell_escape(awk_program)
    process_cmd = process_cmd + "; mv " + shell_escape(manifest_file + ".tmp") + " " + shell_escape(manifest_file)
    process_cmd = process_cmd + "; printf 'ok\\n' > " + shell_escape(completion_file + ".tmp") + "; mv " + shell_escape(completion_file + ".tmp") + " " + shell_escape(completion_file)
    println("[shard] launching Wikipedia shard pipeline")
    runtime_run_command_output(process_cmd)
    if !runtime_file_exists(manifest_file) || !runtime_file_exists(completion_file) {
        println("Error: shard generation command failed")
        return 1
    }
    println("")
    println("[+] Wikipedia sharding complete")
    println("[+] manifest : " + manifest_file)
    println("")
    0
}
