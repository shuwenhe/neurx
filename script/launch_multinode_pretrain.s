package neurx.script

// ============================================================================
// NeurX Multi-node Training Launcher (S Language Implementation)
// 
// 功能: 
//   1. 读取hostfile解析节点配置
//   2. 计算分布式训练的world_size
//   3. 生成NCCL唯一ID并同步
//   4. 为每个rank启动CUDA训练进程
//   5. 管理本地和远程(SSH)进程
// ============================================================================

use std.fs
use std.os
use std.process
use std.strings
use std.io

// ============================================================================
// 配置和常量
// ============================================================================

struct HostNode {
    string hostname
    int gpu_count
}

struct LauncherConfig {
    string root_dir
    string hostfile
    string master_addr
    int master_port
    string output_dir
    string nccl_id_file
    string shard_list_file
    
    // 模型参数
    int pretrain_steps
    int micro_batch
    int seq_len
    float learning_rate
    int log_interval
    int save_interval
    int transformer_dim
    int transformer_heads
    int transformer_ffn
    int transformer_layers
    int gradient_accumulation_steps
    string tokenizer_vocab
    string tokenizer_merges
}

struct ProcessInfo {
    int rank
    string hostname
    int local_rank
    int global_rank
    int process_id
}

// ============================================================================
// 环境变量处理
// ============================================================================

func get_env_or_default(string key, string default_val) string {
    string val = os::getenv(key)
    if val == "" {
        return default_val
    }
    return val
}

func get_env_int_or_default(string key, int default_val) int {
    string val = os::getenv(key)
    if val == "" {
        return default_val
    }
    return strings::parse_int(val)
}

func get_env_float_or_default(string key, float default_val) float {
    string val = os::getenv(key)
    if val == "" {
        return default_val
    }
    return strings::parse_float(val)
}

// ============================================================================
// 文件操作
// ============================================================================

func read_hostfile(string path) []HostNode {
    []HostNode nodes = []HostNode{}
    
    // 检查文件是否可读
    if !fs::exists(path) {
        io::eprintln("hostfile not found: " + path)
        return nodes
    }
    
    // 读取文件内容
    string content = fs::read_file(path)
    if content == "" {
        io::eprintln("hostfile is empty: " + path)
        return nodes
    }
    
    // 按行解析
    []string lines = strings::split(content, "\n")
    
    for i := 0; i < len(lines); i++ {
        string line = strings::trim(lines[i])
        
        // 跳过空行和注释
        if line == "" || strings::has_prefix(line, "#") {
            continue
        }
        
        // 解析 "hostname gpu_count"
        []string parts = strings::split(line, " ")
        if len(parts) < 1 {
            continue
        }
        
        string hostname = strings::trim(parts[0])
        int gpu_count = 0
        
        if len(parts) >= 2 {
            string gpu_str = strings::trim(parts[1])
            gpu_count = strings::parse_int(gpu_str)
        }
        
        if gpu_count <= 0 {
            gpu_count = count_gpus_local()
        }
        
        nodes.push(HostNode{hostname: hostname, gpu_count: gpu_count})
    }
    
    return nodes
}

func count_gpus_local() int {
    // 尝试使用nvidia-smi计算GPU数量
    // 这是简化实现，实际应该调用系统命令
    return 1  // 默认1个GPU
}

// ============================================================================
// NCCL ID处理
// ============================================================================

func write_nccl_id_file(string path, string id_data) bool {
    // 创建目录
    string dir = fs::dirname(path)
    if !fs::exists(dir) {
        fs::mkdir_all(dir)
    }
    
    // 写入临时文件
    string tmp_path = path + ".tmp"
    if !fs::write_file(tmp_path, id_data) {
        io::eprintln("cannot write NCCL id to: " + tmp_path)
        return false
    }
    
    // 原子性重命名
    if !fs::rename(tmp_path, path) {
        io::eprintln("cannot rename NCCL id file")
        return false
    }
    
    return true
}

func read_nccl_id_file(string path) string {
    if !fs::exists(path) {
        return ""
    }
    return fs::read_file(path)
}

// ============================================================================
// 配置初始化
// ============================================================================

