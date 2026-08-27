package neurx.optimizer.zero_infinity

struct zero_infinity_config {
    bool enable_cpu_offload
    bool enable_nvme_offload
    string nvme_swap_dir
    int cpu_buffer_size_mb
    int nvme_buffer_size_mb
    int offload_optimizer_states
    int offload_params
    float overlap_comm_factor
}

struct cpu_offload_buffer {
    float[] data
    int capacity
    int used
    bool[] is_valid
}

struct nvme_offload_buffer {
    string file_path
    int file_handle
    int capacity_mb
    int used_mb
    int[] block_mapping
}

struct offload_param_metadata {
    int param_id
    int size_bytes
    bool on_gpu
    bool on_cpu
    bool on_nvme
    int cpu_offset
    int nvme_offset
    int last_access_step
    int access_count
}

struct zero_infinity_state {
    zero_infinity_config config
    cpu_offload_buffer cpu_buffer
    nvme_offload_buffer nvme_buffer
    []offload_param_metadata param_metadata
    int total_params
    int current_step
    float cpu_to_gpu_bandwidth_gbs
    float nvme_to_cpu_bandwidth_gbs
}

func new_zero_infinity_state(
    zero_infinity_config config,
    int total_params,
    int total_size_mb) zero_infinity_state {
    cpu_offload_buffer cpu_buf
    cpu_buf.capacity = config.cpu_buffer_size_mb * 1024 * 1024 / 4
    cpu_buf.data = float[]{cap: cpu_buf.capacity}
    cpu_buf.used = 0
    cpu_buf.is_valid = bool[]{cap: total_params}
    nvme_offload_buffer nvme_buf
    if config.enable_nvme_offload {
        nvme_buf.file_path = config.nvme_swap_dir + "/zero_infinity_swap.bin"
        nvme_buf.capacity_mb = config.nvme_buffer_size_mb
        nvme_buf.used_mb = 0
        nvme_buf.block_mapping = int[]{cap: total_params}
        int i = 0
        for i < total_params {
            nvme_buf.block_mapping[i] = -1
            i = i + 1
        }
    }
    []offload_param_metadata metadata = []offload_param_metadata{cap: total_params}
    int param_idx = 0
    for param_idx < total_params {
        metadata[param_idx] = offload_param_metadata {
            param_id: param_idx,
            size_bytes: 4,
            on_gpu: true,
            on_cpu: false,
            on_nvme: false,
            cpu_offset: -1,
            nvme_offset: -1,
            last_access_step: 0,
            access_count: 0,
        }
        param_idx = param_idx + 1
    }
    zero_infinity_state {
        config: config,
        cpu_buffer: cpu_buf,
        nvme_buffer: nvme_buf,
        param_metadata: metadata,
        total_params: total_params,
        current_step: 0,
        cpu_to_gpu_bandwidth_gbs: 32.0,
        nvme_to_cpu_bandwidth_gbs: 7.0,
    }
}

func zero_infinity_offload_param_to_cpu(
    zero_infinity_state state,
    float[] gpu_param,
    int param_idx) zero_infinity_state {
    if state.param_metadata[param_idx].on_cpu {
        return state
    }
    int param_size = len(gpu_param)
    int required_space = param_size
    if state.cpu_buffer.used + required_space > state.cpu_buffer.capacity {
        state = zero_infinity_evict_cpu_to_nvme(state, required_space)
    }
    int cpu_offset = state.cpu_buffer.used
    int i = 0
    for i < param_size {
        state.cpu_buffer.data[cpu_offset + i] = gpu_param[i]
        i = i + 1
    }
    state.cpu_buffer.used = state.cpu_buffer.used + param_size
    state.cpu_buffer.is_valid[param_idx] = true
    state.param_metadata[param_idx].on_cpu = true
    state.param_metadata[param_idx].cpu_offset = cpu_offset
    state.param_metadata[param_idx].size_bytes = param_size * 4
    return state
}

func zero_infinity_evict_cpu_to_nvme(
    zero_infinity_state state,
    int required_space) zero_infinity_state {
    if !state.config.enable_nvme_offload {
        return state
    }
    int[] lru_candidates = int[]{cap: state.total_params}
    int candidate_count = 0
    int param_idx = 0
    for param_idx < state.total_params {
        if state.param_metadata[param_idx].on_cpu &&
           !state.param_metadata[param_idx].on_gpu {
            lru_candidates[candidate_count] = param_idx
            candidate_count = candidate_count + 1
        }
        param_idx = param_idx + 1
    }
    int evicted_space = 0
    int cand_idx = 0
    for cand_idx < candidate_count && evicted_space < required_space {
        int target_param = lru_candidates[cand_idx]
        state = zero_infinity_write_to_nvme(state, target_param)
        int param_size = state.param_metadata[target_param].size_bytes / 4
        evicted_space = evicted_space + param_size
        state.param_metadata[target_param].on_cpu = false
        state.cpu_buffer.is_valid[target_param] = false
        cand_idx = cand_idx + 1
    }
    return state
}

