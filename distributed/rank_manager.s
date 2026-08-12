package neurx.distributed.rank_manager
extern func neurx_nccl_init_rank(int rank, int world_size, int local_rank) int64
extern func neurx_nccl_destroy(int64 communicator) int
extern func neurx_nccl_all_reduce_f32(int64 communicator, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) int
extern func neurx_nccl_all_gather_f32(int64 communicator, int64 send_pointer, int64 receive_pointer, int count, int64 stream) int
extern func neurx_nccl_reduce_scatter_f32(int64 communicator, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) int
extern func neurx_nccl_broadcast_f32(int64 communicator, int64 pointer, int count, int root, int64 stream) int
extern func neurx_nccl_barrier(int64 communicator, int64 stream) int
func group_world() int { 0 }

func group_tensor_parallel() int { 1 }

func group_pipeline_parallel() int { 2 }

func group_data_parallel() int { 3 }

func group_expert_parallel() int { 4 }

func reduce_sum() int { 0 }

func reduce_product() int { 1 }

func reduce_maximum() int { 2 }

func reduce_minimum() int { 3 }

struct parallel_topology {
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    int expert_parallel_size
    int world_size
}

struct rank_coordinates {
    int global_rank
    int local_rank
    int tensor_parallel_rank
    int pipeline_parallel_rank
    int data_parallel_rank
    int expert_parallel_rank
}

struct rank_group {
    int kind
    []int ranks
    int rank_in_group
    int64 communicator
    bool initialized
}

struct distributed_context {
    parallel_topology topology
    rank_coordinates coordinates
    string backend
    rank_group world_group
    rank_group tensor_group
    rank_group pipeline_group
    rank_group data_group
    rank_group expert_group
    bool initialized
    string error_message
}

struct distributed_collective_result {
    distributed_context context
    bool success
    int status_code
    string error_message
}

func distributed_remainder(int value, int divisor) int {
    value - (value / divisor) * divisor
}

func normalize_parallel_topology(parallel_topology topology) parallel_topology {
    if topology.tensor_parallel_size <= 0 { topology.tensor_parallel_size = 1 }
    if topology.pipeline_parallel_size <= 0 { topology.pipeline_parallel_size = 1 }
    if topology.data_parallel_size <= 0 { topology.data_parallel_size = 1 }
    if topology.expert_parallel_size <= 0 { topology.expert_parallel_size = 1 }
    topology.world_size = topology.tensor_parallel_size * topology.pipeline_parallel_size * topology.data_parallel_size
    topology
}

func parallel_topology_valid(parallel_topology topology) bool {
    if topology.tensor_parallel_size <= 0 || topology.pipeline_parallel_size <= 0 || topology.data_parallel_size <= 0 || topology.expert_parallel_size <= 0 { return false }
    if topology.world_size != topology.tensor_parallel_size * topology.pipeline_parallel_size * topology.data_parallel_size { return false }
    int expert_domain = topology.tensor_parallel_size * topology.data_parallel_size
    distributed_remainder(expert_domain, topology.expert_parallel_size) == 0
}

func rank_coordinates_for(parallel_topology topology, int global_rank, int local_rank) rank_coordinates {
    rank_coordinates coordinates
    coordinates.global_rank = global_rank
    coordinates.local_rank = local_rank
    coordinates.tensor_parallel_rank = -1
    coordinates.pipeline_parallel_rank = -1
    coordinates.data_parallel_rank = -1
    coordinates.expert_parallel_rank = -1
    if !parallel_topology_valid(topology) || global_rank < 0 || global_rank >= topology.world_size { return coordinates }
    int model_parallel_size = topology.tensor_parallel_size * topology.pipeline_parallel_size
    coordinates.data_parallel_rank = global_rank / model_parallel_size
    int model_rank = global_rank - coordinates.data_parallel_rank * model_parallel_size
    coordinates.pipeline_parallel_rank = model_rank / topology.tensor_parallel_size
    coordinates.tensor_parallel_rank = model_rank - coordinates.pipeline_parallel_rank * topology.tensor_parallel_size
    int expert_linear_rank = coordinates.data_parallel_rank * topology.tensor_parallel_size + coordinates.tensor_parallel_rank
    coordinates.expert_parallel_rank = distributed_remainder(expert_linear_rank, topology.expert_parallel_size)
    coordinates
}

func empty_rank_group(int kind) rank_group {
    rank_group group
    group.kind = kind
    group.ranks = []
    group.rank_in_group = -1
    group.communicator = i64(0)
    group.initialized = false
    group
}

