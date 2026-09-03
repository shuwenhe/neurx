package distributed
struct distributed_context {
    int rank
    int world_size
    int local_rank
    int num_gpus_per_node
    string backend_name
    communicator comm
    process_group_manager group_manager
    bool initialized
}

func new_distributed_context(int rank, int world_size, int local_rank, int num_gpus, comm_backend backend) distributed_context {
    backend_name := ""
    switch backend {
        comm_backend_nccl : backend_name = "nccl",
        comm_backend_ucc : backend_name = "ucc",
        comm_backend_gloo : backend_name = "gloo",
        comm_backend_cpu_only : backend_name = "cpu_only",
    }
    comm := new_communicator(backend, rank, world_size, local_rank)
    group_mgr := new_process_group_manager(backend_name)
    distributed_context {
        rank: rank,
        world_size: world_size,
        local_rank: local_rank,
        num_gpus_per_node: num_gpus,
        backend_name: backend_name,
        comm: comm,
        group_manager: group_mgr,
        initialized: false,
    }
}

func (distributed_context* ctx) initialize() bool {
    if ctx.initialized {
        false
    }
    if !ctx.comm.initialize() {
        false
    }
    ctx.initialized = true
    true
}

func (distributed_context* ctx) finalize() bool {
    if !ctx.initialized {
        false
    }
    groups := ctx.group_manager.list_groups()
    i := 0
    for i < len(groups) {
        g := ctx.group_manager.get_group(groups[i])
        g.finalize()
        ctx.group_manager.delete_group(groups[i])
        i = i + 1
    }
    ctx.comm.finalize()
    ctx.initialized = false
    true
}

func (distributed_context* ctx) is_initialized() bool {
    ctx.initialized
}

func (distributed_context* ctx) get_rank() int {
    ctx.rank
}

func (distributed_context* ctx) get_world_size() int {
    ctx.world_size
}

func (distributed_context* ctx) get_local_rank() int {
    ctx.local_rank
}

func (distributed_context* ctx) is_master() bool {
    ctx.rank == 0
}

func (distributed_context* ctx) create_subgroup([]int ranks, string name) int {
    backend := comm_backend_nccl
    switch ctx.backend_name {
        "nccl" : backend = comm_backend_nccl,
        "ucc" : backend = comm_backend_ucc,
        "gloo" : backend = comm_backend_gloo,
        "cpu_only" : backend = comm_backend_cpu_only,
    }
    ctx.group_manager.create_group(ranks, name, backend)
}

func (distributed_context* ctx) synchronize() bool {
    ctx.comm.barrier()
}

func (distributed_context* ctx) get_communicator() (*communicator) {
    *ctx.comm
}

func (distributed_context* ctx) get_group_manager() (*process_group_manager) {
    *ctx.group_manager
}
