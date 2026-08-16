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

func new_distributed_context(int rank, int world_size, int local_rank, int num_gpus, comm_backend backend) (distributed_context) {
    backend_name := ""
    switch backend {
        comm_backend::nccl : backend_name = "nccl",
        comm_backend::ucc : backend_name = "ucc",
        comm_backend::gloo : backend_name = "gloo",
        comm_backend::cpu_only : backend_name = "cpu_only",
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

func (ctx *distributed_context) initialize() (bool) {
    if ctx.initialized {
        false
    }

    if !ctx.comm.initialize() {
        false
    }

    ctx.initialized = true
    true
}

func (ctx *distributed_context) finalize() (bool) {
    if !ctx.initialized {
        false
    }

    groups := ctx.group_manager.list_groups()
    i := 0
    while i < groups.len() {
        g := ctx.group_manager.get_group(groups[i])
        g.finalize()
        ctx.group_manager.delete_group(groups[i])
        i = i + 1
    }

    ctx.comm.finalize()
    ctx.initialized = false
    true
}

func (ctx *distributed_context) is_initialized() (bool) {
    ctx.initialized
}

func (ctx *distributed_context) get_rank() (int) {
    ctx.rank
}

func (ctx *distributed_context) get_world_size() (int) {
    ctx.world_size
}

func (ctx *distributed_context) get_local_rank() (int) {
    ctx.local_rank
}

func (ctx *distributed_context) is_master() (bool) {
    ctx.rank == 0
}

func (ctx *distributed_context) create_subgroup(vec[int] ranks, string name) (int) {
    backend := comm_backend::nccl
    switch ctx.backend_name {
        "nccl" : backend = comm_backend::nccl,
        "ucc" : backend = comm_backend::ucc,
        "gloo" : backend = comm_backend::gloo,
        "cpu_only" : backend = comm_backend::cpu_only,
    }

    ctx.group_manager.create_group(ranks, name, backend)
}

func (ctx *distributed_context) synchronize() (bool) {
    ctx.comm.barrier()
}

func (ctx *distributed_context) get_communicator() (*communicator) {
    &ctx.comm
}

func (ctx *distributed_context) get_group_manager() (*process_group_manager) {
    &ctx.group_manager
}
