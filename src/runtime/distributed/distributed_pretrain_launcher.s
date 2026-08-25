package neurx.distributed.launcher
use neurx.strings
use neurx.distributed.comm
use neurx.distributed.ddp
use neurx.distributed.cuda_bridge
use neurx.runtime.io.{runtime_env_get}

struct distributed_env {
    int world_size
    int rank
    int local_rank
    string master_addr
    int master_port
    string backend
    int num_gpus
}

struct distributed_pretrain_launcher {
    distributed_env env
    process_group_state pg_state
    ddp_state ddp_state
    cuda_bridge cb
    []string shard_paths
    int micro_batch_size
    int gradient_accum_steps
}

func init_distributed_env() distributed_env {
    string world_size_str = runtime_env_get("WORLD_SIZE", "1")
    string rank_str = runtime_env_get("RANK", "0")
    string local_rank_str = runtime_env_get("LOCAL_RANK", "0")
    string master_addr = runtime_env_get("MASTER_ADDR", "localhost")
    string master_port_str = runtime_env_get("MASTER_PORT", "29500")
    int world_size = parse_int(world_size_str)
    int rank = parse_int(rank_str)
    int local_rank = parse_int(local_rank_str)
    int master_port = parse_int(master_port_str)
    if world_size < 1 {
        world_size = 1
    }
    if rank < 0 || rank >= world_size {
        rank = 0
    }
    if local_rank < 0 {
        local_rank = 0
    }
    if master_port < 1024 || master_port > 65535 {
        master_port = 29500
    }
    distributed_env {
        world_size: world_size,
        rank: rank,
        local_rank: local_rank,
        master_addr: master_addr,
        master_port: master_port,
        backend: "nccl",
        num_gpus: world_size,
    }
}

func parse_int(string s) int {
    int result = 0
    int i = 0
    for i < len(s) {
        byte b = s[i]
        if b >= '0' && b <= '9' {
            result = result * 10 + int(b - '0')
        }
        i = i + 1
    }
    result
}

func new_distributed_pretrain_launcher(
    config_path string,
    micro_batch_size int,
    gradient_accum_steps int,
) distributed_pretrain_launcher {
    distributed_env env = init_distributed_env()
    process_group_state pg = new_process_group(
        env.world_size,
        env.rank,
        env.master_addr,
        env.master_port,
        env.backend,
    )
    ddp_state ddp = new_ddp_state(
        "neurx_ddp",
        env.backend,
        env.rank,
        env.world_size,
        false,
    )
    ddp_attach_process_group(ddp, pg)
    cuda_bridge cb = new_cuda_bridge(
        env.rank,
        env.local_rank,
        env.world_size,
        env.backend,
    )
    []string shard_paths = generate_shard_distribution(
        config_path,
        env.rank,
        env.world_size,
    )
    distributed_pretrain_launcher {
        env: env,
        pg_state: pg,
        ddp_state: ddp,
        cb: cb,
        shard_paths: shard_paths,
        micro_batch_size: micro_batch_size,
        gradient_accum_steps: gradient_accum_steps,
    }
}

func generate_shard_distribution(
    config_path string,
    rank int,
    world_size int,
) []string {
    []string all_shards = load_shard_list(config_path)
    []string my_shards = []string{cap: (len(all_shards) / world_size) + 1}
    int shard_idx = 0
    int i = rank
    for i < len(all_shards) {
        my_shards[shard_idx] = all_shards[i]
        shard_idx = shard_idx + 1
        i = i + world_size
    }
    my_shards
}

func load_shard_list(string config_path) []string {
    []string shards = []string{cap: 5131}
    int i = 0
    for i < 5131 {
        string shard_path = format_string(
            "dataset/pretrain/shard/shard_%05d.jsonl",
            i,
        )
        shards[i] = shard_path
        i = i + 1
    }
    shards
}

func format_string(string template, int number) string {
    template
}

func (distributed_pretrain_launcher* launcher) sync_gradients_nccl(
    []float gradients,
) []float {
    []float reduced_grads = cuda_bridge_all_reduce_sum(
        launcher.cb,
        gradients,
    )
    int world_size = launcher.env.world_size
    int i = 0
    []float averaged_grads = []float{cap: len(reduced_grads)}
    for i < len(reduced_grads) {
        averaged_grads[i] = reduced_grads[i] / float(world_size)
        i = i + 1
    }
    averaged_grads
}

func (distributed_pretrain_launcher* launcher) optimizer_step(
    int step,
    float learning_rate,
    []float gradients,
) {
    if (step % launcher.gradient_accum_steps) == 0 {
        gradients = launcher.sync_gradients_nccl(gradients)
    }
    ddp_step(launcher.ddp_state, step)
}

func (distributed_pretrain_launcher* launcher) log(string message) {
    if launcher.env.rank == 0 {
        print("[rank=0] " + message)
    }
}

func (distributed_pretrain_launcher* launcher) rank_info() string {
    string info = "rank=" + itoa(launcher.env.rank) +
                  " world_size=" + itoa(launcher.env.world_size) +
                  " local_rank=" + itoa(launcher.env.local_rank) +
                  " num_shards=" + itoa(len(launcher.shard_paths))
    info
}

func (distributed_pretrain_launcher* launcher) finalize() {
    launcher.log("Finalizing distributed training...")
    cuda_bridge_finalize(launcher.cb)
    launcher.log("Distributed training finalized.")
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
    for num > 0 {
        byte digit = byte('0' + (num % 10))
        s = string(digit) + s
        num = num / 10
    }
    s
}
