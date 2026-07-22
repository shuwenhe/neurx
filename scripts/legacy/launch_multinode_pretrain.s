package main












use std.fs
use std.os
use std.process
use std.strings
use std.io





struct host_node {
    string hostname
    int gpu_count
}

struct launcher_config {
    string root_dir
    string hostfile
    string master_addr
    int master_port
    string output_dir
    string nccl_id_file
    string shard_list_file


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

struct process_info {
    int rank
    string hostname
    int local_rank
    int global_rank
    int process_id
}





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





func read_hostfile(string path) []host_node {
    []host_node nodes = []host_node{}


    if !fs::exists(path) {
        io::eprintln("hostfile not found: " + path)
        return nodes
    }


    string content = fs::read_file(path)
    if content == "" {
        io::eprintln("hostfile is empty: " + path)
        return nodes
    }


    []string lines = strings::split(content, "\n")

    for i := 0; i < len(lines); i++ {
        string line = strings::trim(lines[i])


        if line == "" || strings::has_prefix(line, "#") {
            continue
        }


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

        nodes.push(host_node{hostname: hostname, gpu_count: gpu_count})
    }

    return nodes
}

func count_gpus_local() int {


    return 1
}





func write_nccl_id_file(string path, string id_data) bool {

    string dir = fs::dirname(path)
    if !fs::exists(dir) {
        fs::mkdir_all(dir)
    }


    string tmp_path = path + ".tmp"
    if !fs::write_file(tmp_path, id_data) {
        io::eprintln("cannot write NCCL id to: " + tmp_path)
        return false
    }


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





func create_launcher_config() launcher_config {

    string script_dir = os::working_dir()
    string root_dir = get_env_or_default("NEURX_ROOT", script_dir)


    launcher_config cfg
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





func launch_multinode_pretrain() int {

    launcher_config cfg = create_launcher_config()


    []host_node nodes = read_hostfile(cfg.hostfile)
    if len(nodes) == 0 {
        io::eprintln("hostfile has no valid nodes: " + cfg.hostfile)
        return 2
    }


    int world_size = 0
    for i := 0; i < len(nodes); i++ {
        world_size += nodes[i].gpu_count
    }


    string master_addr = get_env_or_default("MASTER_ADDR", nodes[0].hostname)


    fs::remove_file(cfg.nccl_id_file)


    if !fs::exists(cfg.output_dir) {
        fs::mkdir_all(cfg.output_dir)
    }


    io::println("[multinode] nodes=" + strings::from_int(len(nodes)) +
                " world_size=" + strings::from_int(world_size) +
                " master=" + master_addr + ":" + strings::from_int(cfg.master_port))
    io::println("[multinode] shared NCCL id: " + cfg.nccl_id_file)


    []process_info processes = []process_info{}
    int global_rank = 0

    for node_idx := 0; node_idx < len(nodes); node_idx++ {
        host_node node = nodes[node_idx]

        for local_rank := 0; local_rank < node.gpu_count; local_rank++ {

            []string env_vars = build_env_vars(cfg, master_addr, world_size,
                                               global_rank, node.gpu_count,
                                               len(nodes))


            string cmd = build_command(cfg, global_rank, local_rank, node.gpu_count,
                                       len(nodes))


            int pid = launch_process(node.hostname, cfg.root_dir, cmd, env_vars,
                                     cfg.output_dir, global_rank, len(nodes) == 1)

            if pid > 0 {
                process_info proc
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


    int exit_code = 0
    for i := 0; i < len(processes); i++ {
        process_info proc = processes[i]
        int status = process::wait(proc.process_id)
        if status != 0 {
            exit_code = status
        }
    }

    return exit_code
}





func build_env_vars(launcher_config cfg, string master_addr, int world_size,
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

func build_command(launcher_config cfg, int rank, int local_rank,
                   int local_gpus, int num_nodes) string {

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

    string full_cmd = build_full_command(cmd, env_vars, output_dir, rank, is_local)

    if is_local {

        if is_local {

            full_cmd = full_cmd + " 2>&1 | tee -a " + output_dir + "/rank_" + strings::from_int(rank) + ".log &"
        } else {

            full_cmd = full_cmd + " >" + output_dir + "/rank_" + strings::from_int(rank) + ".log 2>&1 &"
        }
    } else {

        full_cmd = "ssh " + hostname + " 'cd " + root_dir + " && " + full_cmd +
                   " >" + output_dir + "/rank_" + strings::from_int(rank) + ".log 2>&1' &"
    }


    int pid = os::execute(full_cmd)
    return pid
}

func build_full_command(string cmd, []string env_vars, string output_dir,
                        int rank, bool show_output) string {
    string full = ""


    for i := 0; i < len(env_vars); i++ {
        full = full + "export " + env_vars[i] + "; "
    }


    full = full + cmd

    return full
}





func main() int {
    return launch_multinode_pretrain()
}
