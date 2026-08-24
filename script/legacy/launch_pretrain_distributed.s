package main
use neurx.runtime.io.{runtime_env_get, runtime_env_set, create_directory, file_exists}
use neurx.runtime.process.{exec_process, exec_process_async, wait_process}
use neurx.strings.{trim, string_concat, starts_with}

struct launcher_config {
    int num_gpus
    string master_addr
    int master_port
    string config_path
    string model_path
    string dataset_path
    int micro_batch_size
    int gradient_accum_steps
    int num_epochs
    string log_dir
    string log_file
    bool verbose
}

struct gpu_info {
    int device_id
    string name
    int memory_mb
    bool available
}

func parse_args() launcher_config {
    string num_gpus_str = runtime_env_get("NUM_GPUS", "1")
    int num_gpus = parse_int(num_gpus_str)
    if num_gpus < 1 {
        num_gpus = 1
    }
    string master_addr = runtime_env_get("MASTER_ADDR", "localhost")
    string master_port_str = runtime_env_get("MASTER_PORT", "29500")
    int master_port = parse_int(master_port_str)
    if master_port < 1024 {
        master_port = 29500
    }
    launcher_config {
        num_gpus: num_gpus,
        master_addr: master_addr,
        master_port: master_port,
        config_path: "./pretrain/pretrain_config.toml",
        model_path: "./checkpoint/NeurX-1.3/NeurX-1.3.neurx",
        dataset_path: "./dataset/pretrain/shard",
        micro_batch_size: 8,
        gradient_accum_steps: 8,
        num_epochs: 1,
        log_dir: "./artifacts/logs/distributed_pretrain",
        log_file: "",
        verbose: true,
    }
}

func query_gpu_info() []gpu_info {
    []gpu_info gpus = []gpu_info{cap: 16}
    gpu_info gpu0 = gpu_info {
        device_id: 0,
        name: "NVIDIA RTX 4090",
        memory_mb: 24576,
        available: true,
    }
    gpus[0] = gpu0
    gpus
}

func check_gpu_availability(int num_gpus) (bool, int) {
    []gpu_info gpus = query_gpu_info()
    int available_count = 0
    int i = 0
    while i < len(gpus) {
        if gpus[i].available {
            available_count = available_count + 1
        }
        i = i + 1
    }
    bool sufficient = available_count >= num_gpus
    (sufficient, available_count)
}

func setup_directories(launcher_config config) bool {
    if !create_directory(config.log_dir) {
        print("[ERROR] Failed to create log directory: " + config.log_dir)
        return false
    }
    if !create_directory("src/training/checkpoint/NeurX-1.3") {
        print("[ERROR] Failed to create checkpoint directory")
        return false
    }
    if !create_directory("artifacts/logs") {
        print("[ERROR] Failed to create artifacts directory")
        return false
    }
    true
}

func print_config(launcher_config config) {
    print("==================================================")
    print("NeurX Distributed Pretraining")
    print("==================================================")
    print("[CONFIG] NUM_GPUS: " + itoa(config.num_gpus))
    print("[CONFIG] MASTER_ADDR: " + config.master_addr)
    print("[CONFIG] MASTER_PORT: " + itoa(config.master_port))
    print("[CONFIG] CONFIG_PATH: " + config.config_path)
    print("[CONFIG] MODEL_PATH: " + config.model_path)
    print("[CONFIG] DATASET_PATH: " + config.dataset_path)
    print("[CONFIG] MICRO_BATCH_SIZE: " + itoa(config.micro_batch_size))
    print("[CONFIG] GRADIENT_ACCUM_STEPS: " + itoa(config.gradient_accum_steps))
    print("[CONFIG] NUM_EPOCHS: " + itoa(config.num_epochs))
    print("[CONFIG] LOG_DIR: " + config.log_dir)
    print("[CONFIG] LOG_FILE: " + config.log_file)
    print("==================================================")
}

struct process_handle {
    int rank
    int pid
    string log_file
    bool running
}

