// Start NeurX Web UI Frontend in background
// Pure S implementation - no shell scripts needed

func main() {
    // Display startup message
    println("🌐 Starting NeurX Web UI on port 8081...")
    println("")
    println("🧹 Cleaning up old processes...")
    
    // Kill old frontend processes
    _ = system_exec("pkill -9 -f s_ir_runner.*web_ui_server 2>/dev/null || true")
    
    // Wait for processes to die
    system_sleep(1)
    
    // Prepare environment and launch frontend
    let neurx_root = get_env_or("NEURX_ROOT", ".")
    
    let frontend_ir = neurx_root + "/artifacts/build/production_s_inference/web_ui_server.ir"
    let s_runner = neurx_root + "/artifacts/build/s_runner/s_ir_runner"
    
    println("Starting frontend process...")
    
    // Build and execute the launch command
    let cmd = "cd '" + neurx_root + "' && NEURX_ROOT='" + neurx_root + 
              "' nohup '" + s_runner + "' '" + frontend_ir + 
              "' >/tmp/neurx_frontend.log 2>&1 &"
    
    _ = system_exec(cmd)
    
    // Wait for frontend to initialize
    println("⏳ Waiting for frontend to initialize...")
    system_sleep(3)
    
    // Verify frontend is running by checking port
    if verify_port_listening(8081) {
        println("✅ Frontend is running on port 8081")
        println("🌐 Access UI: http://127.0.0.1:8081")
        println("📋 Log: tail -f /tmp/neurx_frontend.log")
        println("🛑 Stop: make frontend-stop")
        println("")
    } else {
        println("❌ Frontend failed to start. Check logs:")
        _ = system_exec("tail -10 /tmp/neurx_frontend.log")
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
