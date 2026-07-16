package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: test_file_creation")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f Makefile.large_models diagnose-file-creation-s"
    if !runtime_run_command(command).ok {
        println("error: test_file_creation failed")
        return 1
    }
    0
}
