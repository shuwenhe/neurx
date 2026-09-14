package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: chat")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-interactive-inference-s"
    if !runtime_run_command(command).ok {
        println("error: chat failed")
        return 1
    }
    0
}
