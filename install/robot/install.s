package main
use neurx.runtime.io.{runtime_env_get}
use std.io.println

func main() {
    string platform = runtime_env_get("NEURX_ROBOT_PLATFORM", "jetson_orin")
    bool sim_mode = runtime_env_get("NEURX_ROBOT_SIM", "0") == "1"
    println("NeurX Robot install (S)")
    println("Platform: " + platform)
    println("Sim mode: " + bool_text(sim_mode))
    println("This S entrypoint replaces the old shell installer.")
    0
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}
