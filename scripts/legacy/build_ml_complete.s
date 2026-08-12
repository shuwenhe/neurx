package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: build_ml_complete")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f configs/Makefile.large_models compile-all-components-s"
    if !runtime_run_command(command).ok {
        println("error: build_ml_complete failed")
        return 1
    }
    0
}
