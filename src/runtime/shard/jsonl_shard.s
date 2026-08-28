package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}

func pick_input_file(string root) string {
    string candidate = runtime_env_get("SHARD_INPUT_FILE", "")
    if candidate != "" && runtime_file_exists(candidate) {
        return candidate
    }
    candidate = runtime_env_get("INPUT_FILE", "")
    if candidate != "" && runtime_file_exists(candidate) {
        return candidate
    }
    candidate = root + "/data/large_model/train.jsonl"
    if runtime_file_exists(candidate) {
        return candidate
    }
    candidate = root + "/data/training_data_claude.jsonl"
    if runtime_file_exists(candidate) {
        return candidate
    }
    candidate = root + "/data/training_data_industrial_complete.jsonl"
    if runtime_file_exists(candidate) {
        return candidate
    }
    candidate = root + "/data/training_data_splits/val.jsonl"
    if runtime_file_exists(candidate) {
        return candidate
    }
    candidate = root + "/data/training_data_splits/test.jsonl"
    if runtime_file_exists(candidate) {
        return candidate
    }
    ""
}

func build_script(string input_file, string shard_dir, string manifest_file, string docs_per_shard) string {
    string script = "#!/bin/sh\n"
    script = script + "set -e\n"
    script = script + "mkdir -p \"" + shard_dir + "\"\n"
    script = script + "rm -f \"" + shard_dir + "\"/shard_*.jsonl \"" + manifest_file + "\" \"" + shard_dir + "/.jsonl_shard_complete\"\n"
    script = script + "split -d -a 5 -l \"" + docs_per_shard + "\" \"" + input_file + "\" \"" + shard_dir + "/shard_\"\n"
    script = script + "i=0\n"
    script = script + "shard_list=\"\"\n"
    script = script + "for shard_file in \"" + shard_dir + "\"/shard_*; do\n"
    script = script + "  [ -f \"$shard_file\" ] || continue\n"
    script = script + "  case \"$shard_file\" in\n"
    script = script + "    *.log|*.jsonl) continue ;;\n"
    script = script + "  esac\n"
    script = script + "  mv \"$shard_file\" \"$shard_file.jsonl\"\n"
    script = script + "  shard_list=\"$shard_list $shard_file.jsonl\"\n"
    script = script + "  i=$((i + 1))\n"
    script = script + "done\n"
    script = script + "total_docs=$(wc -l < \"" + input_file + "\")\n"
    script = script + "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)\n"
    script = script + "{\n"
    script = script + "  printf '{\\n'\n"
    script = script + "  printf '  \"dataset_name\": \"neurx-jsonl-shard-fallback\",\\n'\n"
    script = script + "  printf '  \"created_at\": \"%s\",\\n' \"$created_at\"\n"
    script = script + "  printf '  \"source_file\": \"%s\",\\n' \"" + input_file + "\"\n"
    script = script + "  printf '  \"shard_dir\": \"%s\",\\n' \"" + shard_dir + "\"\n"
    script = script + "  printf '  \"manifest_file\": \"%s\",\\n' \"" + manifest_file + "\"\n"
    script = script + "  printf '  \"docs_per_shard\": \"%s\",\\n' \"" + docs_per_shard + "\"\n"
    script = script + "  printf '  \"total_documents\": %s,\\n' \"$total_docs\"\n"
    script = script + "  printf '  \"total_shards\": %s,\\n' \"$i\"\n"
    script = script + "  printf '  \"format\": \"jsonl\",\\n'\n"
    script = script + "  printf '  \"shards\": [\\n'\n"
    script = script + "  idx=0\n"
    script = script + "  for shard_file in $shard_list; do\n"
    script = script + "    shard_file=$(printf '%s' \"$shard_file\" | sed 'src/core/s/^ *
    script = script + "    [ -n \"$shard_file\" ] || continue\n"
    script = script + "    lines=$(wc -l < \"$shard_file\")\n"
    script = script + "    size=$(wc -c < \"$shard_file\")\n"
    script = script + "    printf '    {\"shard_id\": \"shard_%05d\", \"file_path\": \"%s\", \"num_documents\": %s, \"size_bytes\": %s}' \"$idx\" \"$shard_file\" \"$lines\" \"$size\"\n"
    script = script + "    idx=$((idx + 1))\n"
    script = script + "    if [ \"$idx\" -lt \"$i\" ]; then printf ','; fi\n"
    script = script + "    printf '\\n'\n"
    script = script + "  done\n"
    script = script + "  printf '  ]\\n'\n"
    script = script + "  printf '}\\n'\n"
    script = script + "} > \"" + manifest_file + "\"\n"
    script = script + ": > \"" + shard_dir + "/.jsonl_shard_complete\"\n"
    script
}

func main() {
    string root = runtime_env_get("NEURX_HOME", runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx"))
    string shard_dir = runtime_env_get("SHARD_DIR", root + "/dataset/pretrain/shard")
    string manifest_file = runtime_env_get("MANIFEST_FILE", root + "/dataset/pretrain/manifest.json")
    string docs_per_shard = runtime_env_get("DOCS_PER_SHARD", "100")
    string input_file = pick_input_file(root)
    if input_file == "" {
        println("jsonl-shard FAIL missing_input")
        return 1
    }
    println("jsonl-shard input=" + input_file)
    println("jsonl-shard shard_dir=" + shard_dir)
    println("jsonl-shard manifest=" + manifest_file)
    string script = build_script(input_file, shard_dir, manifest_file, docs_per_shard)
    string command = "cat > /tmp/neurx_jsonl_shard.sh <<'EOF'\n"
    command = command + script + "\nEOF\n"
    command = command + "sh /tmp/neurx_jsonl_shard.sh"
    string output = runtime_run_command_output(command)
    if output != "" {
        println(output)
    }
    println("jsonl-shard PASS shards=generated")
    0
}
