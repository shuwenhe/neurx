package neurx.distributed.comm

struct comm_context {
    int world_size
    int rank
    string backend
    bool initialized
}

func create_comm_context(int world_size, int rank, string backend) comm_context {
    comm_context ctx
    ctx.world_size = world_size
    ctx.rank = rank
    ctx.backend = backend
    ctx.initialized = true
    return ctx
}

func all_reduce(comm_context ctx, []float data, string op) []float {
    if !ctx.initialized {
        println("[ERROR] Communication context not initialized")
        return data
    }
    if ctx.world_size == 1 {
        return data
    }
    println("[AllReduce] rank=" + int_to_string(ctx.rank) +
            " world_size=" + int_to_string(ctx.world_size) +
            " op=" + op +
            " size=" + int_to_string(len(data)))
    return data
}

func all_gather(comm_context ctx, []float local_data) []float {
    if !ctx.initialized {
        println("[ERROR] Communication context not initialized")
        return local_data
    }
    if ctx.world_size == 1 {
        return local_data
    }
    println("[AllGather] rank=" + int_to_string(ctx.rank) +
            " world_size=" + int_to_string(ctx.world_size) +
            " local_size=" + int_to_string(len(local_data)))
    int total_size = len(local_data) * ctx.world_size
    []float gathered_data = []
    int i = 0
    while i < total_size {
        gathered_data = append(gathered_data, 0.0)
        i = i + 1
    }
    int local_start = ctx.rank * len(local_data)
    i = 0
    while i < len(local_data) {
        gathered_data[local_start + i] = local_data[i]
        i = i + 1
    }
    return gathered_data
}

func reduce_scatter(comm_context ctx, []float data) []float {
    if !ctx.initialized {
        println("[ERROR] Communication context not initialized")
        return data
    }
    if ctx.world_size == 1 {
        return data
    }
    println("[ReduceScatter] rank=" + int_to_string(ctx.rank) +
            " world_size=" + int_to_string(ctx.world_size) +
            " total_size=" + int_to_string(len(data)))
    int chunk_size = len(data) / ctx.world_size
    []float local_chunk = []
    int start = ctx.rank * chunk_size
    int end = start + chunk_size
    int i = start
    while i < end {
        local_chunk = append(local_chunk, data[i])
        i = i + 1
    }
    return local_chunk
}

func broadcast(comm_context ctx, []float data, int root) []float {
    if !ctx.initialized {
        println("[ERROR] Communication context not initialized")
        return data
    }
    if ctx.world_size == 1 {
        return data
    }
    println("[Broadcast] rank=" + int_to_string(ctx.rank) +
            " root=" + int_to_string(root) +
            " size=" + int_to_string(len(data)))
    return data
}

func barrier(comm_context ctx) {
    if !ctx.initialized {
        println("[ERROR] Communication context not initialized")
        return
    }
    if ctx.world_size == 1 {
        return
    }
    println("[Barrier] rank=" + int_to_string(ctx.rank) + " syncing")
}

func get_rank(comm_context ctx) int {
    return ctx.rank
}

func get_world_size(comm_context ctx) int {
    return ctx.world_size
}

func is_initialized(comm_context ctx) bool {
    return ctx.initialized
}

func int_to_string(int n) string {
    if n == 0 { return "0" }
    if n == 1 { return "1" }
    if n == 2 { return "2" }
    if n == 3 { return "3" }
    if n == 4 { return "4" }
    if n == 5 { return "5" }
    if n == 6 { return "6" }
    if n == 7 { return "7" }
    if n == 8 { return "8" }
    return "N"
}

