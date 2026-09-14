package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: train_with_data")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-training-s"
    if !runtime_run_command(command).ok {
        println("error: train_with_data failed")
        return 1
    }
    0
}
