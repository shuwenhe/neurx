package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape, trim}
use std.io.println

func main() {
    string device = runtime_env_get("NEURX_ANDROID_DEVICE", "")
    bool apk_only = runtime_env_get("NEURX_ANDROID_APK_ONLY", "0") == "1"
    println("NeurX Mobile Install (Android) - S")
    println("Device: " + device)
    println("APK only: " + bool_text(apk_only))
    println("Use adb and the Android build targets directly from this S entrypoint.")
    0
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}

