// ============================================================================
// NeurX Shard Manager
//
// S implementation of the unified shard CLI.
// The shell wrapper only translates argv into environment variables.
// ============================================================================

package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}

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

func parse_int(string s, int fallback) int {
    string text = trim(s)
    if len(text) == 0 {
        return fallback
    }

    int sign = 1
    int i = 0
    if string_char(text[0]) == "-" {
        sign = -1
        i = 1
    } else if string_char(text[0]) == "+" {
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

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }

    int value = n
    bool negative = n < 0
    if negative {
        value = 0 - value
    }

    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        out = string_char(digit + 48) + out
        value = value / 10
    }

    if negative {
        out = "-" + out
    }

    out
}

func print_help() {
    println("NeurX Shard Manager")
    println("")
    println("Commands:")
    println("  wikipedia    Shard Wikipedia dump (ENWIKI)")
    println("  verify       Verify shard integrity")
    println("  list         List available shards")
    println("  clean        Clean up shard files")
    println("  help         Show this help message")
}

func env_get(string name, string default_value) string {
    runtime_env_get(name, default_value)
}

func default_neurx_root() string {
    env_get("NEURX_HOME", ".")
}

func default_shard_dir(string root) string {
    env_get("ENWIKI_SHARD_DIR", root + "/dataset/pretrain/shard")
}

func default_manifest(string root) string {
    env_get("ENWIKI_MANIFEST_FILE", root + "/dataset/pretrain/manifest.json")
}

func run_wikipedia() int {
    string root = default_neurx_root()
    string script_dir = env_get("NEURX_SHARD_SCRIPT_DIR", root + "/shard")
    string build_dir = root + "/artifacts/build/shard"
    string runner_bin = root + "/artifacts/build/s_runner/s_ir_runner"
    string compiler = env_get("S_COMPILER", "/home/shuwen/s/bin/s")

    string input = env_get("ENWIKI_BZ2_FILE", root + "/dataset/pretrain/raw/enwiki-latest-pages-articles.xml.bz2")
    string output_dir = env_get("ENWIKI_SHARD_DIR", root + "/dataset/pretrain/shard")
    string manifest = env_get("ENWIKI_MANIFEST_FILE", root + "/dataset/pretrain/manifest.json")
    string docs_per_shard = env_get("DOCS_PER_SHARD", "5000")
    string max_pages = env_get("MAX_PAGES", "0")

    if !runtime_file_exists(input) {
        println("Error: input file not found: " + input)
        return 1
    }

    string mkdir_output = runtime_run_command_output("mkdir -p " + shell_escape(build_dir))
    if len(trim(mkdir_output)) > 0 {
        println(mkdir_output)
    }

    string compile_output = runtime_run_command_output(
        shell_escape(compiler) + " " + shell_escape(script_dir + "/shard_wikipedia_simple.s") + " " + shell_escape(build_dir + "/shard_wikipedia_simple.ir")
    )
    if !runtime_file_exists(build_dir + "/shard_wikipedia_simple.ir") {
        println("Error: failed to compile shard_wikipedia_simple.s")
        return 1
    }

    if !runtime_file_exists(runner_bin) {
        string runner_output = runtime_run_command_output("make -C " + shell_escape(root) + " build-s-ir-runner")
        if !runtime_file_exists(runner_bin) {
            println("Error: failed to build S IR runner")
            return 1
        }
    }

    string run_command = 
        "NEURX_HOME=" + shell_escape(root) +
        " S_COMPILER=" + shell_escape(compiler) +
        " S_COMPILER_EMIT_CWD=" + shell_escape(env_get("S_COMPILER_EMIT_CWD", root + "/../s")) +
        " S_SOURCE_ROOT=" + shell_escape(env_get("S_COMPILER_EMIT_CWD", root + "/../s")) +
        " ENWIKI_BZ2_FILE=" + shell_escape(input) +
        " ENWIKI_SHARD_DIR=" + shell_escape(output_dir) +
        " ENWIKI_MANIFEST_FILE=" + shell_escape(manifest) +
        " DOCS_PER_SHARD=" + shell_escape(docs_per_shard) +
        " MAX_PAGES=" + shell_escape(max_pages) +
        " S_IR_RUNNER_INPUT=" + shell_escape(build_dir + "/shard_wikipedia_simple.ir") +
        " S_IR_RUNNER_ENTRY=" + shell_escape("main") +
        " " + shell_escape(runner_bin)
    println("[shard] launching runner for compiled shard IR")
    runtime_run_command_output(run_command)
    if !runtime_file_exists(manifest) {
        println("Error: shard wikipedia execution failed")
        return 1
    }

    0
}

