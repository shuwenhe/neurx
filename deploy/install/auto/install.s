package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    string os_base = runtime_env_get("NEURX_AUTO_OS_BASE", "linux")
    println("NeurX Auto install (S)")
    println("OS base: " + os_base)
    println("This migration keeps the installer as an S entrypoint and avoids destructive actions by default.")
    0
}
