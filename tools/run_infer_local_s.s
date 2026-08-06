package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string s_root = runtime_env_get("S_ROOT", project_root + "/../s")
    string s_compiler = runtime_env_get("S_COMPILER", s_root + "/.local/bin/s")
    string source_file = runtime_env_get("NEURX_INFER_SOURCE", project_root + "/tools/infer_llm_checkpoint.s")
    string build_dir = runtime_env_get("NEURX_INFER_BUILD_DIR", project_root + "/build")
    string ir_file = build_dir + "/infer_llm.ir"
    string runner_bin = runtime_env_get("NEURX_INFER_RUNNER_BIN", project_root + "/artifacts/build/s_runner/s_ir_runner")
    println("Building local S inference runner")
    println("  project root : " + project_root)
    println("  S root       : " + s_root)
    println("  compiler bin : " + s_compiler)
    println("  source file  : " + source_file)
    println("  IR output    : " + ir_file)
    println("  runner bin   : " + runner_bin)
    println("")
    if !runtime_file_exists(source_file) {
        println("Error: source file not found")
        return 1
    }
    if !runtime_file_exists(s_compiler) {
        println("Error: S compiler not found")
        return 1
    }
    runtime_make_dirs(build_dir)
    string compile_cmd = "cd " + runtime_shell_escape(project_root) + " && " + runtime_shell_escape(s_compiler) + " ir " + runtime_shell_escape(source_file) + " -o " + runtime_shell_escape(ir_file)
    if !runtime_run_command(compile_cmd).ok {
        return 1
    }
    string ensure_runner = "cd " + runtime_shell_escape(project_root) + " && make build-s-ir-runner"
    if !runtime_file_exists(runner_bin) {
        if !runtime_run_command(ensure_runner).ok {
            return 1
        }
    }
    println("Running S inference runner")
    println("  exec         : S_IR_RUNNER_INPUT=\"" + ir_file + "\" S_IR_RUNNER_ENTRY=main \"" + runner_bin + "\"")
    if !runtime_run_command("S_IR_RUNNER_INPUT=" + runtime_shell_escape(ir_file) + " S_IR_RUNNER_ENTRY=main " + runtime_shell_escape(runner_bin)).ok {
        return 1
    }
    0
}