func build_world_group(parallel_topology topology, rank_coordinates coordinates) rank_group {
    rank_group group = empty_rank_group(group_world())
    int rank = 0
    while rank < topology.world_size {
        group.ranks = append(group.ranks, rank)
        rank = rank + 1
    }
    group.rank_in_group = coordinates.global_rank
    group.initialized = coordinates.global_rank >= 0
    group
}

func build_tensor_group(parallel_topology topology, rank_coordinates coordinates) rank_group {
    rank_group group = empty_rank_group(group_tensor_parallel())
    if coordinates.tensor_parallel_rank < 0 { return group }
    int model_parallel_size = topology.tensor_parallel_size * topology.pipeline_parallel_size
    int base = coordinates.data_parallel_rank * model_parallel_size + coordinates.pipeline_parallel_rank * topology.tensor_parallel_size
    int rank = 0
    while rank < topology.tensor_parallel_size {
        group.ranks = append(group.ranks, base + rank)
        rank = rank + 1
    }
    group.rank_in_group = coordinates.tensor_parallel_rank
    group.initialized = true
    group
}

func build_pipeline_group(parallel_topology topology, rank_coordinates coordinates) rank_group {
    rank_group group = empty_rank_group(group_pipeline_parallel())
    if coordinates.pipeline_parallel_rank < 0 { return group }
    int model_parallel_size = topology.tensor_parallel_size * topology.pipeline_parallel_size
    int data_base = coordinates.data_parallel_rank * model_parallel_size
    int stage = 0
    while stage < topology.pipeline_parallel_size {
        group.ranks = append(group.ranks, data_base + stage * topology.tensor_parallel_size + coordinates.tensor_parallel_rank)
        stage = stage + 1
    }
    group.rank_in_group = coordinates.pipeline_parallel_rank
    group.initialized = true
    group
}

func build_data_group(parallel_topology topology, rank_coordinates coordinates) rank_group {
    rank_group group = empty_rank_group(group_data_parallel())
    if coordinates.data_parallel_rank < 0 { return group }
    int model_parallel_size = topology.tensor_parallel_size * topology.pipeline_parallel_size
    int model_offset = coordinates.pipeline_parallel_rank * topology.tensor_parallel_size + coordinates.tensor_parallel_rank
    int data_rank = 0
    while data_rank < topology.data_parallel_size {
        group.ranks = append(group.ranks, data_rank * model_parallel_size + model_offset)
        data_rank = data_rank + 1
    }
    group.rank_in_group = coordinates.data_parallel_rank
    group.initialized = true
    group
}

func build_expert_group(parallel_topology topology, rank_coordinates coordinates) rank_group {
    rank_group group = empty_rank_group(group_expert_parallel())
    if coordinates.expert_parallel_rank < 0 { return group }
    int linear_rank = coordinates.data_parallel_rank * topology.tensor_parallel_size + coordinates.tensor_parallel_rank
    int expert_group_index = linear_rank / topology.expert_parallel_size
    int member = 0
    while member < topology.expert_parallel_size {
        int member_linear_rank = expert_group_index * topology.expert_parallel_size + member
        int member_data_rank = member_linear_rank / topology.tensor_parallel_size
        int member_tensor_rank = member_linear_rank - member_data_rank * topology.tensor_parallel_size
        int model_parallel_size = topology.tensor_parallel_size * topology.pipeline_parallel_size
        int global_rank = member_data_rank * model_parallel_size + coordinates.pipeline_parallel_rank * topology.tensor_parallel_size + member_tensor_rank
        group.ranks = append(group.ranks, global_rank)
        member = member + 1
    }
    group.rank_in_group = coordinates.expert_parallel_rank
    group.initialized = true
    group
}

func distributed_context_init(parallel_topology requested, int global_rank, int local_rank, string backend) distributed_context {
    distributed_context context
    context.topology = normalize_parallel_topology(requested)
    context.coordinates = rank_coordinates_for(context.topology, global_rank, local_rank)
    context.backend = backend
    context.world_group = build_world_group(context.topology, context.coordinates)
    context.tensor_group = build_tensor_group(context.topology, context.coordinates)
    context.pipeline_group = build_pipeline_group(context.topology, context.coordinates)
    context.data_group = build_data_group(context.topology, context.coordinates)
    context.expert_group = build_expert_group(context.topology, context.coordinates)
    context.initialized = parallel_topology_valid(context.topology) && global_rank >= 0 && global_rank < context.topology.world_size && (backend == "nccl" || backend == "gloo" || backend == "hccl")
    context.error_message = ""
    if !context.initialized { context.error_message = "invalid distributed configuration" }
    context
}

