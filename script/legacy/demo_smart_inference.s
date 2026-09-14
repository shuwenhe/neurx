package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: demo_smart_inference")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models test-smart-inference-s"
    if !runtime_run_command(command).ok {
        println("error: demo_smart_inference failed")
        return 1
    }
    0
}
