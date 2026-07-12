package neurx.deployment.cluster_orchestration

use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}

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
        nodes: []cluster_node_spec{cap: 0},
        healthy_nodes: 0,
        total_gpus: 0,
        ready: false,
        last_summary: "",
        last_manifest_path: "",
    }
}

func cluster_add_node(cluster_orchestration_state state, cluster_node_spec node) cluster_orchestration_state {
    cluster_orchestration_state next = state
    next.nodes.push(node)
    next.total_gpus = next.total_gpus + node.gpu_count
    if node.status == "healthy" {
        next.healthy_nodes = next.healthy_nodes + 1
    }
    next
}

func cluster_trim(string s) string {
    int left = 0
    while left < len(s) && (s[left] == 32 || s[left] == 9 || s[left] == 10 || s[left] == 13) {
        left = left + 1
    }
    int right = len(s) - 1
    while right >= left && (s[right] == 32 || s[right] == 9 || s[right] == 10 || s[right] == 13) {
        right = right - 1
    }
    if right < left {
        return ""
    }
    string out = ""
    int i = left
    while i <= right {
        out = out + chr(s[i])
        i = i + 1
    }
    out
}

func cluster_split_lines(string text) []string {
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        if text[i] == 10 || text[i] == 13 {
            if len(current) > 0 {
                lines.push(current)
                current = ""
            }
        } else {
            current = current + chr(text[i])
        }
        i = i + 1
    }
    if len(current) > 0 {
        lines.push(current)
    }
    lines
}

