package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: quick_data_acquisition")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models data-pipeline-s"
    if !runtime_run_command(command).ok {
        println("error: quick_data_acquisition failed")
        return 1
    }
    0
}
