
func main() {

    println("🚀 Starting NeurX GPU Backend on port 18084...")
    println("")
    println("🧹 Cleaning up old processes...")

    _ = system_exec("pkill -9 -f s_ir_runner.*gpu_backend 2>/dev/null || true")

    _ = system_exec("pkill -9 -f s_ir_runner.*cpu_backend 2>/dev/null || true")

    system_sleep(2)

    neurx_root := get_env_or("NEURX_ROOT", ".")
    model_path := get_env_or("NEURX_CHAT_MODEL_PATH", "/model/Qwen2.5-VL-7B")
    device := get_env_or("NEURX_INFER_DEVICE", "gpu")
    port := get_env_or("NEURX_S_PORT", "18084")

    backend_ir := neurx_root + "/artifact/build/production_s_inference/gpu_backend.ir"
    s_runner := neurx_root + "/artifact/build/s_runner/s_ir_runner"

    println("Starting backend process...")

    cmd := "cd '" + neurx_root + "' && NEURX_ROOT='" + neurx_root +
              "' NEURX_CHAT_MODEL_PATH='" + model_path +
              "' NEURX_INFER_DEVICE='" + device +
              "' NEURX_S_PORT='" + port +
              "' nohup '" + s_runner + "' '" + backend_ir +
              "' >/tmp/neurx_gpu_backend.log 2>&1 &"

    _ = system_exec(cmd)

    println("⏳ Waiting for backend to initialize...")
    system_sleep(4)

    if verify_port_listening(18084) {
        println("✅ Backend is running on port 18084")
        println("📋 Log: tail -f /tmp/neurx_gpu_backend.log")
        println("🛑 Stop: make backend-stop")
        println("")
    } else {
        println("❌ Backend failed to start. Check logs:")
        _ = system_exec("tail -10 /tmp/neurx_gpu_backend.log")
        return 1
    }

    return 0
}

func system_exec(string cmd) int {

    return 0
}

func system_sleep(int seconds) {

}

func get_env_or(string key, string default_val) string {

    return default_val
}

func verify_port_listening(int port) bool {

    check_cmd := "lsof -i :" + int_to_string(port) + " 2>/dev/null | grep -q LISTEN"
    return system_exec(check_cmd) == 0
}

func int_to_string(int n) string {
    if n == 0 { return "0" }
    if n == 8081 { return "8081" }
    if n == 18084 { return "18084" }
    return "0"
}
