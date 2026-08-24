package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    let root = runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: LAUNCH_1T_TRAINING")
    let command = "MODEL_SIZE=1t NEURX_ALLOW_FULL_1T_LOCAL=1 make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-large-pretrain-s"
    if !runtime_run_command(command).ok {
        println("error: LAUNCH_1T_TRAINING failed")
        return 1
    }
    0
}
