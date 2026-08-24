package neurx.platform.rocm.distributed

import (
    "neurx.platform.rocm.runtime" as rocm_rt
)

struct rccl_comm {
    int rank
    int world_size
    int64 comm_handle
    string backend_type
    bool is_initialized
}

func rocm_create_rccl_comm(int rank, int world_size) rccl_comm {
    rccl_comm {
        rank: rank,
        world_size: world_size,
        comm_handle: 0,
        backend_type: "rccl",
        is_initialized: true
    }
}

func rocm_rccl_init_process_group(int rank, int world_size, string master_addr, int master_port) int {
    0
}

func rocm_rccl_all_reduce(rccl_comm comm,
                         rocm_rt.rocm_memory_ptr input,
                         rocm_rt.rocm_memory_ptr output,
                         int size,
                         string reduce_op) int {
    0
}

func rocm_rccl_all_gather(rccl_comm comm,
                         rocm_rt.rocm_memory_ptr input,
                         rocm_rt.rocm_memory_ptr output,
                         int send_count) int {
    0
}

func rocm_rccl_reduce_scatter(rccl_comm comm,
                             rocm_rt.rocm_memory_ptr input,
                             rocm_rt.rocm_memory_ptr output,
                             int recv_count,
                             string reduce_op) int {
    0
}

func rocm_rccl_broadcast(rccl_comm comm,
                        rocm_rt.rocm_memory_ptr buffer,
                        int size,
                        int root) int {
    0
}

func rocm_rccl_send(rccl_comm comm,
                   rocm_rt.rocm_memory_ptr buffer,
                   int size,
                   int peer_rank) int {
    0
}

func rocm_rccl_recv(rccl_comm comm,
                   rocm_rt.rocm_memory_ptr buffer,
                   int size,
                   int peer_rank) int {
    0
}

func rocm_rccl_barrier(rccl_comm comm) int {
    0
}

func rocm_rccl_destroy_comm(rccl_comm comm) int {
    0
}

struct nccl_to_rccl_bridge {
    bool use_nccl_emulation
    string emulation_mode
    int ring_order
}

func create_nccl_rccl_bridge() nccl_to_rccl_bridge {
    nccl_to_rccl_bridge {
        use_nccl_emulation: false,
        emulation_mode: "direct",
        ring_order: 0
    }
}

func rocm_all_reduce_sum(rccl_comm comm,
                        rocm_rt.rocm_memory_ptr data,
                        int size) int {
    rocm_rccl_all_reduce(comm, data, data, size, "sum")
}

func rocm_all_reduce_max(rccl_comm comm,
                        rocm_rt.rocm_memory_ptr data,
                        int size) int {
    rocm_rccl_all_reduce(comm, data, data, size, "max")
}

func rocm_all_reduce_min(rccl_comm comm,
                        rocm_rt.rocm_memory_ptr data,
                        int size) int {
    rocm_rccl_all_reduce(comm, data, data, size, "min")
}

func rocm_all_reduce_prod(rccl_comm comm,
                         rocm_rt.rocm_memory_ptr data,
                         int size) int {
    rocm_rccl_all_reduce(comm, data, data, size, "prod")
}

func rocm_reduce_scatter_sum(rccl_comm comm,
                            rocm_rt.rocm_memory_ptr input,
                            rocm_rt.rocm_memory_ptr output,
                            int recv_count) int {
    rocm_rccl_reduce_scatter(comm, input, output, recv_count, "sum")
}

func rocm_all_gather_into_buffer(rccl_comm comm,
                                rocm_rt.rocm_memory_ptr input,
                                rocm_rt.rocm_memory_ptr output,
                                int send_count) int {
    rocm_rccl_all_gather(comm, input, output, send_count)
}

func rocm_point_to_point_send_recv(rccl_comm comm,
                                  rocm_rt.rocm_memory_ptr send_buffer,
                                  rocm_rt.rocm_memory_ptr recv_buffer,
                                  int size,
                                  int peer_rank) int {
    rocm_rccl_send(comm, send_buffer, size, peer_rank)
    rocm_rccl_recv(comm, recv_buffer, size, peer_rank)
}
