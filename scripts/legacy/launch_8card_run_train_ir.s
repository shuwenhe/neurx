package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: launch_8card_run_train_ir")
    let command = "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-train-model-ir-s"
    if !runtime_run_command(command).ok {
        println("error: launch_8card_run_train_ir failed")
        return 1
    }
    0
}
