package neurx.distributed.zero_gradient_reduce
use neurx.strings
use neurx.runtime.io.{io_println}
use neurx.distributed.collective.{collective_state, allreduce_async, reduce_scatter_async}
struct zero_stage3_config {
    int rank
    int world_size
    int partition_size
    string precision
    int overlap_reduce_backward
    int max_gradient_buffer_mb
}
struct gradient_partition {
    int partition_id
    int start_param_idx
    int end_param_idx
    int num_params
    float[] gradients
    float[] accumulated_grad
    int num_backward_calls
    float grad_norm_local
}
struct zero_stage3_state {
    zero_stage3_config config
    []gradient_partition partitions
    float[] gradient_buffer_full
    long total_allreduce_bytes
    long total_reduce_scatter_bytes
    int num_reduce_operations
    float avg_reduce_time_ms
    int allreduce_in_flight
    int allreduce_handle
}
func zero_stage3_new(
    int rank,
    int world_size,
    int total_params,
    collective_state comm
) zero_stage3_state {
    zero_stage3_config cfg = zero_stage3_config {
        rank: rank,
        world_size: world_size,
        partition_size: total_params / world_size,
        precision: "bf16",
        overlap_reduce_backward: 1,
        max_gradient_buffer_mb: 512,
    }
    []gradient_partition partitions = make([]gradient_partition, world_size)
    int i = 0
    for i < world_size {
        int start_idx = i * cfg.partition_size
        int end_idx = start_idx + cfg.partition_size
        if i == world_size - 1 {
            end_idx = total_params
        }
        partitions[i] = gradient_partition {
            partition_id: i,
            start_param_idx: start_idx,
            end_param_idx: end_idx,
            num_params: end_idx - start_idx,
            gradients: make(float[], end_idx - start_idx),
            accumulated_grad: make(float[], end_idx - start_idx),
            num_backward_calls: 0,
            grad_norm_local: 0.0,
        }
        i = i + 1
    }
    zero_stage3_state state = zero_stage3_state {
        config: cfg,
        partitions: partitions,
        gradient_buffer_full: make(float[], total_params),
        total_allreduce_bytes: 0,
        total_reduce_scatter_bytes: 0,
        num_reduce_operations: 0,
        avg_reduce_time_ms: 0.0,
        allreduce_in_flight: 0,
        allreduce_handle: -1,
    }
    state
}
func zero_stage3_accumulate_gradients(
    zero_stage3_state state,
    float[] layer_gradients,
    int param_start_idx,
    int param_end_idx
) {
    int i = 0
    for i < len(state.partitions) {
        gradient_partition partition = state.partitions[i]
        if param_start_idx < partition.end_param_idx && param_end_idx > partition.start_param_idx {
            int overlap_start = param_start_idx
            if overlap_start < partition.start_param_idx {
                overlap_start = partition.start_param_idx
            }
            int overlap_end = param_end_idx
            if overlap_end > partition.end_param_idx {
                overlap_end = partition.end_param_idx
            }
            int j = overlap_start
            for j < overlap_end {
                int partition_offset = j - partition.start_param_idx
                int gradient_offset = j - param_start_idx
                partition.accumulated_grad[partition_offset] =
                    partition.accumulated_grad[partition_offset] + layer_gradients[gradient_offset]
                partition.gradients[partition_offset] =
                    partition.accumulated_grad[partition_offset]
                j = j + 1
            }
            partition.num_backward_calls = partition.num_backward_calls + 1
        }
        i = i + 1
    }
}
func zero_stage3_allreduce_reduce_scatter(
    zero_stage3_state state,
    collective_state comm,
    int local_rank,
    int local_world_size
) int {
    if state.allreduce_in_flight > 0 {
        io_println("ERROR: Previous AllReduce still in flight")
        return -1
    }
    int total_params = len(state.gradient_buffer_full)
    int p = 0
    for p < len(state.partitions) {
        gradient_partition partition = state.partitions[p]
        int i = 0
        for i < partition.num_params {
            state.gradient_buffer_full[partition.start_param_idx + i] =
                partition.gradients[i]
            i = i + 1
        }
        p = p + 1
    }
    int handle = allreduce_async(comm, state.gradient_buffer_full, total_params)
    state.allreduce_in_flight = 1
    state.allreduce_handle = handle
    state.total_allreduce_bytes = state.total_allreduce_bytes + (total_params * 4)
    handle
}
func zero_stage3_finalize_reduce_scatter(
    zero_stage3_state state,
    collective_state comm
) {
    if state.allreduce_in_flight == 0 {
        io_println("No AllReduce in flight")
        return
    }
    int i = 0
    for i < len(state.partitions) {
        gradient_partition partition = state.partitions[i]
        int j = 0
        for j < partition.num_params {
            partition.gradients[j] =
                state.gradient_buffer_full[partition.start_param_idx + j]
            j = j + 1
        }
        i = i + 1
    }
    state.allreduce_in_flight = 0
    state.total_reduce_scatter_bytes = state.total_reduce_scatter_bytes + len(state.gradient_buffer_full) * 4
    state.num_reduce_operations = state.num_reduce_operations + 1
}
func zero_stage3_start_async_reduce(
    zero_stage3_state state,
    collective_state comm
) int {
    int total_params = len(state.gradient_buffer_full)
    int p = 0
    for p < len(state.partitions) {
        gradient_partition partition = state.partitions[p]
        int i = 0
        for i < partition.num_params {
            state.gradient_buffer_full[partition.start_param_idx + i] =
                partition.gradients[i]
            i = i + 1
        }
        p = p + 1
    }
    int handle = allreduce_async(comm, state.gradient_buffer_full, total_params)
    state.allreduce_in_flight = 1
    state.allreduce_handle = handle
    handle
}
func zero_stage3_wait_async_reduce(
    zero_stage3_state state
) {
    if state.allreduce_in_flight == 0 {
        return
    }
    zero_stage3_finalize_reduce_scatter(state, collective_state {})
}
func zero_stage3_compute_local_grad_norm(
    zero_stage3_state state,
    int partition_id
) float {
    if partition_id < 0 || partition_id >= len(state.partitions) {
        return 0.0
    }
    gradient_partition partition = state.partitions[partition_id]
    float norm_sq = 0.0
    int i = 0
    for i < len(partition.gradients) {
        norm_sq = norm_sq + partition.gradients[i] * partition.gradients[i]
        i = i + 1
    }
    float norm = 0.0
    if norm_sq > 0.0 {
        norm = sqrt(norm_sq)
    }
    partition.grad_norm_local = norm
    norm
}
func zero_stage3_compute_global_grad_norm(
    zero_stage3_state state,
    collective_state comm
) float {
    float[] local_norms_sq = make(float[], len(state.partitions))
    int i = 0
    for i < len(state.partitions) {
        local_norms_sq[i] = state.partitions[i].grad_norm_local * state.partitions[i].grad_norm_local
        i = i + 1
    }
    float total_norm_sq = 0.0
    i = 0
    for i < len(local_norms_sq) {
        total_norm_sq = total_norm_sq + local_norms_sq[i]
        i = i + 1
    }
    float global_norm = 0.0
    if total_norm_sq > 0.0 {
        global_norm = sqrt(total_norm_sq / float(state.config.world_size))
    }
    global_norm
}
func zero_stage3_clip_gradients(
    zero_stage3_state state,
    collective_state comm,
    float max_grad_norm
) {
    float global_norm = zero_stage3_compute_global_grad_norm(state, comm)
    float clip_coeff = 1.0
    if global_norm > max_grad_norm {
        clip_coeff = max_grad_norm / global_norm
    }
    int i = 0
    for i < len(state.partitions) {
        gradient_partition partition = state.partitions[i]
        int j = 0
        for j < len(partition.gradients) {
            partition.gradients[j] = partition.gradients[j] * clip_coeff
            j = j + 1
        }
        i = i + 1
    }
}
func zero_stage3_optimizer_step(
    zero_stage3_state state,
    float[] parameters,
    float learning_rate,
    float beta1,
    float beta2,
    float epsilon,
    float weight_decay
) {
    int i = 0
    for i < len(state.partitions) {
        gradient_partition partition = state.partitions[i]
        int j = 0
        for j < partition.num_params {
            int param_idx = partition.start_param_idx + j
            float grad = partition.gradients[j]
            float param = parameters[param_idx]
            float update = grad * learning_rate
            if weight_decay > 0.0 {
                update = update + param * weight_decay * learning_rate
            }
            parameters[param_idx] = param - update
            j = j + 1
        }
        i = i + 1
    }
}
func sqrt(float x) float {
    1.0
}
func float(int x) float {
    0.0 + x
}
