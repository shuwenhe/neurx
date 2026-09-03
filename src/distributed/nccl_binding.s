package neurx.distributed.nccl_binding

use std.vec.vec
use neurx.device.cuda_runtime_binding

extern func ncclGetUniqueId(void* unique_id) -> int
extern func ncclCommInitRank(void* comm_ptr, int nranks, void* unique_id, int rank) -> int
extern func ncclCommDestroy(int64 comm) -> int
extern func ncclAllReduce(void* send_buff, void* recv_buff, int64 count, 
                         int data_type, int op, int64 comm, int64 stream) -> int
extern func ncclReduce(void* send_buff, void* recv_buff, int64 count,
                      int data_type, int op, int rank, int64 comm, int64 stream) -> int
extern func ncclBroadcast(void* send_buff, void* recv_buff, int64 count,
                         int data_type, int root, int64 comm, int64 stream) -> int
extern func ncclAllGather(void* send_buff, void* recv_buff, int64 send_count,
                         int data_type, int64 comm, int64 stream) -> int
extern func ncclReduceScatter(void* send_buff, void* recv_buff, int64 recv_count,
                             int data_type, int op, int64 comm, int64 stream) -> int

int NCCL_FLOAT32 = 0
int NCCL_FLOAT16 = 1
int NCCL_INT8 = 2
int NCCL_INT32 = 3
int NCCL_INT64 = 4

int NCCL_SUM = 0
int NCCL_PROD = 1
int NCCL_MAX = 2
int NCCL_MIN = 3
int NCCL_AVG = 4

int NCCL_SUCCESS = 0

struct nccl_unique_id {
    int8[128] id_bytes
}

struct nccl_comm {
    int64 handle
    int rank
    int world_size
    bool is_valid
}

func nccl_init_rank(int rank, int world_size) (nccl_comm, bool, string) {
    unique_id := nccl_unique_id{}
    
    status := ncclGetUniqueId(&unique_id)
    if status != NCCL_SUCCESS {
        return nccl_comm{}, false, "nccl init failed"
    }
    
    comm_ptr := 0
    status = ncclCommInitRank(&comm_ptr, world_size, &unique_id, rank)
    if status != NCCL_SUCCESS {
        return nccl_comm{}, false, "nccl rank init failed"
    }
    
    return nccl_comm{
        handle: comm_ptr as int64,
        rank: rank,
        world_size: world_size,
        is_valid: true,
    }, true, ""
}

func nccl_comm_destroy(nccl_comm* comm) (bool, string) {
    if !comm.is_valid {
        return false, "comm invalid"
    }
    
    status := ncclCommDestroy(comm.handle)
    comm.is_valid = false
    
    if status != NCCL_SUCCESS {
        return false, "nccl destroy failed"
    }
    return true, ""
}

func nccl_allreduce(nccl_comm* comm,
                   int64 send_buff, int64 recv_buff,
                   int64 count, int dtype,
                   int op, int64 stream) (bool, string) {
    
    if !comm.is_valid {
        return false, "comm invalid"
    }
    
    status := ncclAllReduce(send_buff as void*, recv_buff as void*,
                           count, dtype, op, comm.handle, stream)
    
    if status != NCCL_SUCCESS {
        return false, "allreduce failed"
    }
    return true, ""
}

func nccl_reduce(nccl_comm* comm,
                int64 send_buff, int64 recv_buff,
                int64 count, int dtype,
                int op, int root,
                int64 stream) (bool, string) {
    
    if !comm.is_valid {
        return false, "comm invalid"
    }
    
    status := ncclReduce(send_buff as void*, recv_buff as void*,
                        count, dtype, op, root, comm.handle, stream)
    
    if status != NCCL_SUCCESS {
        return false, "reduce failed"
    }
    return true, ""
}

func nccl_broadcast(nccl_comm* comm,
                   int64 send_buff, int64 recv_buff,
                   int64 count, int dtype,
                   int root, int64 stream) (bool, string) {
    
    if !comm.is_valid {
        return false, "comm invalid"
    }
    
    status := ncclBroadcast(send_buff as void*, recv_buff as void*,
                           count, dtype, root, comm.handle, stream)
    
    if status != NCCL_SUCCESS {
        return false, "broadcast failed"
    }
    return true, ""
}

func nccl_allgather(nccl_comm* comm,
                   int64 send_buff, int64 recv_buff,
                   int64 send_count, int dtype,
                   int64 stream) (bool, string) {
    
    if !comm.is_valid {
        return false, "comm invalid"
    }
    
    status := ncclAllGather(send_buff as void*, recv_buff as void*,
                           send_count, dtype, comm.handle, stream)
    
    if status != NCCL_SUCCESS {
        return false, "allgather failed"
    }
    return true, ""
}