func cluster_find_substring(string text, string pattern) int {
    if len(pattern) == 0 {
        return 0
    }
    int i = 0
    while i + len(pattern) <= len(text) {
        int j = 0
        while j < len(pattern) && text[i + j] == pattern[j] {
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
    while i < len(s) {
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
    while i < len(s) && s[i] >= 48 && s[i] <= 57 {
        whole = whole * 10.0 + (s[i] - 48) * 1.0
        i = i + 1
    }
    float frac = 0.0
    float div = 1.0
    if i < len(s) && s[i] == 46 {
        i = i + 1
        while i < len(s) && s[i] >= 48 && s[i] <= 57 {
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
    []string parts = []string{cap: 8}
    string current = ""
    int i = 0
    while i < len(line) {
        if line[i] == 124 {
            parts.push(cluster_trim(current))
            current = ""
        } else {
            current = current + chr(line[i])
        }
        i = i + 1
    }
    parts.push(cluster_trim(current))

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

func cluster_node_manifest_path() string {
    "./artifacts/cluster_nodes.manifest"
}

func cluster_discover_nodes_from_manifest() []cluster_node_spec {
    string manifest_path = cluster_node_manifest_path()
    if !runtime_file_exists(manifest_path) {
        return []cluster_node_spec{cap: 0}
    }
    string text = runtime_read_text_file(manifest_path)
    []string lines = cluster_split_lines(text)
    []cluster_node_spec nodes = []cluster_node_spec{cap: len(lines)}
    int i = 0
    while i < len(lines) {
        string line = cluster_trim(lines[i])
        if line != "" {
            cluster_node_spec node = cluster_parse_node_record(line)
            node.node_id = i
            nodes.push(node)
        }
        i = i + 1
    }
    nodes
}

func cluster_discover_local_fallback() []cluster_node_spec {
    []cluster_node_spec nodes = []cluster_node_spec{cap: 1}
    nodes.push(new_cluster_node_spec(0, "localhost", "127.0.0.1", 1, "local", 8, 16, "healthy", 0.0))
    nodes
}

func cluster_discover_nodes(cluster_orchestration_state state) cluster_orchestration_state {
    cluster_orchestration_state next = state
    []cluster_node_spec discovered = cluster_discover_nodes_from_manifest()
    if len(discovered) == 0 {
        discovered = cluster_discover_local_fallback()
        next.discovery_source = "local"
    } else {
        next.discovery_source = "env_or_manifest"
    }
    next.nodes = discovered
    next.healthy_nodes = cluster_healthy_node_count(next)
    next.total_gpus = 0
    int i = 0
    while i < len(next.nodes) {
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
    while i < len(next.nodes) {
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
    while i < len(state.nodes) {
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
    while i < len(state.nodes) {
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

func cluster_join_lines([]string lines) string {
    string out = ""
    int i = 0
    while i < len(lines) {
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
    while n > 0 {
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
    []string lines = []string{cap: 12}
    lines.push("export CLUSTER_NAME=" + spec.cluster_name)
    lines.push("export MASTER_ADDR=" + spec.master_addr)
    lines.push("export MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines.push("export WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines.push("export DATA_PARALLEL_SIZE=" + cluster_int_to_string(spec.data_parallel_size))
    lines.push("export TENSOR_PARALLEL_SIZE=" + cluster_int_to_string(spec.tensor_parallel_size))
    lines.push("export PIPELINE_PARALLEL_SIZE=" + cluster_int_to_string(spec.pipeline_parallel_size))
    lines.push("export BACKEND=" + spec.backend)
    lines.push("export CHECKPOINT_DIR=" + spec.checkpoint_dir)
    lines.push("export DATA_DIR=" + spec.data_dir)
    lines.push("export OUTPUT_DIR=" + spec.output_dir)
    lines.push("export NEURX_IMAGE=" + spec.image_name)
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
    []string lines = []string{cap: 32}
    string pretrain_output_dir = cluster_default_pretrain_output_dir(spec)
    string pretrain_manifest = cluster_default_pretrain_manifest_path(spec)
    string tokenizer_manifest = cluster_default_pretrain_tokenizer_manifest_path(spec)
    lines.push("CLUSTER_NAME=" + spec.cluster_name)
    lines.push("CLUSTER_BACKEND=" + spec.backend)
    lines.push("WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines.push("MASTER_ADDR=" + spec.master_addr)
    lines.push("MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines.push("CHECKPOINT_DIR=" + spec.checkpoint_dir)
    lines.push("DATA_DIR=" + spec.data_dir)
    lines.push("OUTPUT_DIR=" + spec.output_dir)
    lines.push("DEPLOYMENT_DIR=" + state.deployment_dir)
    lines.push("NODE_MANIFEST=" + cluster_node_manifest_path())
    lines.push("LAUNCH_PLAN=" + state.deployment_dir + "/launch_plan.s")
    lines.push("SUMMARY_FILE=" + state.deployment_dir + "/cluster_summary.txt")
    lines.push("NEURX_PRETRAIN_OUTPUT_DIR=" + pretrain_output_dir)
    lines.push("NEURX_PRETRAIN_MANIFEST=" + pretrain_manifest)
    lines.push("NEURX_PRETRAIN_TOKENIZER_MANIFEST=" + tokenizer_manifest)
    lines.push("NEURX_PRETRAIN_PRECISION=bf16")
    lines.push("NEURX_PRETRAIN_MICRO_BATCH=8")
    lines.push("NEURX_PRETRAIN_SEQ_LEN=16")
    lines.push("NEURX_PRETRAIN_STEPS=64")
    lines.push("NEURX_PRETRAIN_LR=0.00015")
    lines.push("NEURX_PRETRAIN_MIN_LR=0.00003")
    lines.push("NEURX_PRETRAIN_WARMUP_STEPS=128")
    lines.push("NEURX_PRETRAIN_WEIGHT_DECAY=0.1")
    lines.push("NEURX_PRETRAIN_LOG_INTERVAL=8")
    lines.push("NEURX_PRETRAIN_EVAL_INTERVAL=16")
    lines.push("NEURX_PRETRAIN_SAVE_INTERVAL=32")
    lines.push("NEURX_PRETRAIN_GRAD_ACCUMULATION=1")
    lines.push("NEURX_PRETRAIN_RESUME=1")
    lines.push("NEURX_PRETRAIN_WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines.push("NEURX_PRETRAIN_BACKEND=" + spec.backend)
    lines.push("NEURX_PRETRAIN_MASTER_ADDR=" + spec.master_addr)
    lines.push("NEURX_PRETRAIN_MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines.push("NEURX_PRETRAIN_DATA_DIR=" + spec.data_dir)
    lines.push("NEURX_PRETRAIN_CHECKPOINT_DIR=" + spec.checkpoint_dir)
    lines.push("NEURX_PRETRAIN_USE_LAUNCH_PLAN=1")
    lines
}

func cluster_generate_training_startup_env(cluster_orchestration_state state, cluster_deployment_spec spec) string {
    string out = ""
    []string lines = cluster_generate_training_startup_lines(state, spec)
    int i = 0
    while i < len(lines) {
        out = out + lines[i]
        if i + 1 < len(lines) {
            out = out + "\n"
        }
        i = i + 1
    }
    out
}

func cluster_generate_slurm_script(cluster_deployment_spec spec) string {
    []string lines = []string{cap: 32}
    lines.push("#!/bin/bash")
    lines.push("")
    lines.push("# NeurX cluster deployment script")
    lines.push("# cluster: " + spec.cluster_name)
    lines.push("# backend: " + spec.backend)
    lines.push("")
    lines.push("set -euo pipefail")
    lines.push("")
    lines.push("export MASTER_ADDR=" + spec.master_addr)
    lines.push("export MASTER_PORT=" + cluster_int_to_string(spec.master_port))
    lines.push("export WORLD_SIZE=" + cluster_int_to_string(spec.world_size))
    lines.push("export RANK=${SLURM_PROCID:-0}")
    lines.push("export LOCAL_RANK=${SLURM_LOCALID:-0}")
    lines.push("export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0,1,2,3}")
    lines.push("")
    lines.push("mkdir -p " + spec.output_dir)
    lines.push("mkdir -p " + spec.checkpoint_dir)
    lines.push("")
    lines.push("echo '[NeurX] launching distributed training'")
    lines.push("echo 'cluster=" + spec.cluster_name + "'")
    lines.push("echo 'world_size=" + cluster_int_to_string(spec.world_size) + "'")
    lines.push("echo 'backend=" + spec.backend + "'")
    lines.push("")
    lines.push("srun neurx run train/train_gpt_large.s \\")
    lines.push("  --data_dir=" + spec.data_dir + " \\")
    lines.push("  --checkpoint_dir=" + spec.checkpoint_dir + " \\")
    lines.push("  --output_dir=" + spec.output_dir + " \\")
    lines.push("  --backend=" + spec.backend + " \\")
    lines.push("  --world_size=" + cluster_int_to_string(spec.world_size) + " \\")
    lines.push("  --master_addr=" + spec.master_addr + " \\")
    lines.push("  --master_port=" + cluster_int_to_string(spec.master_port))
    cluster_join_lines(lines)
}

func cluster_generate_kubernetes_yaml(cluster_deployment_spec spec) string {
    []string lines = []string{cap: 40}
    lines.push("apiVersion: apps/v1")
    lines.push("kind: StatefulSet")
    lines.push("metadata:")
    lines.push("  name: " + spec.deployment_name)
    lines.push("spec:")
    lines.push("  replicas: " + cluster_int_to_string(spec.replica_count))
    lines.push("  serviceName: " + spec.cluster_name)
    lines.push("  selector:")
    lines.push("    matchLabels:")
    lines.push("      app: " + spec.deployment_name)
    lines.push("  template:")
    lines.push("    metadata:")
    lines.push("      labels:")
    lines.push("        app: " + spec.deployment_name)
    lines.push("    spec:")
    lines.push("      containers:")
    lines.push("      - name: neurx-trainer")
    lines.push("        image: " + spec.image_name)
    lines.push("        env:")
    lines.push("        - name: MASTER_ADDR")
    lines.push("          value: \"" + spec.master_addr + "\"")
    lines.push("        - name: MASTER_PORT")
    lines.push("          value: \"" + cluster_int_to_string(spec.master_port) + "\"")
    lines.push("        - name: WORLD_SIZE")
    lines.push("          value: \"" + cluster_int_to_string(spec.world_size) + "\"")
    lines.push("        - name: BACKEND")
    lines.push("          value: \"" + spec.backend + "\"")
    lines.push("        - name: CHECKPOINT_DIR")
    lines.push("          value: \"" + spec.checkpoint_dir + "\"")
    lines.push("        - name: DATA_DIR")
    lines.push("          value: \"" + spec.data_dir + "\"")
    lines.push("        - name: OUTPUT_DIR")
    lines.push("          value: \"" + spec.output_dir + "\"")
    lines.push("        resources:")
    lines.push("          requests:")
    lines.push("            nvidia.com/gpu: \"1\"")
    lines.push("            cpu: \"16\"")
    lines.push("            memory: \"64Gi\"")
    lines.push("          limits:")
    lines.push("            nvidia.com/gpu: \"1\"")
    lines.push("            cpu: \"32\"")
    lines.push("            memory: \"128Gi\"")
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

func cluster_write_deployment_bundle(cluster_orchestration_state state, cluster_deployment_spec spec) cluster_orchestration_state {
    cluster_orchestration_state next = state
    if next.deployment_dir == "" {
        next.deployment_dir = "./production_deployment"
    }
    runtime_make_dirs(next.deployment_dir)
    runtime_make_dirs(next.deployment_dir + "/scripts")
    runtime_make_dirs(next.deployment_dir + "/configs")

    string slurm_path = next.deployment_dir + "/scripts/slurm_submit.sh"
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
    string launch_plan = "package main\n\nuse neurx.runtime.io.{runtime_run_command, runtime_shell_escape}\nuse std.io.println\n\nfunc main() int {\n    string startup_env = \"" + next.deployment_dir + "/training_startup.env\"\n    println(\"NeurX cluster launch plan (S Lang)\")\n    println(\"\")\n    println(\"Startup env : \" + startup_env)\n    println(\"Target      : make run-training-s\")\n    println(\"\")\n\n    string cmd = \". \" + runtime_shell_escape(startup_env) + \" && export NEURX_PRETRAIN_USE_LAUNCH_PLAN=0 NEURX_CLUSTER_DISABLE=1 && " + cluster_training_launch_command(spec) + "\"\n    if !runtime_run_command(cmd).ok {\n        return 1\n    }\n    0\n}\n"
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
        "./artifacts/checkpoints",
        "./dataset/pretrain",
        "./artifacts/train_output"
    )
    state = cluster_write_deployment_bundle(state, spec)
    state = cluster_write_launch_plan(state, spec)
    runtime_write_text_file(state.deployment_dir + "/latest_cluster_summary.txt", state.last_summary)
}