func create_launcher_config() LauncherConfig {
    // 获取脚本目录
    string script_dir = os::working_dir()
    string root_dir = get_env_or_default("NEURX_ROOT", script_dir)
    
    // 读取配置
    LauncherConfig cfg
    cfg.root_dir = root_dir
    cfg.hostfile = get_env_or_default("NEURX_HOSTFILE", 
                                       root_dir + "/configs/pretrain.hosts")
    cfg.master_port = get_env_int_or_default("MASTER_PORT", 29500)
    cfg.output_dir = get_env_or_default("NEURX_PRETRAIN_OUTPUT_DIR",
                                         root_dir + "/checkpoint/NeurX-1.3")
    cfg.nccl_id_file = get_env_or_default("NEURX_SHARED_NCCL_ID_FILE",
                                           root_dir + "/artifacts/nccl/unique_id")
    cfg.shard_list_file = get_env_or_default("NEURX_PRETRAIN_SHARD_LIST_FILE",
                                              root_dir + "/artifacts/build/run_large_pretrain/shard_list.txt")
    
    // 模型参数
    cfg.pretrain_steps = get_env_int_or_default("NEURX_PRETRAIN_STEPS", 1000000000)
    cfg.micro_batch = get_env_int_or_default("NEURX_PRETRAIN_MICRO_BATCH", 1)
    cfg.seq_len = get_env_int_or_default("NEURX_PRETRAIN_SEQ_LEN", 256)
    cfg.learning_rate = get_env_float_or_default("NEURX_PRETRAIN_LR", 0.0002)
    cfg.log_interval = get_env_int_or_default("NEURX_PRETRAIN_LOG_INTERVAL", 10)
    cfg.save_interval = get_env_int_or_default("NEURX_PRETRAIN_SAVE_INTERVAL", 100)
    cfg.transformer_dim = get_env_int_or_default("NEURX_TRANSFORMER_DIM", 1024)
    cfg.transformer_heads = get_env_int_or_default("NEURX_TRANSFORMER_HEADS", 16)
    cfg.transformer_ffn = get_env_int_or_default("NEURX_TRANSFORMER_FFN", 4096)
    cfg.transformer_layers = get_env_int_or_default("NEURX_TRANSFORMER_NUM_LAYERS", 24)
    cfg.gradient_accumulation_steps = get_env_int_or_default("NEURX_GRADIENT_ACCUMULATION_STEPS", 8)
    cfg.tokenizer_vocab = get_env_or_default("NEURX_TOKENIZER_VOCAB",
                                              root_dir + "/data/corpus/vocab.json")
    cfg.tokenizer_merges = get_env_or_default("NEURX_TOKENIZER_MERGES",
                                               root_dir + "/data/corpus/merges.txt")
    
    return cfg
}

// ============================================================================
// 主启动逻辑
// ============================================================================

func launch_multinode_pretrain() int {
    // 1. 创建配置
    LauncherConfig cfg = create_launcher_config()
    
    // 2. 读取hostfile
    []HostNode nodes = read_hostfile(cfg.hostfile)
    if len(nodes) == 0 {
        io::eprintln("hostfile has no valid nodes: " + cfg.hostfile)
        return 2
    }
    
    // 3. 计算world_size
    int world_size = 0
    for i := 0; i < len(nodes); i++ {
        world_size += nodes[i].gpu_count
    }
    
    // 4. 确定master_addr
    string master_addr = get_env_or_default("MASTER_ADDR", nodes[0].hostname)
    
    // 5. 清理资源
    fs::remove_file(cfg.nccl_id_file)
    
    // 6. 创建输出目录
    if !fs::exists(cfg.output_dir) {
        fs::mkdir_all(cfg.output_dir)
    }
    
    // 7. 打印启动信息
    io::println("[multinode] nodes=" + strings::from_int(len(nodes)) + 
                " world_size=" + strings::from_int(world_size) + 
                " master=" + master_addr + ":" + strings::from_int(cfg.master_port))
    io::println("[multinode] shared NCCL id: " + cfg.nccl_id_file)
    
    // 8. 启动所有rank的训练进程
    []ProcessInfo processes = []ProcessInfo{}
    int global_rank = 0
    
    for node_idx := 0; node_idx < len(nodes); node_idx++ {
        HostNode node = nodes[node_idx]
        
        for local_rank := 0; local_rank < node.gpu_count; local_rank++ {
            // 构建环境变量
            []string env_vars = build_env_vars(cfg, master_addr, world_size, 
                                               global_rank, node.gpu_count, 
                                               len(nodes))
            
            // 构建命令
            string cmd = build_command(cfg, global_rank, local_rank, node.gpu_count, 
                                       len(nodes))
            
            // 启动进程
            int pid = launch_process(node.hostname, cfg.root_dir, cmd, env_vars, 
                                     cfg.output_dir, global_rank, len(nodes) == 1)
            
            if pid > 0 {
                ProcessInfo proc
                proc.rank = global_rank
                proc.hostname = node.hostname
                proc.local_rank = local_rank
                proc.global_rank = global_rank
                proc.process_id = pid
                processes.push(proc)
                
                io::println("[multinode] rank=" + strings::from_int(global_rank) + 
                           " host=" + node.hostname + " local_rank=" + strings::from_int(local_rank))
            }
            
            global_rank++
        }
    }
    
    // 9. 等待所有进程完成
    int exit_code = 0
    for i := 0; i < len(processes); i++ {
        ProcessInfo proc = processes[i]
        int status = process::wait(proc.process_id)
        if status != 0 {
            exit_code = status
        }
    }
    
    return exit_code
}

// ============================================================================
// 辅助函数
// ============================================================================

