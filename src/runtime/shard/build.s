package main
use std.os.{command, getenv}
func string_char(int c) string {
    string(c)
}
func shell_escape(string s) string {
    string out = "'"
    int i = 0
    for i < len(s) {
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
func compile_one(string compiler, string script_dir, string build_dir, string shard_file) bool {
    string input_path = script_dir + "/" + shard_file
    string output_name = shard_file
    int dot = len(output_name)
    int i = 0
    for i < len(output_name) {
        if string_char(output_name[i]) == "." {
            dot = i
            break
        }
        i = i + 1
    }
    string base_name = ""
    i = 0
    for i < dot {
        base_name = base_name + string_char(output_name[i])
        i = i + 1
    }
    string output_path = build_dir + "/" + base_name + ".ir"
    string cmd = compiler + " ir " + shell_escape(input_path) + " -o " + shell_escape(output_path)
    (_, code) := command(cmd)
    if code == 0 {
        println("✓ " + shard_file + " . " + output_path)
        return true
    }
    println("✗ Failed: " + shard_file)
    false
}
func main() {
    string script_dir = getenv("SHARD_SCRIPT_DIR", ".")
    string build_dir = getenv("SHARD_BUILD_DIR", "../artifact/build/shard")
    string compiler = getenv("S_COMPILER", "/home/shuwen/s/bin/s")
    println("Build directory: " + build_dir)
    println("Compiler: " + compiler)
    println("")
    (_, compiler_code) := command("test -x " + shell_escape(compiler))
    if compiler_code != 0 {
        println("Error: S compiler not found: " + compiler)
        return 1
    }
    (_, mkdir_code) := command("mkdir -p " + shell_escape(build_dir))
    if mkdir_code != 0 {
        println("Error: Failed to create build directory")
        return 1
    }
    if !compile_one(compiler, script_dir, build_dir, "shard.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "shard_wikipedia_simple.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "shard_wikipedia.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "load_shards.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "generate_shards.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "data_shard.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "shard_enwiki.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "verify_shards.s") { return 1 }
    if !compile_one(compiler, script_dir, build_dir, "test_shard.s") { return 1 }
    println("")
    println("All shard files compiled successfully")
    0
}
