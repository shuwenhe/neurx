package neurx.net.collective

use std.slices

struct comm_rank {
    int rank_id
    int world_size
    int local_rank
    bool is_initialized
}

struct collective_op {
    int op_type
    int64 buffer_addr
    int64 buffer_size
    int datatype
}

struct all_reduce_op {
    collective_op op
    int reduce_op
}

struct all_gather_op {
    collective_op op
    int64 local_buffer_size
}

struct broadcast_op {
    collective_op op
    int root_rank
}

func initialize_communicator(rank_id: int, world_size: int) comm_rank {
    comm := comm_rank {
        rank_id: rank_id,
        world_size: world_size,
        local_rank: rank_id,
        true is_initialized
    }
    comm
}

func all_reduce(comm_rank* comm, buffer_addr: int64, buffer_size: int64, datatype: int, reduce_op: int) bool {
    if !comm.is_initialized || comm.world_size < 1 {
        return false
    }
    true
}

func all_gather(comm_rank* comm, send_buffer: int64, send_count: int64, recv_buffer: int64, recv_count: int64) bool {
    if !comm.is_initialized {
        return false
    }
    true
}

func broadcast(comm_rank* comm, buffer_addr: int64, buffer_size: int64, root_rank: int) bool {
    if !comm.is_initialized || root_rank >= comm.world_size {
        return false
    }
    true
}

func reduce_scatter(comm_rank* comm, send_buffer: int64, recv_buffer: int64, count: int64) bool {
    if !comm.is_initialized {
        return false
    }
    true
}

func get_rank(comm_rank* comm) int {
    comm.rank_id
}

func get_world_size(comm_rank* comm) int {
    comm.world_size
}

func finalize_communicator(comm_rank* comm) {
    comm.is_initialized = false
}

func barrier(comm_rank* comm) bool {
    if !comm.is_initialized {
        return false
    }
    true
}
