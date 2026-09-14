package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: MIGRATION_COMPLETE")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models toolchain-s"
    if !runtime_run_command(command).ok {
        println("error: MIGRATION_COMPLETE failed")
        return 1
    }
    0
}
