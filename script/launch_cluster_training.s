#!/usr/bin/env s

// ============================================
// NeurX Multi-Node Cluster Launcher
// 多机集群启动脚本
// 功能: SSH启动、进程管理、日志聚合
// ============================================

package main

use neurx.runtime.io.{runtime_env_get}
use neurx.strings.{string_concat}

// ============================================
// 集群配置
// ============================================

struct cluster_config {
    int num_nodes
    []string node_addresses      // 节点IP/主机名列表
    int gpus_per_node
    string master_node_address
    int master_port
    string ssh_key_path
    string ssh_user
    string working_dir           // 远程工作目录
    string log_dir              // 日志目录
}

struct node_process_handle {
    int node_id
    string node_address
    int process_id
    bool is_running
}

// ============================================
// 集群配置解析
// ============================================

// 从配置文件或环境变量读取集群配置
func parse_cluster_config() cluster_config {
    
    // 从环境变量读取
    string node_list = runtime_env_get("NEURX_NODE_LIST", "localhost")
    int num_nodes = parse_int(runtime_env_get("NEURX_NUM_NODES", "1"), 1)
    int gpus_per_node = parse_int(runtime_env_get("NEURX_GPUS_PER_NODE", "1"), 1)
    string master_addr = runtime_env_get("NEURX_MASTER_ADDR", "localhost")
    int master_port = parse_int(runtime_env_get("NEURX_MASTER_PORT", "29500"), 29500)
    string ssh_user = runtime_env_get("NEURX_SSH_USER", "root")
    string working_dir = runtime_env_get("NEURX_WORKING_DIR", "/home/neurx")
    string log_dir = runtime_env_get("NEURX_LOG_DIR", "/mnt/nccl_shared/logs")
    
    // 解析节点列表 (格式: "node1,node2,node3" 或 "10.0.0.1,10.0.0.2,10.0.0.3")
    []string nodes = split_string(node_list, ",")
    
    cluster_config {
        num_nodes: num_nodes,
        node_addresses: nodes,
        gpus_per_node: gpus_per_node,
        master_node_address: master_addr,
        master_port: master_port,
        ssh_key_path: runtime_env_get("NEURX_SSH_KEY", "/root/.ssh/id_rsa"),
        ssh_user: ssh_user,
        working_dir: working_dir,
        log_dir: log_dir,
    }
}

// ============================================
// 集群启动
// ============================================

// 启动所有节点的训练进程
func launch_cluster_training(
    cluster_config config,
) []node_process_handle {
    
    print("="*60)
    print("Launching NeurX Multi-Node Training Cluster")
    print("="*60)
    
    print("[CLUSTER] Configuration:")
    print("  - Total nodes: " + itoa(config.num_nodes))
    print("  - GPUs per node: " + itoa(config.gpus_per_node))
    print("  - Master node: " + config.master_node_address + ":" + itoa(config.master_port))
    print("  - SSH user: " + config.ssh_user)
    print("  - Working directory: " + config.working_dir)
    
    []node_process_handle handles = []node_process_handle{cap: config.num_nodes}
    
    // 在每个节点上启动GPU训练进程
    int node_idx = 0
    while node_idx < config.num_nodes {
        
        string node_addr = config.node_addresses[node_idx]
        
        print("[CLUSTER] Launching node " + itoa(node_idx) + " (" + node_addr + ")...")
        
        // 构建启动命令
        string cmd = build_launch_command(
            config,
            node_idx,
            node_addr,
        )
        
        // 通过SSH在远程节点执行
        int pid = execute_remote_training(
            config,
            node_idx,
            node_addr,
            cmd,
        )
        
        if pid > 0 {
            handles[node_idx] = node_process_handle {
                node_id: node_idx,
                node_address: node_addr,
                process_id: pid,
                is_running: true,
            }
            print("[CLUSTER] Node " + itoa(node_idx) + " launched (PID: " + itoa(pid) + ")")
        } else {
            print("[ERROR] Failed to launch node " + itoa(node_idx))
        }
        
        node_idx = node_idx + 1
    }
    
    handles
}

