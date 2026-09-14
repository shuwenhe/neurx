package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: EXECUTION_PIPELINE")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models complete-training-cycle-s"
    if !runtime_run_command(command).ok {
        println("error: EXECUTION_PIPELINE failed")
        return 1
    }
    0
}
