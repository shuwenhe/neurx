package main
use neurx.runtime.io.{runtime_env_get}
use std.io.println
func main() {
    string device = runtime_env_get("NEURX_TABLET_DEVICE", "")
    println("NeurX Tablet install (S)")
    println("Device: " + device)
    println("Use the Android build and adb push workflow from this S entrypoint.")
    0
}