func zero_infinity_write_to_nvme(
    zero_infinity_state state,
    int param_idx) zero_infinity_state {
    if state.param_metadata[param_idx].on_nvme {
        return state
    }
    int cpu_offset = state.param_metadata[param_idx].cpu_offset
    int param_size = state.param_metadata[param_idx].size_bytes / 4
    int nvme_offset = state.nvme_buffer.used_mb
    state.nvme_buffer.block_mapping[param_idx] = nvme_offset
    state.nvme_buffer.used_mb = state.nvme_buffer.used_mb +
                                 (param_size * 4 + 1024 * 1024 - 1) / (1024 * 1024)
    state.param_metadata[param_idx].on_nvme = true
    state.param_metadata[param_idx].nvme_offset = nvme_offset
    return state
}

struct prefetch_result {
    zero_infinity_state state
    float[] param_data
}

func zero_infinity_prefetch_param(
    zero_infinity_state state,
    int param_idx) prefetch_result {
    offload_param_metadata meta = state.param_metadata[param_idx]
    float[] dummy = float[]{cap: 0}
    if meta.on_gpu {
        return prefetch_result{state: state, param_data: dummy}
    }
    int param_size = meta.size_bytes / 4
    float[] param_data = float[]{cap: param_size}
    if meta.on_cpu {
        int cpu_offset = meta.cpu_offset
        int i = 0
        for i < param_size {
            param_data[i] = state.cpu_buffer.data[cpu_offset + i]
            i = i + 1
        }
    } else if meta.on_nvme {
        state = zero_infinity_read_from_nvme(state, param_idx)
        int cpu_offset = meta.cpu_offset
        int i = 0
        for i < param_size {
            param_data[i] = state.cpu_buffer.data[cpu_offset + i]
            i = i + 1
        }
    }
    state.param_metadata[param_idx].on_gpu = true
    state.param_metadata[param_idx].last_access_step = state.current_step
    state.param_metadata[param_idx].access_count = state.param_metadata[param_idx].access_count + 1
    return prefetch_result{state: state, param_data: param_data}
}

func zero_infinity_read_from_nvme(
    zero_infinity_state state,
    int param_idx) zero_infinity_state {
    int nvme_offset = state.param_metadata[param_idx].nvme_offset
    int param_size = state.param_metadata[param_idx].size_bytes / 4
    if state.cpu_buffer.used + param_size > state.cpu_buffer.capacity {
        state = zero_infinity_evict_cpu_to_nvme(state, param_size)
    }
    int cpu_offset = state.cpu_buffer.used
    state.cpu_buffer.used = state.cpu_buffer.used + param_size
    state.param_metadata[param_idx].on_cpu = true
    state.param_metadata[param_idx].cpu_offset = cpu_offset
    state.cpu_buffer.is_valid[param_idx] = true
    return state
}

func zero_infinity_get_memory_stats(
    zero_infinity_state state) zero_infinity_memory_stats {
    int gpu_params = 0
    int cpu_params = 0
    int nvme_params = 0
    int i = 0
    for i < state.total_params {
        if state.param_metadata[i].on_gpu {
            gpu_params = gpu_params + 1
        }
        if state.param_metadata[i].on_cpu {
            cpu_params = cpu_params + 1
        }
        if state.param_metadata[i].on_nvme {
            nvme_params = nvme_params + 1
        }
        i = i + 1
    }
    zero_infinity_memory_stats {
        gpu_param_count: gpu_params,
        cpu_param_count: cpu_params,
        nvme_param_count: nvme_params,
        cpu_buffer_used_mb: state.cpu_buffer.used * 4 / (1024 * 1024),
        cpu_buffer_capacity_mb: state.cpu_buffer.capacity * 4 / (1024 * 1024),
        nvme_used_mb: state.nvme_buffer.used_mb,
        nvme_capacity_mb: state.nvme_buffer.capacity_mb,
    }
}

struct zero_infinity_memory_stats {
    int gpu_param_count
    int cpu_param_count
    int nvme_param_count
    int cpu_buffer_used_mb
    int cpu_buffer_capacity_mb
    int nvme_used_mb
    int nvme_capacity_mb
}

func zero_infinity_step(zero_infinity_state state) zero_infinity_state {
    state.current_step = state.current_step + 1
    return state
}
