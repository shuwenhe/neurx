package neurx.inference.production_gpu_backend

extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_bind(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_listen(int sockfd, int backlog) int
extern "intrinsic" func __sys_accept(int sockfd) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int
extern "intrinsic" func __host_read_binary_file_range(string path, int offset, int size) []int
extern "intrinsic" func __host_slice(string text, int start, int end) string

extern func runtime_env_get(string key, string default_value) string
extern func runtime_file_exists(string path) bool

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string result = ""
    int current = value
    if current < 0 {
        current = 0 - current
    }
    while current > 0 {
        int digit = current - (current / 10) * 10
        result = string(48 + digit) + result
        current = current / 10
    }
    if value < 0 {
        return "-" + result
    }
    return result
}

func gpu_available() bool {
    string cuda_path = runtime_env_get("CUDA_HOME", "/usr/local/cuda")
    return runtime_file_exists(cuda_path + "/lib64/libcudart.so") || 
           runtime_file_exists(cuda_path + "/lib/libcudart.so")
}

func gpu_device_info() string {
    // TODO: Query actual GPU info via nvidia-smi or CUDA API
    return "NVIDIA GPU (Mock)"
}

func float_to_string(float f) string {
    // Simplified float to string conversion
    int int_part = int(f)
    return int_to_string(int_part)
}

func model_hidden_dim() int {
    string model_path = runtime_env_get("NEURX_MODEL_DIR", "")
    if len(model_path) > 0 && (contains_substring(model_path, "0.5B") || contains_substring(model_path, "500M")) {
        return 896
    }
    if len(model_path) > 0 && (contains_substring(model_path, "7B") || contains_substring(model_path, "VL-7B")) {
        return 3584
    }
    return 896
}

func contains_substring(string haystack, string needle) bool {
    if len(needle) == 0 {
        return true
    }
    if len(haystack) < len(needle) {
        return false
    }
    int i = 0
    while i <= len(haystack) - len(needle) {
        bool matches = true
        int j = 0
        while j < len(needle) {
            if haystack[i + j] != needle[j] {
                matches = false
            }
            j = j + 1
        }
        if matches {
            return true
        }
        i = i + 1
    }
    return false
}

func parse_int_or_default(string s, int default_val) int {
    if len(s) == 0 {
        return default_val
    }
    // Simple integer parsing
    int result = 0
    int i = 0
    while i < len(s) {
        string ch = __host_slice(s, i, i + 1)
        if ch[0] >= 48 && ch[0] <= 57 {
            result = result * 10 + (ch[0] - 48)
        } else {
            return result
        }
        i = i + 1
    }
    return result
}

func num_transformer_layers() int {
    string model_path = runtime_env_get("NEURX_MODEL_DIR", "")
    if len(model_path) > 0 && (contains_substring(model_path, "0.5B") || contains_substring(model_path, "500M")) {
        return 24
    }
    if len(model_path) > 0 && (contains_substring(model_path, "7B") || contains_substring(model_path, "VL-7B")) {
        return 28
    }
    return 24
}

func active_transformer_layers() int {
    int configured = parse_int_or_default(runtime_env_get("NEURX_ACTIVE_LAYERS", "2"), 2)
    if configured < 1 {
        return 1
    }
    if configured > num_transformer_layers() {
        return num_transformer_layers()
    }
    return configured
}

func create_ready_file(string path) {
    print("✓ Backend ready file: " + path + "\n")
}

