package neurx.runtime.distributed.collective_abi

extern "libc:neurx_collective_probe" func neurx_collective_probe(string backend) int
extern "libc:neurx_collective_init_rank" func neurx_collective_init_rank(string backend, int rank, int world_size, int device_id, string unique_id_hex) int
extern "libc:neurx_collective_destroy" func neurx_collective_destroy(int communicator) int
extern "libc:neurx_collective_all_reduce" func neurx_collective_all_reduce(int communicator, int64 send_buffer, int64 receive_buffer, int64 count, int dtype, int operation, int64 stream) int
extern "libc:neurx_collective_all_gather" func neurx_collective_all_gather(int communicator, int64 send_buffer, int64 receive_buffer, int64 count, int dtype, int64 stream) int
extern "libc:neurx_collective_reduce_scatter" func neurx_collective_reduce_scatter(int communicator, int64 send_buffer, int64 receive_buffer, int64 count, int dtype, int operation, int64 stream) int
extern "libc:neurx_collective_send" func neurx_collective_send(int communicator, int64 send_buffer, int64 count, int dtype, int peer, int64 stream) int
extern "libc:neurx_collective_recv" func neurx_collective_recv(int communicator, int64 receive_buffer, int64 count, int dtype, int peer, int64 stream) int
extern "libc:neurx_collective_synchronize" func neurx_collective_synchronize(int communicator, int64 stream) int
extern "libc:neurx_collective_async_error" func neurx_collective_async_error(int communicator) int
extern "libc:neurx_collective_last_error" func neurx_collective_last_error(int communicator) string

func collective_backend_nccl() string { "nccl" }

func collective_backend_hccl() string { "hccl" }

func collective_backend_rccl() string { "rccl" }

func collective_dtype_float32() int { 0 }

func collective_dtype_float16() int { 1 }

func collective_dtype_bfloat16() int { 2 }

func collective_reduce_sum() int { 0 }

struct communicator {
    int handle
    int rank
    int world_size
    int device_id
    string backend
    bool valid
    string error_message
}

func collective_init(string backend, int rank, int world_size, int device_id, string unique_id_hex) communicator {
    if neurx_collective_probe(backend) <= 0 {
        return communicator {handle: 0, rank: rank, world_size: world_size, device_id: device_id, backend: backend, valid: false, error_message: neurx_collective_last_error(0)}
    }
    int handle = neurx_collective_init_rank(backend, rank, world_size, device_id, unique_id_hex)
    communicator {handle: handle, rank: rank, world_size: world_size, device_id: device_id, backend: backend, valid: handle > 0, error_message: neurx_collective_last_error(handle)}
}

func collective_destroy(communicator comm) int {
    if !comm.valid { return 0 - 1 }
    neurx_collective_destroy(comm.handle)
}
