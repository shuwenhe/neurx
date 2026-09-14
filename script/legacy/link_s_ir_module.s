package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    root := runtime_env_get("NEURX_ROOT", ".")
    println("NeurX S entry: link_s_ir_module")
    command := "make -C " + runtime_shell_escape(root) + " -f Makefile -f config/Makefile.large_models compile-all-components-s"
    if !runtime_run_command(command).ok {
        println("error: link_s_ir_module failed")
        return 1
    }
    0
}
