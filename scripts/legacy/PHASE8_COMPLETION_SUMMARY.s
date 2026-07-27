package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() int {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: PHASE8_COMPLETION_SUMMARY")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f configs/Makefile.large_models toolchain-s"
    if !runtime_run_command(command).ok {
        println("error: PHASE8_COMPLETION_SUMMARY failed")
        return 1
    }
    0
}