func build_env_vars(LauncherConfig cfg, string master_addr, int world_size,
                    int rank, int local_gpus, int num_nodes) []string {
    []string env_vars = []string{}
    
    env_vars.push("NEURX_ROOT=" + cfg.root_dir)
    env_vars.push("NEURX_PRETRAIN_OUTPUT_DIR=" + cfg.output_dir)
    env_vars.push("NEURX_NCCL_ID_FILE=" + cfg.nccl_id_file)
    env_vars.push("NEURX_PRETRAIN_SHARD_LIST_FILE=" + cfg.shard_list_file)
    env_vars.push("NEURX_PRETRAIN_STEPS=" + strings::from_int(cfg.pretrain_steps))
    env_vars.push("NEURX_PRETRAIN_MICRO_BATCH=" + strings::from_int(cfg.micro_batch))
    env_vars.push("NEURX_PRETRAIN_SEQ_LEN=" + strings::from_int(cfg.seq_len))
    env_vars.push("NEURX_PRETRAIN_LR=" + strings::from_float(cfg.learning_rate))
    env_vars.push("NEURX_PRETRAIN_LOG_INTERVAL=" + strings::from_int(cfg.log_interval))
    env_vars.push("NEURX_PRETRAIN_SAVE_INTERVAL=" + strings::from_int(cfg.save_interval))
    env_vars.push("NEURX_TRANSFORMER_DIM=" + strings::from_int(cfg.transformer_dim))
    env_vars.push("NEURX_TRANSFORMER_HEADS=" + strings::from_int(cfg.transformer_heads))
    env_vars.push("NEURX_TRANSFORMER_FFN=" + strings::from_int(cfg.transformer_ffn))
    env_vars.push("NEURX_TRANSFORMER_NUM_LAYERS=" + strings::from_int(cfg.transformer_layers))
    env_vars.push("NEURX_GRADIENT_ACCUMULATION_STEPS=" + strings::from_int(cfg.gradient_accumulation_steps))
    env_vars.push("NEURX_TOKENIZER_VOCAB=" + cfg.tokenizer_vocab)
    env_vars.push("NEURX_TOKENIZER_MERGES=" + cfg.tokenizer_merges)
    env_vars.push("MASTER_ADDR=" + master_addr)
    env_vars.push("MASTER_PORT=" + strings::from_int(cfg.master_port))
    env_vars.push("WORLD_SIZE=" + strings::from_int(world_size))
    env_vars.push("RANK=" + strings::from_int(rank))
    env_vars.push("LOCAL_RANK=" + strings::from_int(rank % local_gpus))
    env_vars.push("CUDA_VISIBLE_DEVICES=" + strings::from_int(rank % local_gpus))
    
    return env_vars
}

func build_command(LauncherConfig cfg, int rank, int local_rank, 
                   int local_gpus, int num_nodes) string {
    // 根据节点数判断是否需要rank目录后缀
    string ckpt_path = cfg.output_dir + "/transformer_v2.ckpt"
    if num_nodes > 1 {
        ckpt_path = cfg.output_dir + "/rank_" + strings::from_int(rank) + "/transformer_v2.ckpt"
    }
    
    string cmd = cfg.root_dir + "/artifacts/build/cuda_train/neurx_cuda_train_bridge"
    cmd += " NEURX_PRETRAIN_RESUME_FROM=" + ckpt_path
    
    return cmd
}

func launch_process(string hostname, string root_dir, string cmd, 
                    []string env_vars, string output_dir, int rank, bool is_local) int {
    // 构建完整的命令行
    string full_cmd = build_full_command(cmd, env_vars, output_dir, rank, is_local)
    
    if is_local {
        // 本地启动
        if is_local {
            // 单节点: 实时显示输出
            full_cmd = full_cmd + " 2>&1 | tee -a " + output_dir + "/rank_" + strings::from_int(rank) + ".log &"
        } else {
            // 多节点: 后台运行
            full_cmd = full_cmd + " >" + output_dir + "/rank_" + strings::from_int(rank) + ".log 2>&1 &"
        }
    } else {
        // 远程SSH启动
        full_cmd = "ssh " + hostname + " 'cd " + root_dir + " && " + full_cmd + 
                   " >" + output_dir + "/rank_" + strings::from_int(rank) + ".log 2>&1' &"
    }
    
    // 执行命令（S语言通过os::execute或system调用）
    int pid = os::execute(full_cmd)
    return pid
}

func build_full_command(string cmd, []string env_vars, string output_dir, 
                        int rank, bool show_output) string {
    string full = ""
    
    // 添加环境变量
    for i := 0; i < len(env_vars); i++ {
        full = full + "export " + env_vars[i] + "; "
    }
    
    // 添加实际命令
    full = full + cmd
    
    return full
}

// ============================================================================
// 主函数
// ============================================================================

func main() {
    int exit_code = launch_multinode_pretrain()
    os::exit(exit_code)
}