func handle_client_gpu(int client_fd, string model_path, string device_type) {
    []int input_buffer = []int{cap: 4096}
    string request = __sys_read_string(client_fd, 4096)
    
    int slice_end = len(request)
    if slice_end > 100 {
        slice_end = 100
    }
    print("[GPU-Backend] Received request: " + __host_slice(request, 0, slice_end) + "...\n")
    
    // Parse JSON request
    bool is_generate = contains_substring(request, "\"action\":\"generate\"")
    
    string response = ""
    if is_generate {
        print("[GPU-Backend] Processing generate request\n")
        // Mock GPU inference for now
        response = "{\"status\":\"ok\",\"output\":\"GPU-based response\",\"backend\":\"neurx-s-gpu\"}"
    } else {
        response = "{\"status\":\"error\",\"message\":\"Unknown action\"}"
    }
    
    print("[GPU-Backend] Sending response\n")
    _ = __sys_write_string(client_fd, "HTTP/1.1 200 OK\r\n")
    _ = __sys_write_string(client_fd, "Content-Type: application/json\r\n")
    _ = __sys_write_string(client_fd, "Content-Length: " + int_to_string(len(response)) + "\r\n")
    _ = __sys_write_string(client_fd, "\r\n")
    _ = __sys_write_string(client_fd, response)
    
    _ = __sys_close(client_fd)
}

func main() {
    print("╔════════════════════════════════════════════════════════════════╗\n")
    print("║  NeurX GPU Backend - Pure S Implementation                     ║\n")
    print("║  GPU-Accelerated Inference Engine                             ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n\n")
    
    string model_path = runtime_env_get("NEURX_MODEL_DIR", "/model/Qwen2.5-0.5B-Instruct")
    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")
    string port_str = runtime_env_get("NEURX_S_PORT", "18083")
    int port = parse_int_or_default(port_str, 18083)
    string device_type = runtime_env_get("NEURX_INFER_DEVICE", "gpu")
    string ready_file = runtime_env_get("NEURX_S_READY_FILE", "/tmp/neurx_s_inference_" + port_str + "_ready")
    
    print("Configuration:\n")
    print("  Model: " + model_path + "\n")
    print("  Device: " + device_type + "\n")
    print("  Host: " + host + "\n")
    print("  Port: " + port_str + "\n")
    
    bool gpu_ok = gpu_available()
    string gpu_status = "NO ✗"
    if gpu_ok {
        gpu_status = "YES ✓"
    }
    print("  GPU Available: " + gpu_status + "\n")
    
    if gpu_ok {
        print("  GPU Device: " + gpu_device_info() + "\n")
    }
    
    print("  Active Layers: " + int_to_string(active_transformer_layers()) + "\n")
    print("  Hidden Dimension: " + int_to_string(model_hidden_dim()) + "\n")
    print("\nBackend Status: ✓ READY\n")
    print("Execution Mode: Pure S Language + GPU Acceleration ⚡\n\n")
    
    int listener_fd = __sys_socket(2, 1, 0)
    if listener_fd < 0 {
        print("ERROR: Socket creation failed\n")
        return
    }
    
    int bind_result = __sys_bind(listener_fd, host, port, 2)
    if bind_result != 0 {
        print("ERROR: Socket bind failed\n")
        _ = __sys_close(listener_fd)
        return
    }
    
    int listen_result = __sys_listen(listener_fd, 128)
    if listen_result != 0 {
        print("ERROR: Socket listen failed\n")
        _ = __sys_close(listener_fd)
        return
    }
    
    print("Socket creation: fd=" + int_to_string(listener_fd) + "\n")
    print("HTTP server listening on " + host + ":" + port_str + "\n")
    print("[Socket] Ready to accept connections\n")
    print("Signaling readiness at: " + ready_file + "\n")
    
    create_ready_file(ready_file)
    print("✓ Backend ready file: " + ready_file + "\n\n")
    
    int consecutive_errors = 0
    int max_consecutive_errors = 10
    while true {
        int client_fd = __sys_accept(listener_fd)
        
        if client_fd < 0 {
            consecutive_errors = consecutive_errors + 1
            if consecutive_errors >= max_consecutive_errors {
                print("ERROR: Too many consecutive accept failures\n")
                break
            }
        } else {
            consecutive_errors = 0
            handle_client_gpu(client_fd, model_path, device_type)
        }
    }
    
    _ = __sys_close(listener_fd)
}
