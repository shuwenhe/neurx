package main

use neurx.runtime.io.{runtime_env_get}
use std.io.println

func main() int {
    string device_udid = runtime_env_get("NEURX_IOS_DEVICE_UDID", "")
    bool use_sim = runtime_env_get("NEURX_IOS_USE_SIM", "0") == "1"
    println("NeurX Mobile Install (iOS) - S")
    println("Simulator: " + bool_text(use_sim))
    println("Device: " + device_udid)
    0
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}
