package neurx.deployment.cluster_orchestration
use neurx.runtime.command.{runtime_env_get}
use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_socket(int domain, int type, int protocol) int
extern "intrinsic" func __sys_connect(int sockfd, string ip, int port, int family) int
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_write_string(int fd, string data) int
extern "intrinsic" func __sys_close(int fd) int

struct cluster_node_spec {
    int node_id
    string node_name
    string ip_address
    int gpu_count
    string gpu_type
    int cpu_cores
    int memory_gb
    string status
    float utilization
}

struct cluster_deployment_spec {
    string deployment_name
    string cluster_name
    string backend
    string image_name
    string master_addr
    int master_port
    int replica_count
    int world_size
    int data_parallel_size
    int tensor_parallel_size
    int pipeline_parallel_size
    string checkpoint_dir
    string data_dir
    string output_dir
}

struct cluster_orchestration_state {
    string cluster_name
    string deployment_dir
    string backend
    string discovery_source
    []cluster_node_spec nodes
    int healthy_nodes
    int total_gpus
    bool ready
    string last_summary
    string last_manifest_path
}

func new_cluster_node_spec(int node_id, string node_name, string ip_address, int gpu_count, string gpu_type, int cpu_cores, int memory_gb, string status, float utilization) cluster_node_spec {
    cluster_node_spec {
        node_id: node_id,
        node_name: node_name,
        ip_address: ip_address,
        gpu_count: gpu_count,
        gpu_type: gpu_type,
        cpu_cores: cpu_cores,
        memory_gb: memory_gb,
        status: status,
        utilization: utilization,
    }
}

func new_cluster_deployment_spec(string cluster_name, string image_name, string backend, string master_addr, int master_port, int replica_count, int world_size, string checkpoint_dir, string data_dir, string output_dir) cluster_deployment_spec {
    cluster_deployment_spec {
        deployment_name: cluster_name + "-llm-train",
        cluster_name: cluster_name,
        backend: backend,
        image_name: image_name,
        master_addr: master_addr,
        master_port: master_port,
        replica_count: replica_count,
        world_size: world_size,
        data_parallel_size: world_size,
        tensor_parallel_size: 1,
        pipeline_parallel_size: 1,
        checkpoint_dir: checkpoint_dir,
        data_dir: data_dir,
        output_dir: output_dir,
    }
}

func new_cluster_orchestration_state(string cluster_name, string deployment_dir, string backend) cluster_orchestration_state {
    cluster_orchestration_state {
        cluster_name: cluster_name,
        deployment_dir: deployment_dir,
        backend: backend,
        discovery_source: "",
        nodes: make([]cluster_node_spec, 0),
        healthy_nodes: 0,
        total_gpus: 0,
        ready: false,
        last_summary: "",
        last_manifest_path: "",
    }
}

func cluster_add_node(cluster_orchestration_state state, cluster_node_spec node) cluster_orchestration_state {
    cluster_orchestration_state next = state
    next.nodes = append(next.nodes, node)
    next.total_gpus = next.total_gpus + node.gpu_count
    if node.status == "healthy" {
        next.healthy_nodes = next.healthy_nodes + 1
    }
    next
}

func cluster_trim(string s) string {
    int left = 0
    for left < len(s) && (s[left] == 32 || s[left] == 9 || s[left] == 10 || s[left] == 13) {
        left = left + 1
    }
    int right = len(s) - 1
    for right >= left && (s[right] == 32 || s[right] == 9 || s[right] == 10 || s[right] == 13) {
        right = right - 1
    }
    if right < left {
        return ""
    }
    string out = ""
    int i = left
    for i <= right {
        out = out + chr(s[i])
        i = i + 1
    }
    out
}

func cluster_split_lines(string text) []string {
    string[] lines = []string{}
    string current = ""
    int i = 0
    for i < len(text) {
        if text[i] == 10 || text[i] == 13 {
            if len(current) > 0 {
                lines = append(lines, current)
                current = ""
            }
        } else {
            current = current + chr(text[i])
        }
        i = i + 1
    }
    if len(current) > 0 {
        lines = append(lines, current)
    }
    lines
}

func cluster_find_substring(string text, string pattern) int {
    if len(pattern) == 0 {
        return 0
    }
    int i = 0
    for i + len(pattern) <= len(text) {
        int j = 0
        for j < len(pattern) && text[i + j] == pattern[j] {
            j = j + 1
        }
        if j == len(pattern) {
            return i
        }
        i = i + 1
    }
    -1
}

