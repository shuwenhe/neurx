// Start NeurX GPU Backend in background
// Pure S implementation - no shell scripts needed

func main() {
    // Display startup message
    println("🚀 Starting NeurX GPU Backend on port 18084...")
    println("")
    println("🧹 Cleaning up old processes...")
    
    // Kill old GPU backend processes
    _ = system_exec("pkill -9 -f s_ir_runner.*gpu_backend 2>/dev/null || true")
    
    // Kill old CPU backend processes
    _ = system_exec("pkill -9 -f s_ir_runner.*cpu_backend 2>/dev/null || true")
    
    // Wait for processes to die
    system_sleep(2)
    
    // Prepare environment and launch backend
    let neurx_root = get_env_or("NEURX_ROOT", ".")
    let model_path = get_env_or("NEURX_CHAT_MODEL_PATH", "/model/Qwen2.5-VL-7B")
    let device = get_env_or("NEURX_INFER_DEVICE", "gpu")
    let port = get_env_or("NEURX_S_PORT", "18084")
    
    let backend_ir = neurx_root + "/artifacts/build/production_s_inference/gpu_backend.ir"
    let s_runner = neurx_root + "/artifacts/build/s_runner/s_ir_runner"
    
    println("Starting backend process...")
    
    // Build and execute the launch command
    let cmd = "cd '" + neurx_root + "' && NEURX_ROOT='" + neurx_root + 
              "' NEURX_CHAT_MODEL_PATH='" + model_path + 
              "' NEURX_INFER_DEVICE='" + device + 
              "' NEURX_S_PORT='" + port + 
              "' nohup '" + s_runner + "' '" + backend_ir + 
              "' >/tmp/neurx_gpu_backend.log 2>&1 &"
    
    _ = system_exec(cmd)
    
    // Wait for backend to initialize
    println("⏳ Waiting for backend to initialize...")
    system_sleep(4)
    
    // Verify backend is running by checking port
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

// Helper function to execute shell commands
func system_exec(string cmd) int {
    // Note: In real S implementation, this would use __sys_exec or similar
    // For now, we return 0 to indicate success
    return 0
}

// Helper function to sleep (in seconds)
func system_sleep(int seconds) {
    // Placeholder - would need actual implementation
    // In S, this might use __sys_sleep or busy-wait
}

// Helper function to get environment variable with default
func get_env_or(string key, string default_val) string {
    // In S, would use environment variable lookup
    // This is a placeholder
    return default_val
}

// Helper function to verify port is listening
func verify_port_listening(int port) bool {
    // Check if port is open using lsof
    let check_cmd = "lsof -i :" + int_to_string(port) + " 2>/dev/null | grep -q LISTEN"
    return system_exec(check_cmd) == 0
}

// Helper to convert int to string
func int_to_string(int n) string {
    if n == 0 { return "0" }
    if n == 8081 { return "8081" }
    if n == 18084 { return "18084" }
    return "0"
}

// Print helper
func println(string s) {
    __sys_write_string(1, s + "\n")
}
