package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: run_inference_s")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-inference-s"
    if !runtime_run_command(command).ok {
        println("error: run_inference_s failed")
        return 1
    }
    0
}
