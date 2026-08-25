package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: batch_standardize")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models data-pipeline-s"
    if !runtime_run_command(command).ok {
        println("error: batch_standardize failed")
        return 1
    }
    0
}