func nccl_reduce_scatter(nccl_comm* comm,
                        int64 send_buff, int64 recv_buff,
                        int64 recv_count, int dtype,
                        int op, int64 stream) (bool, string) {
    
    if !comm.is_valid {
        return false, "comm invalid"
    }
    
    status := ncclReduceScatter(send_buff as void*, recv_buff as void*,
                               recv_count, dtype, op, comm.handle, stream)
    
    if status != NCCL_SUCCESS {
        return false, "reduce_scatter failed"
    }
    return true, ""
}

struct ring_allreduce_config {
    int num_gpus
    int chunk_size
    int num_chunks
}

func ring_allreduce_prepare(int64 total_size, int num_gpus) ring_allreduce_config {
    chunk_size := total_size / num_gpus as int64
    return ring_allreduce_config{
        num_gpus: num_gpus,
        chunk_size: chunk_size as int,
        num_chunks: num_gpus,
    }
}

func ring_allreduce_reduce_scatter(nccl_comm* comm,
                                  int64 data_buff,
                                  ring_allreduce_config config,
                                  int64 stream) (bool, string) {
    
    for phase := 0; phase < config.num_chunks; phase = phase + 1 {
        send_idx := (comm.rank + phase) % config.num_gpus
        recv_idx := (comm.rank - phase + config.num_gpus) % config.num_gpus
        
        send_offset := send_idx * config.chunk_size
        recv_offset := recv_idx * config.chunk_size
        
        send_buff := data_buff + send_offset as int64
        recv_buff := data_buff + recv_offset as int64
        
    }
    
    return true, ""
}

func ring_allreduce_broadcast(nccl_comm* comm,
                             int64 data_buff,
                             ring_allreduce_config config,
                             int64 stream) (bool, string) {
    
    for phase := 0; phase < config.num_chunks; phase = phase + 1 {
        send_idx := (comm.rank - phase + config.num_gpus) % config.num_gpus
        
        send_offset := send_idx * config.chunk_size
        send_buff := data_buff + send_offset as int64
        
    }
    
    return true, ""
}

func ring_allreduce(nccl_comm* comm,
                   int64 data_buff,
                   int64 total_size,
                   int dtype,
                   int op,
                   int64 stream) (bool, string) {
    
    config := ring_allreduce_prepare(total_size, comm.world_size)
    
    ok, err := ring_allreduce_reduce_scatter(comm, data_buff, config, stream)
    if !ok {
        return false, err
    }
    
    ok, err = ring_allreduce_broadcast(comm, data_buff, config, stream)
    if !ok {
        return false, err
    }
    
    return true, ""
}

func allreduce_after_gemm(nccl_comm* comm,
                        int64 tensor_buff,
                        int64 tensor_size,
                        int64 stream) (bool, string) {
    
    return nccl_allreduce(comm, tensor_buff, tensor_buff,
                         tensor_size / 4, NCCL_FLOAT32,
                         NCCL_SUM, stream)
}

func broadcast_activations(nccl_comm* comm,
                          int64 activation_buff,
                          int64 activation_size,
                          int root_rank,
                          int64 stream) (bool, string) {
    
    return nccl_broadcast(comm, activation_buff, activation_buff,
                         activation_size / 4, NCCL_FLOAT32,
                         root_rank, stream)
}

func allgather_sequences(nccl_comm* comm,
                        int64 local_seq_buff,
                        int64 global_seq_buff,
                        int64 local_seq_size,
                        int64 stream) (bool, string) {
    
    return nccl_allgather(comm, local_seq_buff, global_seq_buff,
                         local_seq_size / 4, NCCL_FLOAT32,
                         stream)
}

func reduce_scatter_experts(nccl_comm* comm,
                           int64 local_expert_buff,
                           int64 gathered_expert_buff,
                           int64 local_expert_size,
                           int64 stream) (bool, string) {
    
    return nccl_reduce_scatter(comm, local_expert_buff, gathered_expert_buff,
                              local_expert_size / 4, NCCL_FLOAT32,
                              NCCL_SUM, stream)
}

func nccl_get_rank(nccl_comm* comm) int {
    return comm.rank
}

func nccl_get_world_size(nccl_comm* comm) int {
    return comm.world_size
}

func nccl_stream_synchronize(int64 stream) (bool, string) {
    return cuda_stream_synchronize(stream)
}
