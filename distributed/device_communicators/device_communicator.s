package neurx.distributed.device_communicators
use neurx.distributed.parallel_state.{group_coordinator, copy_parallel_ranks}
extern func neurx_nccl_init_rank(int rank, int world_size, int local_rank) int64
extern func neurx_nccl_destroy(int64 communicator) int
extern func neurx_nccl_all_reduce_f32(int64 communicator, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) int
extern func neurx_nccl_all_gather_f32(int64 communicator, int64 send_pointer, int64 receive_pointer, int count, int64 stream) int
extern func neurx_nccl_reduce_scatter_f32(int64 communicator, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) int
extern func neurx_nccl_broadcast_f32(int64 communicator, int64 pointer, int count, int root, int64 stream) int
extern func neurx_nccl_send_f32(int64 communicator, int64 pointer, int count, int peer, int tag, int64 stream) int
extern func neurx_nccl_recv_f32(int64 communicator, int64 pointer, int count, int peer, int tag, int64 stream) int
extern func neurx_nccl_barrier(int64 communicator, int64 stream) int
func reduce_sum() int { 0 }

func reduce_product() int { 1 }

func reduce_maximum() int { 2 }

func reduce_minimum() int { 3 }

struct device_communicator {
    string name
    string backend
    []int ranks
    int global_rank
    int rank_in_group
    int world_size
    int local_rank
    int64 native_handle
    bool initialized
    bool suspended
    bool use_all_to_all
    int operation_count
    string error_message
}
struct device_collective_result {
    device_communicator communicator
    bool success
    int status_code
    string error_message
}
struct async_communication_handle {
    int request_id
    int operation
    int peer
    int status_code
    bool completed
    string error_message
}
func device_communicator_from_group(group_coordinator group, bool use_all_to_all) device_communicator {
    int64 handle = i64(0)
    bool initialized = false
    string error_message = ""
    if group.initialized {
        if group.world_size == 1 {
            initialized = true
        } else if group.backend == "nccl" {
            handle = neurx_nccl_init_rank(group.rank_in_group, group.world_size, group.local_rank)
            initialized = handle != i64(0)
            if !initialized {
                error_message = "failed to initialize native NCCL communicator"
            }
        } else if group.backend == "gloo" || group.backend == "cpu" || group.backend == "hccl" {
            initialized = true
        }
    } else {
        error_message = "parallel group is not initialized"
    }
    device_communicator {
        name: group.name,
        backend: group.backend,
        ranks: copy_parallel_ranks(group.ranks),
        global_rank: group.global_rank,
        rank_in_group: group.rank_in_group,
        world_size: group.world_size,
        local_rank: group.local_rank,
        native_handle: handle,
        initialized: initialized,
        suspended: false,
        use_all_to_all: use_all_to_all,
        operation_count: 0,
        error_message: error_message,
    }
}
func communicator_after_operation(device_communicator communicator, int status, string message) device_communicator {
    device_communicator {
        name: communicator.name,
        backend: communicator.backend,
        ranks: copy_parallel_ranks(communicator.ranks),
        global_rank: communicator.global_rank,
        rank_in_group: communicator.rank_in_group,
        world_size: communicator.world_size,
        local_rank: communicator.local_rank,
        native_handle: communicator.native_handle,
        initialized: communicator.initialized,
        suspended: communicator.suspended,
        use_all_to_all: communicator.use_all_to_all,
        operation_count: communicator.operation_count + 1,
        error_message: message,
    }
}
func device_communicator_ready(device_communicator communicator, int count) bool {
    if !communicator.initialized || communicator.suspended || count <= 0 {
        return false
    }
    if communicator.world_size == 1 {
        return true
    }
    if communicator.backend == "nccl" {
        return communicator.native_handle != i64(0)
    }
    false
}
func failed_device_collective(device_communicator communicator, string message) device_collective_result {
    device_collective_result {
        communicator: communicator,
        success: false,
        status_code: 0 - 1,
        error_message: message,
    }
}
func completed_device_collective(device_communicator communicator, int status, string operation_name) device_collective_result {
    string message = ""
    if status != 0 {
        message = operation_name + " failed"
    }
    device_collective_result {
        communicator: communicator_after_operation(communicator, status, message),
        success: status == 0,
        status_code: status,
        error_message: message,
    }
}
func device_all_reduce_f32(device_communicator communicator, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) device_collective_result {
    if !device_communicator_ready(communicator, count) || send_pointer == i64(0) || receive_pointer == i64(0) {
        return failed_device_collective(communicator, "all-reduce communicator or buffer is not ready")
    }
    if communicator.world_size == 1 {
        return completed_device_collective(communicator, 0, "all-reduce")
    }
    int status = neurx_nccl_all_reduce_f32(communicator.native_handle, send_pointer, receive_pointer, count, operation, stream)
    completed_device_collective(communicator, status, "all-reduce")
}
func device_all_gather_f32(device_communicator communicator, int64 send_pointer, int64 receive_pointer, int count, int64 stream) device_collective_result {
    if !device_communicator_ready(communicator, count) || send_pointer == i64(0) || receive_pointer == i64(0) {
        return failed_device_collective(communicator, "all-gather communicator or buffer is not ready")
    }
    if communicator.world_size == 1 {
        return completed_device_collective(communicator, 0, "all-gather")
    }
    int status = neurx_nccl_all_gather_f32(communicator.native_handle, send_pointer, receive_pointer, count, stream)
    completed_device_collective(communicator, status, "all-gather")
}
func device_reduce_scatter_f32(device_communicator communicator, int64 send_pointer, int64 receive_pointer, int count, int operation, int64 stream) device_collective_result {
    if !device_communicator_ready(communicator, count) || send_pointer == i64(0) || receive_pointer == i64(0) {
        return failed_device_collective(communicator, "reduce-scatter communicator or buffer is not ready")
    }
    if communicator.world_size == 1 {
        return completed_device_collective(communicator, 0, "reduce-scatter")
    }
    int status = neurx_nccl_reduce_scatter_f32(communicator.native_handle, send_pointer, receive_pointer, count, operation, stream)
    completed_device_collective(communicator, status, "reduce-scatter")
}
func device_broadcast_f32(device_communicator communicator, int64 pointer, int count, int source, int64 stream) device_collective_result {
    if !device_communicator_ready(communicator, count) || pointer == i64(0) || source < 0 || source >= communicator.world_size {
        return failed_device_collective(communicator, "broadcast communicator, buffer, or source is not ready")
    }
    if communicator.world_size == 1 {
        return completed_device_collective(communicator, 0, "broadcast")
    }
    int status = neurx_nccl_broadcast_f32(communicator.native_handle, pointer, count, source, stream)
    completed_device_collective(communicator, status, "broadcast")
}
func device_barrier(device_communicator communicator, int64 stream) device_collective_result {
    if !device_communicator_ready(communicator, 1) {
        return failed_device_collective(communicator, "barrier communicator is not ready")
    }
    if communicator.world_size == 1 {
        return completed_device_collective(communicator, 0, "barrier")
    }
    int status = neurx_nccl_barrier(communicator.native_handle, stream)
    completed_device_collective(communicator, status, "barrier")
}
func device_isend_f32(device_communicator communicator, int64 pointer, int count, int destination, int tag, int64 stream) async_communication_handle {
    int status = 0 - 1
    string message = "send communicator, buffer, or destination is not ready"
    if device_communicator_ready(communicator, count) && pointer != i64(0) && destination >= 0 && destination < communicator.world_size {
        if communicator.world_size == 1 {
            status = 0
        } else {
            status = neurx_nccl_send_f32(communicator.native_handle, pointer, count, destination, tag, stream)
        }
        message = ""
        if status != 0 {
            message = "send failed"
        }
    }
    async_communication_handle {
        request_id: communicator.operation_count + 1,
        operation: 1,
        peer: destination,
        status_code: status,
        completed: true,
        error_message: message,
    }
}
func device_irecv_f32(device_communicator communicator, int64 pointer, int count, int source, int tag, int64 stream) async_communication_handle {
    int status = 0 - 1
    string message = "receive communicator, buffer, or source is not ready"
    if device_communicator_ready(communicator, count) && pointer != i64(0) && source >= 0 && source < communicator.world_size {
        if communicator.world_size == 1 {
            status = 0
        } else {
            status = neurx_nccl_recv_f32(communicator.native_handle, pointer, count, source, tag, stream)
        }
        message = ""
        if status != 0 {
            message = "receive failed"
        }
    }
    async_communication_handle {
        request_id: communicator.operation_count + 1,
        operation: 2,
        peer: source,
        status_code: status,
        completed: true,
        error_message: message,
    }
}
func communication_handle_is_completed(async_communication_handle handle) bool {
    handle.completed
}
func communication_handle_succeeded(async_communication_handle handle) bool {
    handle.completed && handle.status_code == 0
}
func checkpoint_prepare_communicator(device_communicator communicator) device_communicator {
    int status = 0
    if communicator.native_handle != i64(0) {
        status = neurx_nccl_destroy(communicator.native_handle)
    }
    device_communicator {
        name: communicator.name,
        backend: communicator.backend,
        ranks: copy_parallel_ranks(communicator.ranks),
        global_rank: communicator.global_rank,
        rank_in_group: communicator.rank_in_group,
        world_size: communicator.world_size,
        local_rank: communicator.local_rank,
        native_handle: i64(0),
        initialized: status == 0,
        suspended: true,
        use_all_to_all: communicator.use_all_to_all,
        operation_count: communicator.operation_count,
        error_message: communicator.error_message,
    }
}
func checkpoint_restore_communicator(device_communicator communicator) device_communicator {
    int64 handle = i64(0)
    bool initialized = communicator.world_size == 1
    if communicator.world_size > 1 && communicator.backend == "nccl" {
        handle = neurx_nccl_init_rank(communicator.rank_in_group, communicator.world_size, communicator.local_rank)
        initialized = handle != i64(0)
    }
    device_communicator {
        name: communicator.name,
        backend: communicator.backend,
        ranks: copy_parallel_ranks(communicator.ranks),
        global_rank: communicator.global_rank,
        rank_in_group: communicator.rank_in_group,
        world_size: communicator.world_size,
        local_rank: communicator.local_rank,
        native_handle: handle,
        initialized: initialized,
        suspended: false,
        use_all_to_all: communicator.use_all_to_all,
        operation_count: communicator.operation_count,
        error_message: "",
    }
}
func destroy_device_communicator(device_communicator communicator) device_communicator {
    int status = 0
    if communicator.native_handle != i64(0) {
        status = neurx_nccl_destroy(communicator.native_handle)
    }
    device_communicator {
        name: communicator.name,
        backend: communicator.backend,
        ranks: copy_parallel_ranks(communicator.ranks),
        global_rank: communicator.global_rank,
        rank_in_group: communicator.rank_in_group,
        world_size: communicator.world_size,
        local_rank: communicator.local_rank,
        native_handle: i64(0),
        initialized: false,
        suspended: false,
        use_all_to_all: communicator.use_all_to_all,
        operation_count: communicator.operation_count,
        error_message: communicator.error_message,
    }
}
