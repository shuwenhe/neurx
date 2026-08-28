package distributed
    nccl
    ucc
    gloo
    cpu_only
}
    all_reduce
    all_gather
    reduce_scatter
    broadcast
    send_recv
    barrier
}
struct tensor_handle {
    int64 device_id
    string device_type
    int64 ptr
    int64 size
    string dtype
}
struct comm_operation {
    comm_op_type op_type
    string name
    int64 created_at
}
struct reduce_op {
    string op_name
}
func reduce_op_sum() reduce_op {
    reduce_op { op_name: "sum" }
}
func reduce_op_max() reduce_op {
    reduce_op { op_name: "max" }
}
func reduce_op_min() reduce_op {
    reduce_op { op_name: "min" }
}
func reduce_op_avg() reduce_op {
    reduce_op { op_name: "avg" }
}
struct communicator_config {
    comm_backend backend
    int rank
    int world_size
    int local_rank
    string backend_config
    bool enable_profiling
}
struct communicator {
    communicator_config config
    string backend_name
    bool initialized
    int64 init_time
    map[string, comm_operation] operations
}
func new_tensor_handle(int64 device_id, string device_type, int64 ptr, int64 size, string dtype) tensor_handle {
    tensor_handle {
        device_id: device_id,
        device_type: device_type,
        ptr: ptr,
        size: size,
        dtype: dtype,
    }
}
func new_communicator(comm_backend backend, int rank, int world_size, int local_rank) communicator {
    backend_name := ""
    switch backend {
        comm_backend_nccl : backend_name = "nccl",
        comm_backend_ucc : backend_name = "ucc",
        comm_backend_gloo : backend_name = "gloo",
        comm_backend_cpu_only : backend_name = "cpu_only",
    }
    config := communicator_config {
        backend: backend,
        rank: rank,
        world_size: world_size,
        local_rank: local_rank,
        backend_config: "",
        enable_profiling: false,
    }
    communicator {
        config: config,
        backend_name: backend_name,
        initialized: false,
        init_time: 0,
        operations: map[string, comm_operation]{},
    }
}
func (communicator* comm) initialize() bool {
    if comm.initialized {
        false
    }
    comm.initialized = true
    comm.init_time = 0
    true
}
func (communicator* comm) finalize() bool {
    if !comm.initialized {
        false
    }
    comm.initialized = false
    true
}
func (communicator* comm) get_rank() int {
    comm.config.rank
}
func (communicator* comm) get_world_size() int {
    comm.config.world_size
}
func (communicator* comm) get_local_rank() int {
    comm.config.local_rank
}
func (communicator* comm) is_initialized() bool {
    comm.initialized
}
func (communicator* comm) get_backend() string {
    comm.backend_name
}