// ============================================
// 命令生成
// ============================================

// 构建单个节点的启动命令
func build_launch_command(
    cluster_config config,
    int node_rank,
    string node_addr,
) string {
    
    // 格式: cd $WORKING_DIR && \
    //       WORLD_SIZE=N RANK=rank MASTER_ADDR=master_ip ./pretrain/distributed_pretrain_multi_node_entry.s
    
    string world_size = itoa(config.num_nodes * config.gpus_per_node)
    
    string cmd = "cd " + config.working_dir + " && " +
                 "export WORLD_SIZE=" + world_size + " && " +
                 "export NEURX_NUM_NODES=" + itoa(config.num_nodes) + " && " +
                 "export NEURX_NODE_RANK=" + itoa(node_rank) + " && " +
                 "export NEURX_GPUS_PER_NODE=" + itoa(config.gpus_per_node) + " && " +
                 "export NEURX_MASTER_ADDR=" + config.master_node_address + " && " +
                 "export NEURX_MASTER_PORT=" + itoa(config.master_port) + " && " +
                 "export NEURX_NODE_NAME=" + node_addr + " && " +
                 "export NEURX_NODE_LIST=" + string_join(config.node_addresses, ",") + " && " +
                 "./pretrain/distributed_pretrain_multi_node_entry.s"
    
    cmd
}

// ============================================
// 远程执行
// ============================================

// 通过SSH在远程节点执行训练
func execute_remote_training(
    cluster_config config,
    int node_rank,
    string node_addr,
    string cmd,
) int {
    
    // SSH命令格式:
    // ssh -i key_file user@host "nohup cmd > log 2>&1 &"
    
    string log_file = config.log_dir + "/node_" + itoa(node_rank) + ".log"
    
    string ssh_cmd = "ssh -i " + config.ssh_key_path +
                     " -o StrictHostKeyChecking=no" +
                     " -o ConnectTimeout=30" +
                     " " + config.ssh_user + "@" + node_addr +
                     " 'nohup " + cmd +
                     " > " + log_file + " 2>&1 &'"
    
    print("[CLUSTER] Executing SSH command on " + node_addr)
    
    // 实际实现中调用系统命令
    // int exit_code = exec_command(ssh_cmd)
    
    // 模拟返回PID
    int simulated_pid = 10000 + node_rank
    simulated_pid
}

// ============================================
// 进程监控
// ============================================

// 监控所有节点的进程状态
func monitor_cluster_processes(
    []node_process_handle handles,
    cluster_config config,
) []node_process_handle {
    
    print("[MONITOR] Starting cluster process monitoring...")
    
    int alive_count = 0
    int dead_count = 0
    
    int i = 0
    while i < len(handles) {
        
        node_process_handle h = handles[i]
        
        // 检查远程进程是否还在运行
        bool still_running = check_remote_process(
            config,
            h.node_address,
            h.process_id,
        )
        
        if still_running {
            alive_count = alive_count + 1
            print("[MONITOR] Node " + itoa(h.node_id) + " is running")
        } else {
            dead_count = dead_count + 1
            print("[WARNING] Node " + itoa(h.node_id) + " process died!")
            handles[i].is_running = false
        }
        
        i = i + 1
    }
    
    print("[MONITOR] Status: " + itoa(alive_count) + " alive, " + itoa(dead_count) + " dead")
    
    handles
}

// 检查远程进程是否运行
func check_remote_process(
    cluster_config config,
    string node_addr,
    int pid,
) bool {
    
    // SSH ps命令
    string cmd = "ssh -i " + config.ssh_key_path +
                 " " + config.ssh_user + "@" + node_addr +
                 " ps -p " + itoa(pid)
    
    // 实际实现中执行命令并检查返回码
    // bool exists = (exec_command(cmd) == 0)
    
    true  // 模拟进程运行中
}

// ============================================
// 日志聚合
// ============================================

