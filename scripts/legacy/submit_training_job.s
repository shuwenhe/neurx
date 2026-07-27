package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() int {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: submit_training_job")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f configs/Makefile.large_models cluster-launch-s"
    if !runtime_run_command(command).ok {
        println("error: submit_training_job failed")
        return 1
    }
    0
}
