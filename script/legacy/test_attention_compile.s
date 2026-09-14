package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: test_attention_compile")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models test-build-s"
    if !runtime_run_command(command).ok {
        println("error: test_attention_compile failed")
        return 1
    }
    0
}
