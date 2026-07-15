package neurx.script

// ============================================================================
// NeurX Multi-node Launcher Generator (S Language)
// 
// 功能: 使用S语言生成优化的shell启动脚本
// 优势: 配置管理、参数校验在S语言中完成，最后生成高效的shell脚本
// ============================================================================

use std.fs
use std.os
use std.strings

// ============================================================================
// 配置数据结构
// ============================================================================

struct TrainingConfig {
    // 系统配置
    string root_dir
    string hostfile
    string output_dir
    string master_addr
    int master_port
    string nccl_id_file
    int num_nodes
    int world_size
    
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
    
    // Tokenizer
    string tokenizer_vocab
    string tokenizer_merges
    string shard_list_file
}

// ============================================================================
// 配置解析
// ============================================================================

func load_config_from_env() TrainingConfig {
    TrainingConfig cfg
    
    // 获取NEURX_ROOT
    string root = os::getenv("NEURX_ROOT")
    if root == "" {
        root = os::working_dir()
    }
    cfg.root_dir = root
    
    // 获取hostfile
    cfg.hostfile = os::getenv("NEURX_HOSTFILE")
    if cfg.hostfile == "" {
        cfg.hostfile = root + "/configs/pretrain.hosts"
    }
    
    // 获取输出目录
    cfg.output_dir = os::getenv("NEURX_PRETRAIN_OUTPUT_DIR")
    if cfg.output_dir == "" {
        cfg.output_dir = root + "/checkpoint/NeurX-1.3"
    }
    
    // 获取NCCL ID文件路径
    cfg.nccl_id_file = os::getenv("NEURX_SHARED_NCCL_ID_FILE")
    if cfg.nccl_id_file == "" {
        cfg.nccl_id_file = root + "/artifacts/nccl/unique_id"
    }
    
    // 获取master地址
    cfg.master_addr = os::getenv("MASTER_ADDR")
    if cfg.master_addr == "" {
        cfg.master_addr = "localhost"
    }
    
    // 获取master端口
    string port_str = os::getenv("MASTER_PORT")
    if port_str != "" {
        cfg.master_port = strings::parse_int(port_str)
    } else {
        cfg.master_port = 29500
    }
    
    // 模型参数
    cfg.pretrain_steps = parse_env_int("NEURX_PRETRAIN_STEPS", 1000000000)
    cfg.micro_batch = parse_env_int("NEURX_PRETRAIN_MICRO_BATCH", 1)
    cfg.seq_len = parse_env_int("NEURX_PRETRAIN_SEQ_LEN", 256)
    cfg.learning_rate = parse_env_float("NEURX_PRETRAIN_LR", 0.0002)
    cfg.log_interval = parse_env_int("NEURX_PRETRAIN_LOG_INTERVAL", 10)
    cfg.save_interval = parse_env_int("NEURX_PRETRAIN_SAVE_INTERVAL", 100)
    cfg.transformer_dim = parse_env_int("NEURX_TRANSFORMER_DIM", 1024)
    cfg.transformer_heads = parse_env_int("NEURX_TRANSFORMER_HEADS", 16)
    cfg.transformer_ffn = parse_env_int("NEURX_TRANSFORMER_FFN", 4096)
    cfg.transformer_layers = parse_env_int("NEURX_TRANSFORMER_NUM_LAYERS", 24)
    cfg.gradient_accumulation_steps = parse_env_int("NEURX_GRADIENT_ACCUMULATION_STEPS", 8)
    
    // Tokenizer
    cfg.tokenizer_vocab = os::getenv("NEURX_TOKENIZER_VOCAB")
    if cfg.tokenizer_vocab == "" {
        cfg.tokenizer_vocab = root + "/data/corpus/vocab.json"
    }
    
    cfg.tokenizer_merges = os::getenv("NEURX_TOKENIZER_MERGES")
    if cfg.tokenizer_merges == "" {
        cfg.tokenizer_merges = root + "/data/corpus/merges.txt"
    }
    
    cfg.shard_list_file = os::getenv("NEURX_PRETRAIN_SHARD_LIST_FILE")
    if cfg.shard_list_file == "" {
        cfg.shard_list_file = root + "/artifacts/build/run_large_pretrain/shard_list.txt"
    }
    
    return cfg
}

func parse_env_int(string key, int default_val) int {
    string val = os::getenv(key)
    if val == "" {
        return default_val
    }
    return strings::parse_int(val)
}

func parse_env_float(string key, float default_val) float {
    string val = os::getenv(key)
    if val == "" {
        return default_val
    }
    return strings::parse_float(val)
}

// ============================================================================
// Hostfile 解析
// ============================================================================