func distributed_group(distributed_context context, int kind) rank_group {
    if kind == group_tensor_parallel() { return context.tensor_group }
    if kind == group_pipeline_parallel() { return context.pipeline_group }
    if kind == group_data_parallel() { return context.data_group }
    if kind == group_expert_parallel() { return context.expert_group }
    context.world_group
}

func distributed_attach_communicator(distributed_context context, int kind, int64 communicator) distributed_context {
    if kind == group_tensor_parallel() { context.tensor_group.communicator = communicator }
    else if kind == group_pipeline_parallel() { context.pipeline_group.communicator = communicator }
    else if kind == group_data_parallel() { context.data_group.communicator = communicator }
    else if kind == group_expert_parallel() { context.expert_group.communicator = communicator }
    else { context.world_group.communicator = communicator }
    context
}

func new_collective_result(distributed_context context, int status_code, string error_message) distributed_collective_result {
    distributed_collective_result result
    result.context = context
    result.success = status_code == 0
    result.status_code = status_code
    result.error_message = error_message
    result
}

func distributed_collective_ready(distributed_context context, int kind, int count) bool {
    rank_group group = distributed_group(context, kind)
    context.initialized && context.backend == "nccl" && group.initialized && group.communicator != i64(0) && count > 0
}

func distributed_all_reduce_f32(distributed_context context, int kind, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) distributed_collective_result {
    if !distributed_collective_ready(context, kind, count) || send_pointer == i64(0) || receive_pointer == i64(0) {
        return new_collective_result(context, -1, "all-reduce is not ready")
    }
    int status = neurx_nccl_all_reduce_f32(distributed_group(context, kind).communicator, send_pointer, receive_pointer, count, operation, stream)
    string message = ""
    if status != 0 { message = "NCCL all-reduce failed" }
    new_collective_result(context, status, message)
}

func distributed_all_gather_f32(distributed_context context, int kind, int64 send_pointer, int64 receive_pointer, int count, int64 stream) distributed_collective_result {
    if !distributed_collective_ready(context, kind, count) || send_pointer == i64(0) || receive_pointer == i64(0) {
        return new_collective_result(context, -1, "all-gather is not ready")
    }
    int status = neurx_nccl_all_gather_f32(distributed_group(context, kind).communicator, send_pointer, receive_pointer, count, stream)
    string message = ""
    if status != 0 { message = "NCCL all-gather failed" }
    new_collective_result(context, status, message)
}

func distributed_reduce_scatter_f32(distributed_context context, int kind, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) distributed_collective_result {
    if !distributed_collective_ready(context, kind, count) || send_pointer == i64(0) || receive_pointer == i64(0) {
        return new_collective_result(context, -1, "reduce-scatter is not ready")
    }
    int status = neurx_nccl_reduce_scatter_f32(distributed_group(context, kind).communicator, send_pointer, receive_pointer, count, operation, stream)
    string message = ""
    if status != 0 { message = "NCCL reduce-scatter failed" }
    new_collective_result(context, status, message)
}

func distributed_broadcast_f32(distributed_context context, int kind, int64 pointer, int count, int root, int64 stream) distributed_collective_result {
    rank_group group = distributed_group(context, kind)
    if !distributed_collective_ready(context, kind, count) || pointer == i64(0) || root < 0 || root >= len(group.ranks) {
        return new_collective_result(context, -1, "broadcast is not ready")
    }
    int status = neurx_nccl_broadcast_f32(group.communicator, pointer, count, root, stream)
    string message = ""
    if status != 0 { message = "NCCL broadcast failed" }
    new_collective_result(context, status, message)
}

func distributed_barrier(distributed_context context, int kind, int64 stream) distributed_collective_result {
    rank_group group = distributed_group(context, kind)
    if !context.initialized || !group.initialized || group.communicator == i64(0) {
        return new_collective_result(context, -1, "barrier is not ready")
    }
    int status = neurx_nccl_barrier(group.communicator, stream)
    string message = ""
    if status != 0 { message = "NCCL barrier failed" }
    new_collective_result(context, status, message)
}

func distributed_topology_contract_valid(parallel_topology requested) bool {
    parallel_topology topology = normalize_parallel_topology(requested)
    if !parallel_topology_valid(topology) { return false }
    int rank = 0
    while rank < topology.world_size {
        rank_coordinates coordinates = rank_coordinates_for(topology, rank, rank)
        if coordinates.global_rank != rank || coordinates.tensor_parallel_rank < 0 || coordinates.pipeline_parallel_rank < 0 || coordinates.data_parallel_rank < 0 || coordinates.expert_parallel_rank < 0 { return false }
        rank = rank + 1
    }
    true
}

