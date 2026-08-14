package main
use std.exec
use std.os
use std.path
use std.strings
struct multi_node_config_2 {
    root string
    hostfile string
    master_addr string
    master_port string
    shared_id string
    output string
    resume_enabled bool
    hosts []string
}

func parse_host_file(string hostfile) []string {
    content, _ := os.ReadFile(hostfile)
    lines := strings.Split(string(content), "\n")
    hosts := []string{}
    for _, line := range lines {
        trimmed := strings.TrimSpace(line)
        if trimmed != "" && !strings.HasPrefix(trimmed, "#") {
            hosts = append(hosts, trimmed)
        }
    }
    return hosts
}

func get_gpu_count(string host) int {
    cmd := exec.command("ssh", host, "nvidia-smi -L | wc -l")
    output, _ := cmd.Output()
    count := 0
    strings.TrimSpace(string(output))
    return count
}

func launch_on_host(string host, int rank, config multi_node_config_2) {
    env := os.Environ()
    env = append(env,
        "NEURX_ROOT=" + config.root,
        "NEURX_PRETRAIN_OUTPUT_DIR=" + config.output,
        "NEURX_NCCL_ID_FILE=" + config.sharedId,
        "RANK=" + string(rank),
        "LOCAL_RANK=0",
        "WORLD_SIZE=1",
        "MASTER_ADDR=" + config.masterAddr,
        "MASTER_PORT=" + config.masterPort,
        "CUDA_VISIBLE_DEVICES=0",
    )
    cmd := exec.command(config.root + "/artifacts/build/cuda_train/neurx_cuda_train_bridge")
    cmd.Env = env
    cmd.Dir = config.root
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Run()
}

func main() {
    root := os.Getenv("NEURX_ROOT")
    if root == "" {
        root = "."
    }
    hostfile := os.Getenv("NEURX_HOSTFILE")
    if hostfile == "" {
        hostfile = root + "/configs/pretrain.hosts"
    }
    config := multi_node_config_2{
        root: root,
        hostfile: hostfile,
        master_addr: os.Getenv("MASTER_ADDR"),
        master_port: os.Getenv("MASTER_PORT"),
        shared_id: os.Getenv("NEURX_SHARED_NCCL_ID_FILE"),
        output: os.Getenv("NEURX_PRETRAIN_OUTPUT_DIR"),
    }
    if config.masterPort == "" {
        config.masterPort = "29500"
    }
    if config.sharedId == "" {
        config.sharedId = root + "/artifacts/nccl/unique_id"
    }
    if config.output == "" {
        config.output = root + "/checkpoint/NeurX-1.3"
    }
    config.hosts = parse_host_file(config.hostfile)
    if config.masterAddr == "" && len(config.hosts) > 0 {
        config.masterAddr = strings.Fields(config.hosts[0])[0]
    }
    os.MkdirAll(path.Dir(config.output), 0755)
    os.MkdirAll(path.Dir(config.sharedId), 0755)
    io.Println("[multinode] nodes=" + string(len(config.hosts)) + " master=" + config.masterAddr + ":" + config.masterPort)
    for i, host := range config.hosts {
        launch_on_host(host, i, config)
    }
}