func parse_hostfile(string hostfile_path) []string {
    []string hosts = []string{}
    
    if !fs::exists(hostfile_path) {
        io::eprintln("hostfile not found: " + hostfile_path)
        return hosts
    }
    
    string content = fs::read_file(hostfile_path)
    []string lines = strings::split(content, "\n")
    
    for i := 0; i < len(lines); i++ {
        string line = strings::trim(lines[i])
        
        // 跳过空行和注释
        if line == "" || strings::has_prefix(line, "#") {
            continue
        }
        
        // 提取主机名和GPU数
        []string parts = strings::split(line, " ")
        if len(parts) >= 1 {
            hosts.push(line)
        }
    }
    
    return hosts
}

// ============================================================================
// Shell脚本生成
// ============================================================================

func generate_launcher_script(TrainingConfig cfg, []string hosts) string {
    string script = ""
    
    // 添加脚本头
    script = script + "#!/usr/bin/env bash\n"
    script = script + "set -Eeuo pipefail\n"
    script = script + "\n"
    script = script + "# Auto-generated by NeurX Launcher (S Language)\n"
    script = script + "# Config: " + cfg.root_dir + "\n"
    script = script + "\n"
    
    // 添加变量定义
    script = script + "# Configuration\n"
    script = script + "ROOT=\"" + cfg.root_dir + "\"\n"
    script = script + "HOSTFILE=\"" + cfg.hostfile + "\"\n"
    script = script + "OUT=\"" + cfg.output_dir + "\"\n"
    script = script + "SHARED_ID=\"" + cfg.nccl_id_file + "\"\n"
    script = script + "MASTER_ADDR=\"" + cfg.master_addr + "\"\n"
    script = script + "MASTER_PORT=" + strings::from_int(cfg.master_port) + "\n"
    script = script + "\n"
    
    // 添加环境变量数组
    script = script + "# Base environment variables\n"
    script = script + "declare -a base_env=(\n"
    script = script + "  \"NEURX_ROOT=$ROOT\"\n"
    script = script + "  \"NEURX_PRETRAIN_OUTPUT_DIR=$OUT\"\n"
    script = script + "  \"NEURX_NCCL_ID_FILE=$SHARED_ID\"\n"
    script = script + "  \"NEURX_PRETRAIN_SHARD_LIST_FILE=" + cfg.shard_list_file + "\"\n"
    script = script + "  \"NEURX_PRETRAIN_STEPS=" + strings::from_int(cfg.pretrain_steps) + "\"\n"
    script = script + "  \"NEURX_PRETRAIN_MICRO_BATCH=" + strings::from_int(cfg.micro_batch) + "\"\n"
    script = script + "  \"NEURX_PRETRAIN_SEQ_LEN=" + strings::from_int(cfg.seq_len) + "\"\n"
    script = script + "  \"NEURX_PRETRAIN_LR=" + strings::from_float(cfg.learning_rate) + "\"\n"
    script = script + "  \"NEURX_PRETRAIN_LOG_INTERVAL=" + strings::from_int(cfg.log_interval) + "\"\n"
    script = script + "  \"NEURX_PRETRAIN_SAVE_INTERVAL=" + strings::from_int(cfg.save_interval) + "\"\n"
    script = script + "  \"NEURX_TRANSFORMER_DIM=" + strings::from_int(cfg.transformer_dim) + "\"\n"
    script = script + "  \"NEURX_TRANSFORMER_HEADS=" + strings::from_int(cfg.transformer_heads) + "\"\n"
    script = script + "  \"NEURX_TRANSFORMER_FFN=" + strings::from_int(cfg.transformer_ffn) + "\"\n"
    script = script + "  \"NEURX_TRANSFORMER_NUM_LAYERS=" + strings::from_int(cfg.transformer_layers) + "\"\n"
    script = script + "  \"NEURX_GRADIENT_ACCUMULATION_STEPS=" + strings::from_int(cfg.gradient_accumulation_steps) + "\"\n"
    script = script + "  \"NEURX_TOKENIZER_VOCAB=" + cfg.tokenizer_vocab + "\"\n"
    script = script + "  \"NEURX_TOKENIZER_MERGES=" + cfg.tokenizer_merges + "\"\n"
    script = script + "  \"MASTER_ADDR=$MASTER_ADDR\"\n"
    script = script + "  \"MASTER_PORT=$MASTER_PORT\"\n"
    script = script + "  \"WORLD_SIZE=" + strings::from_int(cfg.world_size) + "\"\n"
    script = script + ")\n"
    script = script + "\n"
    
    // 添加主循环
    script = script + "# Cleanup function\n"
    script = script + "declare -a PIDS=()\n"
    script = script + "cleanup() {\n"
    script = script + "  trap - EXIT INT TERM\n"
    script = script + "  for pid in \"${PIDS[@]:-}\"; do kill \"$pid\" 2>/dev/null || true; done\n"
    script = script + "}\n"
    script = script + "trap cleanup EXIT INT TERM\n"
    script = script + "\n"
    
    script = script + "# Create output directories\n"
    script = script + "mkdir -p \"$(dirname \"$SHARED_ID\")\" \"$OUT\"\n"
    script = script + "rm -f \"$SHARED_ID\" \"$SHARED_ID.tmp\"\n"
    script = script + "\n"
    
    script = script + "echo \"[multinode] nodes=" + strings::from_int(len(hosts)) + 
                      " world_size=" + strings::from_int(cfg.world_size) + 
                      " master=${MASTER_ADDR}:${MASTER_PORT}\"\n"
    script = script + "echo \"[multinode] shared NCCL id: $SHARED_ID\"\n"
    script = script + "\n"
    
    // 添加rank启动循环
    script = script + "# Launch processes\n"
    script = script + "rank=0\n"
    script = script + "for node in " + generate_hosts_array(hosts) + "; do\n"
    script = script + "  host=\"${node%% *}\"; gpus=\"${node#* }\"\n"
    script = script + "  if [[ \"$gpus\" == \"$node\" || ! \"$gpus\" =~ ^[0-9]+$ ]]; then\n"
    script = script + "    gpus=\"$(nvidia-smi -L 2>/dev/null | wc -l)\"\n"
    script = script + "  fi\n"
    script = script + "  for ((local=0; local<gpus; local++)); do\n"
    script = script + "    # A single rank writes directly under OUT; distributed ranks use rank_N.\n"
    script = script + "    if (( world == 1 )); then\n"
    script = script + "      ckpt_path=\"$OUT/transformer_v2.ckpt\"\n"
    script = script + "    else\n"
    script = script + "      ckpt_path=\"$OUT/rank_${rank}/transformer_v2.ckpt\"\n"
    script = script + "    fi\n"
    script = script + "    cmd=(\"env\" \"${base_env[@]}\" \"RANK=$rank\" \"LOCAL_RANK=$local\"\n"
    script = script + "      \"CUDA_VISIBLE_DEVICES=$local\"\n"
    script = script + "      \"NEURX_PRETRAIN_RESUME_FROM=$ckpt_path\"\n"
    script = script + "      \"$ROOT/artifacts/build/cuda_train/neurx_cuda_train_bridge\")\n"
    script = script + "    echo \"[multinode] rank=$rank host=$host local_rank=$local checkpoint=$ckpt_path\"\n"
    script = script + "    if [[ \"$host\" == \"localhost\" || \"$host\" == \"127.0.0.1\" || \"$host\" == \"$(hostname)\" ]]; then\n"
    script = script + "      \"${cmd[@]}\" 2>&1 | tee -a \"${OUT}/rank_${rank}.log\" &\n"
    script = script + "    else\n"
    script = script + "      printf -v remote_cmd '%q ' \"${cmd[@]}\"\n"
    script = script + "      ssh \"$host\" \"cd $(printf '%q' \"$ROOT\") && $remote_cmd\" >\"${OUT}/rank_${rank}.log\" 2>&1 &\n"
    script = script + "    fi\n"
    script = script + "    PIDS+=(\"$!\")\n"
    script = script + "    rank=$((rank + 1))\n"
    script = script + "  done\n"
    script = script + "done\n"
    script = script + "\n"
    
    script = script + "# Wait for all processes\n"
    script = script + "status=0\n"
    script = script + "for pid in \"${PIDS[@]}\"; do wait \"$pid\" || status=$?; done\n"
    script = script + "exit \"$status\"\n"
    
    return script
}

