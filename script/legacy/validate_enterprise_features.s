package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: validate_enterprise_features")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models run-end-to-end-verification-s"
    if !runtime_run_command(command).ok {
        println("error: validate_enterprise_features failed")
        return 1
    }
    0
}