// 从所有节点收集日志
func collect_cluster_logs(
    []node_process_handle handles,
    cluster_config config,
) bool {
    
    print("[LOGS] Collecting logs from all nodes...")
    
    string aggregated_log = config.log_dir + "/cluster_aggregated.log"
    
    // 创建汇总日志文件
    print("[LOGS] Aggregating logs to: " + aggregated_log)
    
    // 对每个节点
    int i = 0
    while i < len(handles) {
        
        node_process_handle h = handles[i]
        string node_log = config.log_dir + "/node_" + itoa(h.node_id) + ".log"
        
        // 通过SCP下载日志
        string scp_cmd = "scp -i " + config.ssh_key_path +
                         " " + config.ssh_user + "@" + h.node_address +
                         ":" + node_log +
                         " " + config.log_dir + "/node_" + itoa(h.node_id) + "_local.log"
        
        print("[LOGS] Downloading log from node " + itoa(h.node_id))
        
        // 实际执行下载
        // exec_command(scp_cmd)
        
        i = i + 1
    }
    
    true
}

// ============================================
// 清理
// ============================================

// 终止所有节点的训练进程
func kill_cluster_training(
    []node_process_handle handles,
    cluster_config config,
) bool {
    
    print("[CLEANUP] Terminating all training processes...")
    
    int killed = 0
    
    int i = 0
    while i < len(handles) {
        
        node_process_handle h = handles[i]
        
        // SSH kill命令
        string cmd = "ssh -i " + config.ssh_key_path +
                     " " + config.ssh_user + "@" + h.node_address +
                     " kill -9 " + itoa(h.process_id)
        
        print("[CLEANUP] Killing process on node " + itoa(h.node_id))
        
        // 实际执行kill
        // exec_command(cmd)
        
        killed = killed + 1
        i = i + 1
    }
    
    print("[CLEANUP] Killed " + itoa(killed) + " processes")
    true
}

// ============================================
// 主函数
// ============================================

func main() {
    
    // 1. 解析集群配置
    cluster_config config = parse_cluster_config()
    
    // 2. 启动所有节点
    []node_process_handle handles = launch_cluster_training(config)
    
    print("[MAIN] Waiting for training to complete...")
    
    // 3. 监控进程
    sleep_seconds(300)  // 模拟运行5分钟
    
    handles = monitor_cluster_processes(handles, config)
    
    // 4. 收集日志
    collect_cluster_logs(handles, config)
    
    // 5. 清理
    kill_cluster_training(handles, config)
    
    print("[MAIN] Multi-node training completed!")
}

// ============================================
// 辅助函数
// ============================================

func split_string(string s, string sep) []string {
    []string parts = []string{cap: 10}
    int part_idx = 0
    int i = 0
    string current = ""
    
    while i < len(s) {
        if i + len(sep) <= len(s) {
            string substr = s[i : i + len(sep)]
            if substr == sep {
                parts[part_idx] = current
                part_idx = part_idx + 1
                current = ""
                i = i + len(sep)
                continue
            }
        }
        
        byte b = s[i]
        current = current + string(b)
        i = i + 1
    }
    
    if current != "" {
        parts[part_idx] = current
        part_idx = part_idx + 1
    }
    
    parts
}

func string_join([]string parts, string sep) string {
    string result = ""
    
    int i = 0
    while i < len(parts) {
        result = result + parts[i]
        if i < len(parts) - 1 {
            result = result + sep
        }
        i = i + 1
    }
    
    result
}

func parse_int(string s, int fallback) int {
    int result = 0
    int i = 0
    
    while i < len(s) {
        byte b = s[i]
        if b >= '0' && b <= '9' {
            result = result * 10 + int(b - '0')
        }
        i = i + 1
    }
    
    if result == 0 {
        result = fallback
    }
    result
}

func itoa(int n) string {
    if n == 0 {
        return "0"
    }
    
    string s = ""
    int num = n
    
    if num < 0 {
        s = "-"
        num = -num
    }
    
    while num > 0 {
        byte digit = byte('0' + (num % 10))
        s = string(digit) + s
        num = num / 10
    }
    
    s
}

func sleep_seconds(int seconds) {
    // 实际实现: time.Sleep()
}