func generate_hosts_array([]string hosts) string {
    string result = ""
    for i := 0; i < len(hosts); i++ {
        if i > 0 {
            result = result + " "
        }
        result = result + "\"" + hosts[i] + "\""
    }
    return result
}

// ============================================================================
// 主函数
// ============================================================================

func main() {
    // 1. 加载配置
    TrainingConfig cfg = load_config_from_env()
    
    // 2. 解析hostfile
    []string hosts = parse_hostfile(cfg.hostfile)
    if len(hosts) == 0 {
        io::eprintln("ERROR: no valid hosts in hostfile")
        os::exit(2)
    }
    
    // 3. 计算world_size
    cfg.num_nodes = len(hosts)
    cfg.world_size = 0
    for i := 0; i < len(hosts); i++ {
        // 简化: 假设每个主机的GPU数
        // 实际应该解析"host num_gpus"格式
        cfg.world_size = cfg.world_size + 1  // 默认1个GPU
    }
    
    // 4. 生成脚本
    string script = generate_launcher_script(cfg, hosts)
    
    // 5. 输出脚本到文件
    string output_script = cfg.root_dir + "/script/launch_multinode_pretrain_generated.sh"
    if !fs::write_file(output_script, script) {
        io::eprintln("ERROR: cannot write script to " + output_script)
        os::exit(1)
    }
    
    io::println("✓ Generated launcher script: " + output_script)
    
    // 6. 让脚本可执行
    os::chmod(output_script, 0755)
    
    io::println("✓ Ready to launch: bash " + output_script)
}