func launch_rank_process(
    launcher_config config,
    int rank,
    int world_size,
) process_handle {
    runtime_env_set("RANK", itoa(rank))
    runtime_env_set("LOCAL_RANK", itoa(rank))
    runtime_env_set("WORLD_SIZE", itoa(world_size))
    runtime_env_set("MASTER_ADDR", config.master_addr)
    runtime_env_set("MASTER_PORT", itoa(config.master_port))
    string cmd = "./pretrain/distributed_pretrain_entry.s " +
                 "--config=" + config.config_path +
                 " --model_path=" + config.model_path +
                 " --dataset_path=" + config.dataset_path +
                 " --micro_batch_size=" + itoa(config.micro_batch_size) +
                 " --gradient_accum_steps=" + itoa(config.gradient_accum_steps) +
                 " --epochs=" + itoa(config.num_epochs) +
                 " --rank=" + itoa(rank) +
                 " --world_size=" + itoa(world_size)
    string log_file = config.log_dir + "/rank_" + itoa(rank) + ".log"
    int pid = exec_process_async(cmd, log_file)
    process_handle {
        rank: rank,
        pid: pid,
        log_file: log_file,
        running: pid > 0,
    }
}

func launch_all_processes(
    launcher_config config,
    int world_size,
) []process_handle {
    []process_handle handles = []process_handle{cap: world_size}
    int rank = 0
    while rank < world_size {
        process_handle handle = launch_rank_process(config, rank, world_size)
        handles[rank] = handle
        if config.verbose {
            print("[INFO] Launched rank " + itoa(rank) + " with PID " + itoa(handle.pid))
        }
        rank = rank + 1
    }
    handles
}

func wait_all_processes(
    []process_handle handles,
) int {
    int overall_exit_code = 0
    int rank = 0
    while rank < len(handles) {
        process_handle handle = handles[rank]
        if handle.running {
            print("[INFO] Waiting for rank " + itoa(handle.rank) + " (PID " + itoa(handle.pid) + ")...")
            int exit_code = wait_process(handle.pid)
            if exit_code != 0 {
                print("[ERROR] Rank " + itoa(handle.rank) + " exited with code " + itoa(exit_code))
                overall_exit_code = exit_code
            } else {
                print("[SUCCESS] Rank " + itoa(handle.rank) + " completed successfully")
            }
        }
        rank = rank + 1
    }
    overall_exit_code
}

func aggregate_logs(launcher_config config, []process_handle handles) {
    print("[INFO] Aggregating logs from all ranks...")
    int rank = 0
    while rank < len(handles) {
        string rank_log = handles[rank].log_file
        if file_exists(rank_log) {
            print("[INFO] Rank " + itoa(rank) + " log: " + rank_log)
        }
        rank = rank + 1
    }
}

func print_final_stats(launcher_config config, int exit_code) {
    print("==================================================")
    if exit_code == 0 {
        print("[SUCCESS] Distributed Pretraining Completed!")
    } else {
        print("[ERROR] Distributed Pretraining Failed")
        print("[ERROR] Exit code: " + itoa(exit_code))
    }
    print("==================================================")
    print("[INFO] model saved to: " + config.model_path)
    print("[INFO] Logs saved to: " + config.log_dir)
    print("[INFO] Check logs for details: " + config.log_file)
    print("==================================================")
}

func main() {
    launcher_config config = parse_args()
    string timestamp = get_timestamp()
    config.log_file = config.log_dir + "/pretrain_" + timestamp + ".log"
    print_config(config)
    print("[INFO] Checking GPU availability...")
    (bool sufficient, int available_gpus) := check_gpu_availability(config.num_gpus)
    print("[INFO] Requested GPUs: " + itoa(config.num_gpus))
    print("[INFO] Available GPUs: " + itoa(available_gpus))
    if !sufficient {
        print("[ERROR] Insufficient GPUs available!")
        exit(1)
    }
    if !setup_directories(config) {
        print("[ERROR] Failed to setup directories")
        exit(1)
    }
    print("[INFO] Launching " + itoa(config.num_gpus) + " training processes...")
    []process_handle handles = launch_all_processes(config, config.num_gpus)
    print("[INFO] All processes started. Waiting for completion...")
    int exit_code = wait_all_processes(handles)
    aggregate_logs(config, handles)
    print_final_stats(config, exit_code)
    exit(exit_code)
}

func parse_int(string s) int {
    int result = 0
    int i = 0
    while i < len(s) {
        byte b = s[i]
        if b >= '0' && b <= '9' {
            result = result * 10 + int(b - '0')
        }
        i = i + 1
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

func get_timestamp() string {
    "20260714_161200"
}

func exit(int code) {
}
