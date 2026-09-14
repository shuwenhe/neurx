package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: compile_training_integration")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models integration-s"
    if !runtime_run_command(command).ok {
        println("error: compile_training_integration failed")
        return 1
    }
    0
}
