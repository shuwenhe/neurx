package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: demo_complete_pipeline")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f Makefile.large_models complete-training-cycle-s"
    if !runtime_run_command(command).ok {
        println("error: demo_complete_pipeline failed")
        return 1
    }
    0
}
