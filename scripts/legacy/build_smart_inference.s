package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string s_compiler = runtime_env_get("S_COMPILER", runtime_env_get("COMPILER_BIN", "/Users/feifei/shuwen/train/s/.local/bin/s"))
    string source_file = runtime_env_get("NEURX_SMART_INFERENCE_SOURCE", project_root + "/s/smart_inference.s")
    string build_dir = runtime_env_get("NEURX_SMART_INFERENCE_BUILD_DIR", project_root + "/build")
    string ir_file = build_dir + "/smart_inference.ir"
    string bin_file = build_dir + "/smart_inference.bin"
    println("NeurX Smart Inference Build entry (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("S compiler   : " + s_compiler)
    println("Source file  : " + source_file)
    println("IR output    : " + ir_file)
    println("Binary output: " + bin_file)
    println("")
    if !runtime_file_exists(s_compiler) && !runtime_file_exists(runtime_env_get("S_BIN", "")) {
        println("Error: S compiler not found")
        return 1
    }
    if !runtime_file_exists(source_file) {
        println("Error: source file not found")
        return 1
    }
    runtime_make_dirs(build_dir)
    string compile_ir = "cd " + runtime_shell_escape(project_root) + " && " + runtime_shell_escape(s_compiler) + " " + runtime_shell_escape(source_file) + " " + runtime_shell_escape(ir_file)
    if !runtime_run_command(compile_ir).ok {
        return 1
    }
    string emit_bin = "cd " + runtime_shell_escape(project_root) + "/../s && " + runtime_shell_escape(s_compiler) + " --emit-bin " + runtime_shell_escape(ir_file) + " " + runtime_shell_escape(bin_file)
    if !runtime_run_command(emit_bin).ok {
        return 1
    }
    runtime_run_command("chmod +x " + runtime_shell_escape(bin_file))
    println("")
    println("Smart inference build complete")
    0
}
