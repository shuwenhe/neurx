package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}
use std.io.println

func main() {
    ir_path := runtime_env_get("S_IR_RUNNER_INPUT", "")
    entry := runtime_env_get("S_IR_RUNNER_ENTRY", "main")
    compiler := runtime_env_get("S_COMPILER", "s")
    compiler_cwd := runtime_env_get("S_COMPILER_EMIT_CWD", "")
    binary_path := ir_path + ".runner.bin"
    if ir_path == "" {
        println("usage: s_ir_runner <input.ir> [entry]")
        return 2
    }
    string compile_command = compiler + " --emit-bin " + ir_path + " " + binary_path
    if compiler_cwd != "" {
        compile_command = "cd " + compiler_cwd + " && S_SOURCE_ROOT=" + compiler_cwd + " " + compile_command
    }
    runtime_run_command_output(compile_command)
    if !runtime_file_exists(binary_path) {
        println("error: failed to build runner binary")
        return 1
    }
    string run_command =
        "S_IR_RUNNER_INPUT=" + ir_path +
        " S_IR_RUNNER_ENTRY=" + entry +
        " " + binary_path
    runtime_run_command_output(run_command)
    if !runtime_file_exists(binary_path) {
        println("error: failed to run runner binary")
        return 1
    }
    return 0
}
