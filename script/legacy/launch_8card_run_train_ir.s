package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: launch_8card_run_train_ir")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-train-model-ir-s"
    if !runtime_run_command(command).ok {
        println("error: launch_8card_run_train_ir failed")
        return 1
    }
    0
}