func cluster_parse_int(string text, int fallback) int {
    string s = cluster_trim(text)
    if s == "" {
        return fallback
    }
    int sign = 1
    int i = 0
    if s[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    for i < len(s) {
        int digit = s[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func cluster_parse_float(string text, float fallback) float {
    string s = cluster_trim(text)
    if s == "" {
        return fallback
    }
    bool neg = false
    int i = 0
    if s[0] == 45 {
        neg = true
        i = 1
    }
    float whole = 0.0
    for i < len(s) && s[i] >= 48 && s[i] <= 57 {
        whole = whole * 10.0 + (s[i] - 48) * 1.0
        i = i + 1
    }
    float frac = 0.0
    float div = 1.0
    if i < len(s) && s[i] == 46 {
        i = i + 1
        for i < len(s) && s[i] >= 48 && s[i] <= 57 {
            frac = frac * 10.0 + (s[i] - 48) * 1.0
            div = div * 10.0
            i = i + 1
        }
    }
    float value = whole + frac / div
    if neg {
        value = -value
    }
    value
}

func cluster_parse_node_record(string line) cluster_node_spec {
    string[] parts = make([]string, 8)
    string current = ""
    int i = 0
    for i < len(line) {
        if line[i] == 124 {
            parts = append(parts, cluster_trim(current))
            current = ""
        } else {
            current = current + chr(line[i])
        }
        i = i + 1
    }
    parts = append(parts, cluster_trim(current))
    string node_name = ""
    string ip_address = ""
    string gpu_type = "H100"
    string status = "healthy"
    if len(parts) > 0 {
        node_name = parts[0]
    }
    if len(parts) > 1 {
        ip_address = parts[1]
    }
    int gpu_count = 8
    if len(parts) > 2 {
        gpu_count = cluster_parse_int(parts[2], 8)
    }
    if len(parts) > 3 && parts[3] != "" {
        gpu_type = parts[3]
    }
    int cpu_cores = 64
    if len(parts) > 4 {
        cpu_cores = cluster_parse_int(parts[4], 64)
    }
    int memory_gb = 512
    if len(parts) > 5 {
        memory_gb = cluster_parse_int(parts[5], 512)
    }
    if len(parts) > 6 && parts[6] != "" {
        status = parts[6]
    }
    float utilization = 0.0
    if len(parts) > 7 {
        utilization = cluster_parse_float(parts[7], 0.0)
    }
    new_cluster_node_spec(0, node_name, ip_address, gpu_count, gpu_type, cpu_cores, memory_gb, status, utilization)
}

func cluster_split_csv(string text) []string {
    string[] items = []string{}
    string current = ""
    int i = 0
    for i < len(text) {
        if text[i] == 44 {
            items = append(items, cluster_trim(current))
            current = ""
        } else {
            current = current + chr(text[i])
        }
        i = i + 1
    }
    if current != "" {
        items = append(items, cluster_trim(current))
    }
    items
}

func cluster_http_response_body(string response) string {
    int separator = cluster_find_substring(response, "\r\n\r\n")
    if separator < 0 {
        return ""
    }
    __host_slice(response, separator + 4, len(response))
}

func cluster_http_success(string response) bool {
    if len(response) < 12 {
        return false
    }
    __host_slice(response, 0, 12) == "HTTP/1.1 200"
}

func cluster_http_request(string host, int port, string method, string path, string body) string {
    int conn_fd = __sys_socket(2, 1, 6)
    if conn_fd < 0 {
        return ""
    }
    if __sys_connect(conn_fd, host, port, 2) < 0 {
        _ = __sys_close(conn_fd)
        return ""
    }
    string request = method + " " + path + " HTTP/1.1\r\n" +
        "Host: " + host + "\r\n" +
        "Connection: close\r\n" +
        "Content-Length: " + cluster_int_to_string(len(body)) + "\r\n\r\n" +
        body
    int offset = 0
    for offset < len(request) {
        string remaining = __host_slice(request, offset, len(request))
        int written = __sys_write_string(conn_fd, remaining)
        if written <= 0 {
            _ = __sys_close(conn_fd)
            return ""
        }
        offset = offset + written
    }
    string response = ""
    for true {
        string chunk = __sys_read_string(conn_fd, 65536)
        if len(chunk) == 0 {
            break
        }
        response = response + chunk
    }
    _ = __sys_close(conn_fd)
    response
}

func cluster_json_find_key(string json, string key) int {
    string search = "\"" + key + "\":"
    int i = 0
    for i + len(search) <= len(json) {
        bool found = true
        int j = 0
        for j < len(search) {
            if json[i + j] != search[j] {
                found = false
                break
            }
            j = j + 1
        }
        if found {
            return i + len(search)
        }
        i = i + 1
    }
    -1
}

func cluster_json_extract_raw(string json, string key) string {
    int start = cluster_json_find_key(json, key)
    if start < 0 {
        return ""
    }
    for start < len(json) && (json[start] == 32 || json[start] == 9 || json[start] == 10 || json[start] == 13) {
        start = start + 1
    }
    if start >= len(json) {
        return ""
    }
    if json[start] == 34 {
        start = start + 1
        int end = start
        bool escaped = false
        for end < len(json) {
            if escaped {
                escaped = false
            } else if json[end] == 92 {
                escaped = true
            } else if json[end] == 34 {
                return __host_slice(json, start, end)
            }
            end = end + 1
        }
        return ""
    }
    int end = start
    for end < len(json) && json[end] != 44 && json[end] != 125 && json[end] != 93 {
        end = end + 1
    }
    cluster_trim(__host_slice(json, start, end))
}

func cluster_json_extract_int(string json, string key, int fallback) int {
    string raw = cluster_json_extract_raw(json, key)
    if raw == "" {
        return fallback
    }
    cluster_parse_int(raw, fallback)
}

func cluster_json_extract_float(string json, string key, float fallback) float {
    string raw = cluster_json_extract_raw(json, key)
    if raw == "" {
        return fallback
    }
    cluster_parse_float(raw, fallback)
}

func cluster_discover_node_from_http(string host, int port) cluster_node_spec {
    string response = cluster_http_request(host, port, "GET", "/v1/node/info", "")
    if !cluster_http_success(response) {
        response = cluster_http_request(host, port, "GET", "/health", "")
    }
    if !cluster_http_success(response) {
        return new_cluster_node_spec(0, "", "", 0, "", 0, 0, "down", 0.0)
    }
    string body = cluster_http_response_body(response)
    string node_name = cluster_json_extract_raw(body, "node_name")
    if node_name == "" {
        node_name = cluster_json_extract_raw(body, "name")
    }
    if node_name == "" {
        node_name = host
    }
    string ip_address = cluster_json_extract_raw(body, "ip_address")
    if ip_address == "" {
        ip_address = cluster_json_extract_raw(body, "host")
    }
    if ip_address == "" {
        ip_address = host
    }
    int gpu_count = cluster_json_extract_int(body, "gpu_count", 1)
    string gpu_type = cluster_json_extract_raw(body, "gpu_type")
    if gpu_type == "" {
        gpu_type = "unknown"
    }
    int cpu_cores = cluster_json_extract_int(body, "cpu_cores", 8)
    int memory_gb = cluster_json_extract_int(body, "memory_gb", 32)
    string status = cluster_json_extract_raw(body, "status")
    if status == "" {
        status = "healthy"
    }
    float utilization = cluster_json_extract_float(body, "utilization", 0.0)
    new_cluster_node_spec(0, node_name, ip_address, gpu_count, gpu_type, cpu_cores, memory_gb, status, utilization)
}

func cluster_discover_nodes_from_network() []cluster_node_spec {
    string host_list = runtime_env_get("NEURX_DISCOVERY_HOSTS", "")
    string prefix_list = runtime_env_get("NEURX_DISCOVERY_PREFIXES", runtime_env_get("NEURX_DISCOVERY_PREFIX", ""))
    int port = cluster_parse_int(runtime_env_get("NEURX_DISCOVERY_PORT", runtime_env_get("NEURX_NODE_PORT", "8888")), 8888)
    []cluster_node_spec nodes = make([]cluster_node_spec, 0)
    if host_list != "" {
        string[] hosts = cluster_split_csv(host_list)
        int i = 0
        for i < len(hosts) {
            string host = cluster_trim(hosts[i])
            if host != "" {
                cluster_node_spec node = cluster_discover_node_from_http(host, port)
                if node.node_name != "" {
                    node.node_id = len(nodes)
                    nodes = append(nodes, node)
                }
            }
            i = i + 1
        }
        return nodes
    }
    if prefix_list == "" {
        return nodes
    }
    string[] prefixes = cluster_split_csv(prefix_list)
    int p = 0
    for p < len(prefixes) {
        string prefix = cluster_trim(prefixes[p])
        if prefix != "" {
            int host_id = 1
            for host_id <= 254 {
                string host = prefix + "." + cluster_int_to_string(host_id)
                cluster_node_spec node = cluster_discover_node_from_http(host, port)
                if node.node_name != "" {
                    node.node_id = len(nodes)
                    nodes = append(nodes, node)
                }
                host_id = host_id + 1
            }
        }
        p = p + 1
    }
    nodes
}

func cluster_node_manifest_path() string {
    "./artifact/cluster_nodes.manifest"
}

func cluster_discover_nodes_from_manifest() []cluster_node_spec {
    string manifest_path = cluster_node_manifest_path()
    if !runtime_file_exists(manifest_path) {
        return make([]cluster_node_spec, 0)
    }
    string text = runtime_read_text_file(manifest_path)
    string[] lines = cluster_split_lines(text)
    []cluster_node_spec nodes = make([]cluster_node_spec, len(lines))
    int i = 0
    for i < len(lines) {
        string line = cluster_trim(lines[i])
        if line != "" {
            cluster_node_spec node = cluster_parse_node_record(line)
            node.node_id = i
            nodes = append(nodes, node)
        }
        i = i + 1
    }
    nodes
}

func cluster_discover_local_fallback() []cluster_node_spec {
    []cluster_node_spec nodes = make([]cluster_node_spec, 1)
    nodes = append(nodes, new_cluster_node_spec(0, "localhost", "127.0.0.1", 1, "local", 8, 16, "healthy", 0.0))
    nodes
}

func cluster_discover_nodes(cluster_orchestration_state state) cluster_orchestration_state {
    cluster_orchestration_state next = state
    []cluster_node_spec discovered = cluster_discover_nodes_from_manifest()
    []cluster_node_spec network_discovered = cluster_discover_nodes_from_network()
    if len(network_discovered) > 0 {
        discovered = network_discovered
        next.discovery_source = "network"
    }
    if len(discovered) == 0 {
        discovered = cluster_discover_local_fallback()
        next.discovery_source = "local"
    } else if next.discovery_source == "" {
        next.discovery_source = "env_or_manifest"
    }
    next.nodes = discovered
    next.healthy_nodes = cluster_healthy_node_count(next)
    next.total_gpus = 0
    int i = 0
    for i < len(next.nodes) {
        next.total_gpus = next.total_gpus + next.nodes[i].gpu_count
        i = i + 1
    }
    next.ready = cluster_validate_setup(next)
    next
}

func cluster_elastic_recover(cluster_orchestration_state state) cluster_orchestration_state {
    cluster_orchestration_state next = state
    int recovered = 0
    int i = 0
    for i < len(next.nodes) {
        if next.nodes[i].status == "failed" {
            next.nodes[i].status = "standby"
        } else {
            if next.nodes[i].status == "degraded" && next.nodes[i].utilization < 0.85 {
                next.nodes[i].status = "healthy"
                recovered = recovered + 1
            }
        }
        i = i + 1
    }
    next.healthy_nodes = cluster_healthy_node_count(next)
    next.ready = cluster_validate_setup(next)
    next.last_summary = next.last_summary + "recovered_nodes=" + cluster_int_to_string(recovered) + "\n"
    next
}

func cluster_training_launch_command(cluster_deployment_spec spec) string {
    string cmd = "NEURX_CLUSTER_NAME=" + spec.cluster_name
    cmd = cmd + " NEURX_CLUSTER_BACKEND=" + spec.backend
    cmd = cmd + " NEURX_CLUSTER_WORLD_SIZE=" + cluster_int_to_string(spec.world_size)
    cmd = cmd + " NEURX_CLUSTER_MASTER_ADDR=" + spec.master_addr
    cmd = cmd + " NEURX_CLUSTER_MASTER_PORT=" + cluster_int_to_string(spec.master_port)
    cmd = cmd + " NEURX_CHECKPOINT_DIR=" + spec.checkpoint_dir
    cmd = cmd + " NEURX_TRAIN_OUTPUT_DIR=" + spec.output_dir
    cmd = cmd + " make run-training-s"
    cmd
}

func cluster_healthy_node_count(cluster_orchestration_state state) int {
    int healthy = 0
    int i = 0
    for i < len(state.nodes) {
        if state.nodes[i].status == "healthy" {
            healthy = healthy + 1
        }
        i = i + 1
    }
    healthy
}

func cluster_validate_setup(cluster_orchestration_state state) bool {
    if len(state.nodes) == 0 {
        return false
    }
    cluster_healthy_node_count(state) > 0
}

func cluster_recommended_world_size(cluster_orchestration_state state) int {
    int world = 0
    int i = 0
    for i < len(state.nodes) {
        if state.nodes[i].status == "healthy" {
            world = world + state.nodes[i].gpu_count
        }
        i = i + 1
    }
    if world <= 0 {
        world = 1
    }
    world
}

func cluster_recommended_backend(cluster_orchestration_state state) string {
    if state.backend != "" {
        return state.backend
    }
    if len(state.nodes) >= 2 {
        return "nccl"
    }
    "gloo"
}

func cluster_join_lines(string[] lines) string {
    string out = ""
    int i = 0
    for i < len(lines) {
        out = out + lines[i]
        if i + 1 < len(lines) {
            out = out + "\n"
        }
        i = i + 1
    }
    out
}

func cluster_int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    int n = value
    bool negative = false
    if n < 0 {
        negative = true
        n = -n
    }
    string out = ""
    for n > 0 {
        int digit = n - (n / 10) * 10
        out = chr(digit + 48) + out
        n = n / 10
    }
    if negative {
        out = "-" + out
    }
    out
}

func cluster_generate_env_lines(cluster_deployment_spec spec) []string {
    string[] lines = make([]string, 12)
    lines = append(lines, "export CLUSTER_NAME=" + spec.cluster_name)
    lines = append(lines, "export MASTER_ADDR=" + spec.master_addr)
    lines = append(lines, "export MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines = append(lines, "export WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines = append(lines, "export DATA_PARALLEL_SIZE=" + cluster_int_to_string(spec.data_parallel_size))
    lines = append(lines, "export TENSOR_PARALLEL_SIZE=" + cluster_int_to_string(spec.tensor_parallel_size))
    lines = append(lines, "export PIPELINE_PARALLEL_SIZE=" + cluster_int_to_string(spec.pipeline_parallel_size))
    lines = append(lines, "export BACKEND=" + spec.backend)
    lines = append(lines, "export CHECKPOINT_DIR=" + spec.checkpoint_dir)
    lines = append(lines, "export DATA_DIR=" + spec.data_dir)
    lines = append(lines, "export OUTPUT_DIR=" + spec.output_dir)
    lines = append(lines, "export NEURX_IMAGE=" + spec.image_name)
    lines
}

func cluster_default_pretrain_output_dir(cluster_deployment_spec spec) string {
    spec.checkpoint_dir + "/gpt_large_pretrain"
}

func cluster_default_pretrain_manifest_path(cluster_deployment_spec spec) string {
    spec.data_dir + "/manifest.json"
}

func cluster_default_pretrain_tokenizer_manifest_path(cluster_deployment_spec spec) string {
    "./data/tokenizer.manifest"
}

func cluster_generate_training_startup_lines(cluster_orchestration_state state, cluster_deployment_spec spec) []string {
    string[] lines = make([]string, 32)
    string pretrain_output_dir = cluster_default_pretrain_output_dir(spec)
    string pretrain_manifest = cluster_default_pretrain_manifest_path(spec)
    string tokenizer_manifest = cluster_default_pretrain_tokenizer_manifest_path(spec)
    lines = append(lines, "CLUSTER_NAME=" + spec.cluster_name)
    lines = append(lines, "CLUSTER_BACKEND=" + spec.backend)
    lines = append(lines, "WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines = append(lines, "MASTER_ADDR=" + spec.master_addr)
    lines = append(lines, "MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines = append(lines, "CHECKPOINT_DIR=" + spec.checkpoint_dir)
    lines = append(lines, "DATA_DIR=" + spec.data_dir)
    lines = append(lines, "OUTPUT_DIR=" + spec.output_dir)
    lines = append(lines, "DEPLOYMENT_DIR=" + state.deployment_dir)
    lines = append(lines, "NODE_MANIFEST=" + cluster_node_manifest_path())
    lines = append(lines, "LAUNCH_PLAN=" + state.deployment_dir + "/launch_plan.s")
    lines = append(lines, "SUMMARY_FILE=" + state.deployment_dir + "/cluster_summary.txt")
    lines = append(lines, "NEURX_PRETRAIN_OUTPUT_DIR=" + pretrain_output_dir)
    lines = append(lines, "NEURX_PRETRAIN_MANIFEST=" + pretrain_manifest)
    lines = append(lines, "NEURX_PRETRAIN_TOKENIZER_MANIFEST=" + tokenizer_manifest)
    lines = append(lines, "NEURX_PRETRAIN_PRECISION=bf16")
    lines = append(lines, "NEURX_PRETRAIN_MICRO_BATCH=8")
    lines = append(lines, "NEURX_PRETRAIN_SEQ_LEN=16")
    lines = append(lines, "NEURX_PRETRAIN_STEPS=64")
    lines = append(lines, "NEURX_PRETRAIN_LR=0.00015")
    lines = append(lines, "NEURX_PRETRAIN_MIN_LR=0.00003")
    lines = append(lines, "NEURX_PRETRAIN_WARMUP_STEPS=128")
    lines = append(lines, "NEURX_PRETRAIN_WEIGHT_DECAY=0.1")
    lines = append(lines, "NEURX_PRETRAIN_LOG_INTERVAL=8")
    lines = append(lines, "NEURX_PRETRAIN_EVAL_INTERVAL=16")
    lines = append(lines, "NEURX_PRETRAIN_SAVE_INTERVAL=32")
    lines = append(lines, "NEURX_PRETRAIN_GRAD_ACCUMULATION=1")
    lines = append(lines, "NEURX_PRETRAIN_RESUME=1")
    lines = append(lines, "NEURX_PRETRAIN_WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines = append(lines, "NEURX_PRETRAIN_BACKEND=" + spec.backend)
    lines = append(lines, "NEURX_PRETRAIN_MASTER_ADDR=" + spec.master_addr)
    lines = append(lines, "NEURX_PRETRAIN_MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines = append(lines, "NEURX_PRETRAIN_DATA_DIR=" + spec.data_dir)
    lines = append(lines, "NEURX_PRETRAIN_CHECKPOINT_DIR=" + spec.checkpoint_dir)
    lines = append(lines, "NEURX_PRETRAIN_USE_LAUNCH_PLAN=1")
    lines
}

func cluster_generate_training_startup_env(cluster_orchestration_state state, cluster_deployment_spec spec) string {
    string out = ""
    string[] lines = cluster_generate_training_startup_lines(state, spec)
    int i = 0
    for i < len(lines) {
        out = out + lines[i]
        if i + 1 < len(lines) {
            out = out + "\n"
        }
        i = i + 1
    }
    out
}

func cluster_generate_slurm_script(cluster_deployment_spec spec) string {
    string[] lines = make([]string, 32)
    lines = append(lines, "#!/bin/bash")
    lines = append(lines, "")
    lines = append(lines, "# NeurX cluster deployment script")
    lines = append(lines, "# cluster: " + spec.cluster_name)
    lines = append(lines, "# backend: " + spec.backend)
    lines = append(lines, "")
    lines = append(lines, "set -euo pipefail")
    lines = append(lines, "")
    lines = append(lines, "export MASTER_ADDR=" + spec.master_addr)
    lines = append(lines, "export MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines = append(lines, "export WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines = append(lines, "export RANK=${SLURM_PROCID:-0}")
    lines = append(lines, "export LOCAL_RANK=${SLURM_LOCALID:-0}")
    lines = append(lines, "export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0,1,2,3}")
    lines = append(lines, "")
    lines = append(lines, "mkdir -p " + spec.output_dir)
    lines = append(lines, "mkdir -p " + spec.checkpoint_dir)
    lines = append(lines, "")
    lines = append(lines, "echo '[NeurX] launching distributed training'")
    lines = append(lines, "echo 'cluster=" + spec.cluster_name + "'")
    lines = append(lines, "echo 'world_size=" + cluster_int_to_string(spec.world_size) + "'")
    lines = append(lines, "echo 'backend=" + spec.backend + "'")
    lines = append(lines, "")
    lines = append(lines, "srun neurx run train/train_gpt_large.s \\")
    lines = append(lines, "  --data_dir=" + spec.data_dir + " \\")
    lines = append(lines, "  --checkpoint_dir=" + spec.checkpoint_dir + " \\")
    lines = append(lines, "  --output_dir=" + spec.output_dir + " \\")
    lines = append(lines, "  --backend=" + spec.backend + " \\")
    lines = append(lines, "  --world_size=" + cluster_int_to_string(spec.world_size) + " \\")
    lines = append(lines, "  --master_addr=" + spec.master_addr + " \\")
    lines = append(lines, "  --master_port=" + cluster_int_to_string(spec.master_port))
    cluster_join_lines(lines)
}

func cluster_generate_kubernetes_yaml(cluster_deployment_spec spec) string {
    string[] lines = make([]string, 40)
    lines = append(lines, "apiVersion: app/v1")
    lines = append(lines, "kind: StatefulSet")
    lines = append(lines, "metadata:")
    lines = append(lines, "  name: " + spec.deployment_name)
    lines = append(lines, "spec:")
    lines = append(lines, "  replicas: " + cluster_int_to_string(spec.replica_count))
    lines = append(lines, "  serviceName: " + spec.cluster_name)
    lines = append(lines, "  selector:")
    lines = append(lines, "    matchLabels:")
    lines = append(lines, "      app: " + spec.deployment_name)
    lines = append(lines, "  template:")
    lines = append(lines, "    metadata:")
    lines = append(lines, "      labels:")
    lines = append(lines, "        app: " + spec.deployment_name)
    lines = append(lines, "    spec:")
    lines = append(lines, "      containers:")
    lines = append(lines, "      - name: neurx-trainer")
    lines = append(lines, "        image: " + spec.image_name)
    lines = append(lines, "        env:")
    lines = append(lines, "        - name: MASTER_ADDR")
    lines = append(lines, "          value: \"" + spec.master_addr + "\"")
    lines = append(lines, "        - name: MASTER_PORT")
    lines = append(lines, "          value: \"" + cluster_int_to_string(spec.master_port) + "\"")
    lines = append(lines, "        - name: WORLD_SIZE")
    lines = append(lines, "          value: \"" + cluster_int_to_string(spec.world_size) + "\"")
    lines = append(lines, "        - name: BACKEND")
    lines = append(lines, "          value: \"" + spec.backend + "\"")
    lines = append(lines, "        - name: CHECKPOINT_DIR")
    lines = append(lines, "          value: \"" + spec.checkpoint_dir + "\"")
    lines = append(lines, "        - name: DATA_DIR")
    lines = append(lines, "          value: \"" + spec.data_dir + "\"")
    lines = append(lines, "        - name: OUTPUT_DIR")
    lines = append(lines, "          value: \"" + spec.output_dir + "\"")
    lines = append(lines, "        resources:")
    lines = append(lines, "          requests:")
    lines = append(lines, "            nvidia.com/gpu: \"1\"")
    lines = append(lines, "            cpu: \"16\"")
    lines = append(lines, "            memory: \"64Gi\"")
    lines = append(lines, "          limits:")
    lines = append(lines, "            nvidia.com/gpu: \"1\"")
    lines = append(lines, "            cpu: \"32\"")
    lines = append(lines, "            memory: \"128Gi\"")
    cluster_join_lines(lines)
}

func cluster_state_summary(cluster_orchestration_state state, cluster_deployment_spec spec) string {
    string out = ""
    out = out + "cluster=" + state.cluster_name + "\n"
    out = out + "deployment_dir=" + state.deployment_dir + "\n"
    out = out + "backend=" + cluster_recommended_backend(state) + "\n"
    out = out + "healthy_nodes=" + cluster_int_to_string(cluster_healthy_node_count(state)) + "\n"
    out = out + "total_gpus=" + cluster_int_to_string(state.total_gpus) + "\n"
    out = out + "recommended_world_size=" + cluster_int_to_string(cluster_recommended_world_size(state)) + "\n"
    out = out + "master_addr=" + spec.master_addr + "\n"
    out = out + "master_port=" + cluster_int_to_string(spec.master_port) + "\n"
    out = out + "checkpoint_dir=" + spec.checkpoint_dir + "\n"
    out = out + "data_dir=" + spec.data_dir + "\n"
    out = out + "output_dir=" + spec.output_dir + "\n"
    out
}

func cluster_discovery_summary(cluster_orchestration_state state) string {
    string out = ""
    out = out + "discovery_source=" + state.discovery_source + "\n"
    out = out + "discovered_nodes=" + cluster_int_to_string(len(state.nodes)) + "\n"
    int i = 0
    for i < len(state.nodes) {
        out = out + "node[" + cluster_int_to_string(i) + "]="
        out = out + state.nodes[i].node_name
        out = out + " ip=" + state.nodes[i].ip_address
        out = out + " gpu_count=" + cluster_int_to_string(state.nodes[i].gpu_count)
        out = out + " status=" + state.nodes[i].status
        out = out + "\n"
        i = i + 1
    }
    out
}

func cluster_write_deployment_bundle(cluster_orchestration_state state, cluster_deployment_spec spec) cluster_orchestration_state {
    cluster_orchestration_state next = state
    if next.deployment_dir == "" {
        next.deployment_dir = "./production_deployment"
    }
    runtime_make_dirs(next.deployment_dir)
    runtime_make_dirs(next.deployment_dir + "/scripts")
    runtime_make_dirs(next.deployment_dir + "/configs")
    string slurm_path = next.deployment_dir + "/script/slurm_submit.sh"
    string k8s_path = next.deployment_dir + "/kubernetes_deployment.yaml"
    string summary_path = next.deployment_dir + "/cluster_summary.txt"
    string startup_path = next.deployment_dir + "/training_startup.env"
    runtime_write_text_file(slurm_path, cluster_generate_slurm_script(spec))
    runtime_write_text_file(k8s_path, cluster_generate_kubernetes_yaml(spec))
    runtime_write_text_file(summary_path, cluster_state_summary(next, spec))
    runtime_write_text_file(startup_path, cluster_generate_training_startup_env(next, spec))
    next.last_manifest_path = cluster_node_manifest_path()
    next.last_summary = cluster_state_summary(next, spec)
    next.ready = cluster_validate_setup(next)
    next
}

func cluster_write_launch_plan(cluster_orchestration_state state, cluster_deployment_spec spec) cluster_orchestration_state {
    cluster_orchestration_state next = state
    string launch_path = next.deployment_dir + "/launch_plan.s"
    string launch_plan = "package main\n\nuse neurx.runtime.io.{runtime_run_command, runtime_shell_escape}\nuse std.io.println\n\nfunc main() {\n    string startup_env = \"" + next.deployment_dir + "/training_startup.env\"\n    println(\"NeurX cluster launch plan (S Lang)\")\n    println(\"\")\n    println(\"Startup env : \" + startup_env)\n    println(\"Target      : make run-training-s\")\n    println(\"\")\n\n    string cmd = \". \" + runtime_shell_escape(startup_env) + \" && export NEURX_PRETRAIN_USE_LAUNCH_PLAN=0 NEURX_CLUSTER_DISABLE=1 && " + cluster_training_launch_command(spec) + "\"\n    if !runtime_run_command(cmd).ok {\n        return 1\n    }\n    0\n}\n"
    runtime_write_text_file(launch_path, launch_plan)
    next.last_summary = next.last_summary + "launch_plan=" + launch_path + "\n"
    next
}

func cluster_state_dict(cluster_orchestration_state state) cluster_orchestration_state {
    state
}

func cluster_load_state_dict(cluster_orchestration_state state, cluster_orchestration_state other) cluster_orchestration_state {
    del state
    other
}

func new_demo_cluster_state() cluster_orchestration_state {
    cluster_orchestration_state state = new_cluster_orchestration_state("neurx-prod", "./production_deployment", "nccl")
    state = cluster_add_node(state, new_cluster_node_spec(0, "node-0", "10.0.0.10", 8, "H100", 64, 512, "healthy", 0.18))
    state = cluster_add_node(state, new_cluster_node_spec(1, "node-1", "10.0.0.11", 8, "H100", 64, 512, "healthy", 0.14))
    state = cluster_add_node(state, new_cluster_node_spec(2, "node-2", "10.0.0.12", 8, "H100", 64, 512, "healthy", 0.21))
    state = cluster_add_node(state, new_cluster_node_spec(3, "node-3", "10.0.0.13", 8, "H100", 64, 512, "degraded", 0.37))
    state
}

func main() {
    cluster_orchestration_state state = new_demo_cluster_state()
    state = cluster_discover_nodes(state)
    state = cluster_elastic_recover(state)
    cluster_deployment_spec spec = new_cluster_deployment_spec(
        state.cluster_name,
        "neurx:latest",
        cluster_recommended_backend(state),
        "node-0",
        29500,
        len(state.nodes),
        cluster_recommended_world_size(state),
        "./artifact/checkpoints",
        "./dataset/pretrain",
        "./artifact/train_output"
    )
    state = cluster_write_deployment_bundle(state, spec)
    state = cluster_write_launch_plan(state, spec)
    runtime_write_text_file(state.deployment_dir + "/latest_cluster_summary.txt", state.last_summary)
}