func run_verify() int {
    string root = default_neurx_root()
    string shard_dir = default_shard_dir(root)
    if !runtime_file_exists(shard_dir) {
        println("Shard directory not found: " + shard_dir)
        return 1
    }

    string verify_cmd = "for shard_file in " + shell_escape(shard_dir) + "/shard_*.jsonl; do " +
        "if [ ! -f \"$shard_file\" ]; then continue; fi; " +
        "line_count=$(wc -l < \"$shard_file\"); " +
        "if tail -n 5 \"$shard_file\" | python3 -c 'import sys, json; [json.loads(line) for line in sys.stdin]' 2>/dev/null; then " +
        "echo \"$(basename \"$shard_file\"): ${line_count} documents\"; " +
        "else echo \"$(basename \"$shard_file\"): Invalid JSON detected\"; exit 1; fi; done"
    string verify_output = runtime_run_command_output("sh -c " + shell_escape(verify_cmd))
    if len(trim(verify_output)) > 0 {
        println(verify_output)
    }
    0
}

func run_list() int {
    string root = default_neurx_root()
    string shard_dir = default_shard_dir(root)
    if !runtime_file_exists(shard_dir) {
        println("Shard directory not found: " + shard_dir)
        return 1
    }

    string list_cmd = "sh -c " +
        shell_escape("printf '%-30s %10s %15s\n' 'Shard File' 'Lines' 'Size (MB)'; printf '%-30s %10s %15s\n' '--------------------' '----------' '---------------'; total_size=0; total_lines=0; for shard_file in " + shell_escape(shard_dir) + "/shard_*.jsonl; do [ -f \"$shard_file\" ] || continue; filename=$(basename \"$shard_file\"); line_count=$(wc -l < \"$shard_file\"); file_size=$((($(stat -c%s \"$shard_file\" 2>/dev/null || stat -f%z \"$shard_file\") / 1024 / 1024))); printf '%-30s %10d %15d\n' \"$filename\" \"$line_count\" \"$file_size\"; total_size=$((total_size + file_size)); total_lines=$((total_lines + line_count)); done; printf '%-30s %10d %15d\n' 'TOTAL' \"$total_lines\" \"$total_size\"")
    string list_output = runtime_run_command_output(list_cmd)
    if len(trim(list_output)) > 0 {
        println(list_output)
    }
    0
}

func run_clean() int {
    string root = default_neurx_root()
    string shard_dir = default_shard_dir(root)
    if !runtime_file_exists(shard_dir) {
        println("Shard directory not found: " + shard_dir)
        return 1
    }

    string clean_output = runtime_run_command_output("sh -c " + shell_escape("rm -f " + shell_escape(shard_dir) + "/shard_*.jsonl"))
    if len(trim(clean_output)) > 0 {
        println(clean_output)
    }
    0
}

func main() int {
    string cmd = env_get("NEURX_SHARD_CMD", "help")
    if cmd == "wikipedia" || cmd == "shard" {
        return run_wikipedia()
    }
    if cmd == "verify" {
        return run_verify()
    }
    if cmd == "list" {
        return run_list()
    }
    if cmd == "clean" {
        return run_clean()
    }
    print_help()
    0
}
