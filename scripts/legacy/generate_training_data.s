package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: generate_training_data")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f Makefile.large_models data-pipeline-s"
    if !runtime_run_command(command).ok {
        println("error: generate_training_data failed")
        return 1
    }
    0
}
