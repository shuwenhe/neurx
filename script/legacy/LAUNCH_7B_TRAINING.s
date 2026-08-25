package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: LAUNCH_7B_TRAINING")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models train-large"
    if !runtime_run_command(command).ok {
        println("error: LAUNCH_7B_TRAINING failed")
        return 1
    }
    0
}
