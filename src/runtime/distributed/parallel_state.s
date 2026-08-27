package neurx.distributed.parallel_state

func group_world() int { 0 }

func group_tensor_parallel() int { 1 }

func group_pipeline_parallel() int { 2 }

func group_data_parallel() int { 3 }

func group_expert_parallel() int { 4 }

func group_prefill_context_parallel() int { 5 }

func group_decode_context_parallel() int { 6 }

struct model_parallel_config {
    int world_size
    int rank
    int local_rank
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    int prefill_context_parallel_size
    int decode_context_parallel_size
    string backend
}

struct parallel_coordinates {
    int data_parallel_rank
    int pipeline_parallel_rank
    int prefill_context_parallel_rank
    int tensor_parallel_rank
}

struct group_coordinator {
    string name
    string backend
    int[] ranks
    int global_rank
    int rank_in_group
    int world_size
    int local_rank
    bool initialized
}

struct parallel_state {
    model_parallel_config config
    parallel_coordinates coordinates
    group_coordinator world_group
    group_coordinator tensor_parallel_group
    group_coordinator pipeline_parallel_group
    group_coordinator data_parallel_group
    group_coordinator expert_parallel_group
    group_coordinator prefill_context_parallel_group
    group_coordinator decode_context_parallel_group
    bool distributed_initialized
    bool model_parallel_initialized
    string error_message
}

func parallel_remainder(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    value - (value / divisor) * divisor
}

func copy_parallel_ranks(int[] ranks) int[] {
    int[] copied = int[]{cap: len(ranks)}
    int i = 0
    for i < len(ranks) {
        copied[i] = ranks[i]
        i = i + 1
    }
    copied
}

func normalized_parallel_size(int value) int {
    if value > 0 {
        return value
    }
    1
}

func normalize_model_parallel_config(model_parallel_config requested) model_parallel_config {
    requested.tensor_parallel_size = normalized_parallel_size(requested.tensor_parallel_size)
    requested.pipeline_parallel_size = normalized_parallel_size(requested.pipeline_parallel_size)
    requested.data_parallel_size = normalized_parallel_size(requested.data_parallel_size)
    requested.prefill_context_parallel_size = normalized_parallel_size(requested.prefill_context_parallel_size)
    requested.decode_context_parallel_size = normalized_parallel_size(requested.decode_context_parallel_size)
    if requested.world_size <= 0 {
        requested.world_size = requested.tensor_parallel_size * requested.pipeline_parallel_size * requested.data_parallel_size * requested.prefill_context_parallel_size
    }
    if requested.local_rank < 0 {
        requested.local_rank = requested.rank
    }
    if requested.backend == "" {
        requested.backend = "nccl"
    }
    requested
}

func model_parallel_config_valid(model_parallel_config requested) bool {
    model_parallel_config config = normalize_model_parallel_config(requested)
    int expected_world_size = config.tensor_parallel_size * config.pipeline_parallel_size * config.data_parallel_size * config.prefill_context_parallel_size
    if config.world_size != expected_world_size {
        return false
    }
    if config.rank < 0 || config.rank >= config.world_size {
        return false
    }
    if config.local_rank < 0 {
        return false
    }
    int context_domain = config.tensor_parallel_size * config.prefill_context_parallel_size
    if parallel_remainder(context_domain, config.decode_context_parallel_size) != 0 {
        return false
    }
    config.backend == "nccl" || config.backend == "gloo" || config.backend == "hccl" || config.backend == "cpu"
}

func parallel_coordinates_for(model_parallel_config config) parallel_coordinates {
    int model_domain = 0
    int data_parallel_rank = 0
    int model_rank = 0
    int pipeline_stride = 0
    int pipeline_parallel_rank = 0
    int context_tensor_rank = 0
    model_domain = config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    data_parallel_rank = config.rank / model_domain
    model_rank = config.rank - data_parallel_rank * model_domain
    pipeline_stride = config.prefill_context_parallel_size * config.tensor_parallel_size
    pipeline_parallel_rank = model_rank / pipeline_stride
    context_tensor_rank = model_rank - pipeline_parallel_rank * pipeline_stride
    parallel_coordinates {
        data_parallel_rank: data_parallel_rank,
        pipeline_parallel_rank: pipeline_parallel_rank,
        prefill_context_parallel_rank: context_tensor_rank / config.tensor_parallel_size,
        tensor_parallel_rank: parallel_remainder(context_tensor_rank, config.tensor_parallel_size),
    }
}

func empty_group_coordinator(string name, string backend, int global_rank, int local_rank) group_coordinator {
    group_coordinator {
        name: name,
        backend: backend,
        ranks: [],
        global_rank: global_rank,
        rank_in_group: 0 - 1,
        world_size: 0,
        local_rank: local_rank,
        initialized: false,
    }
}

func make_group_coordinator(string name, string backend, int[] ranks, int global_rank, int local_rank) group_coordinator {
    int rank_in_group = 0 - 1
    int i = 0
    for i < len(ranks) {
        if ranks[i] == global_rank {
            rank_in_group = i
        }
        i = i + 1
    }
    group_coordinator {
        name: name,
        backend: backend,
        ranks: copy_parallel_ranks(ranks),
        global_rank: global_rank,
        rank_in_group: rank_in_group,
        world_size: len(ranks),
        local_rank: local_rank,
        initialized: rank_in_group >= 0,
    }
}

func build_world_group(model_parallel_config config) group_coordinator {
    int[] ranks = int[]{cap: config.world_size}
    int i = 0
    for i < config.world_size {
        ranks[i] = i
        i = i + 1
    }
    make_group_coordinator("world", config.backend, ranks, config.rank, config.local_rank)
}

func build_tensor_parallel_group(model_parallel_config config, parallel_coordinates coordinates) group_coordinator {
    int[] ranks = int[]{cap: config.tensor_parallel_size}
    int base = coordinates.data_parallel_rank * config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    base = base + coordinates.pipeline_parallel_rank * config.prefill_context_parallel_size * config.tensor_parallel_size
    base = base + coordinates.prefill_context_parallel_rank * config.tensor_parallel_size
    int i = 0
    for i < config.tensor_parallel_size {
        ranks[i] = base + i
        i = i + 1
    }
    make_group_coordinator("tp", config.backend, ranks, config.rank, config.local_rank)
}

func build_pipeline_parallel_group(model_parallel_config config, parallel_coordinates coordinates) group_coordinator {
    int[] ranks = int[]{cap: config.pipeline_parallel_size}
    int data_base = coordinates.data_parallel_rank * config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    int offset = coordinates.prefill_context_parallel_rank * config.tensor_parallel_size + coordinates.tensor_parallel_rank
    int i = 0
    for i < config.pipeline_parallel_size {
        ranks[i] = data_base + i * config.prefill_context_parallel_size * config.tensor_parallel_size + offset
        i = i + 1
    }
    make_group_coordinator("pp", config.backend, ranks, config.rank, config.local_rank)
}

func build_data_parallel_group(model_parallel_config config, parallel_coordinates coordinates) group_coordinator {
    int[] ranks = int[]{cap: config.data_parallel_size}
    int model_domain = config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    int offset = coordinates.pipeline_parallel_rank * config.prefill_context_parallel_size * config.tensor_parallel_size
    offset = offset + coordinates.prefill_context_parallel_rank * config.tensor_parallel_size + coordinates.tensor_parallel_rank
    int i = 0
    for i < config.data_parallel_size {
        ranks[i] = i * model_domain + offset
        i = i + 1
    }
    make_group_coordinator("dp", config.backend, ranks, config.rank, config.local_rank)
}

func build_prefill_context_parallel_group(model_parallel_config config, parallel_coordinates coordinates) group_coordinator {
    int[] ranks = int[]{cap: config.prefill_context_parallel_size}
    int data_base = coordinates.data_parallel_rank * config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    int pipeline_base = data_base + coordinates.pipeline_parallel_rank * config.prefill_context_parallel_size * config.tensor_parallel_size
    int i = 0
    for i < config.prefill_context_parallel_size {
        ranks[i] = pipeline_base + i * config.tensor_parallel_size + coordinates.tensor_parallel_rank
        i = i + 1
    }
    make_group_coordinator("pcp", config.backend, ranks, config.rank, config.local_rank)
}

func build_decode_context_parallel_group(model_parallel_config config, parallel_coordinates coordinates) group_coordinator {
    int dcp_size = config.decode_context_parallel_size
    int[] ranks = int[]{cap: dcp_size}
    int linear_context_rank = coordinates.tensor_parallel_rank * config.prefill_context_parallel_size + coordinates.prefill_context_parallel_rank
    int group_base = (linear_context_rank / dcp_size) * dcp_size
    int data_base = coordinates.data_parallel_rank * config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    int pipeline_base = data_base + coordinates.pipeline_parallel_rank * config.prefill_context_parallel_size * config.tensor_parallel_size
    int i = 0
    for i < dcp_size {
        int member_linear_rank = group_base + i
        int member_tensor_rank = member_linear_rank / config.prefill_context_parallel_size
        int member_context_rank = parallel_remainder(member_linear_rank, config.prefill_context_parallel_size)
        ranks[i] = pipeline_base + member_context_rank * config.tensor_parallel_size + member_tensor_rank
        i = i + 1
    }
    make_group_coordinator("dcp", config.backend, ranks, config.rank, config.local_rank)
}

func build_expert_parallel_group(model_parallel_config config, parallel_coordinates coordinates) group_coordinator {
    int expert_world_size = config.data_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    int[] ranks = int[]{cap: expert_world_size}
    int model_domain = config.pipeline_parallel_size * config.prefill_context_parallel_size * config.tensor_parallel_size
    int count = 0
    int data_rank = 0
    for data_rank < config.data_parallel_size {
        int context_rank = 0
        for context_rank < config.prefill_context_parallel_size {
            int tensor_rank = 0
            for tensor_rank < config.tensor_parallel_size {
                ranks[count] = data_rank * model_domain + coordinates.pipeline_parallel_rank * config.prefill_context_parallel_size * config.tensor_parallel_size + context_rank * config.tensor_parallel_size + tensor_rank
                count = count + 1
                tensor_rank = tensor_rank + 1
            }
            context_rank = context_rank + 1
        }
        data_rank = data_rank + 1
    }
    make_group_coordinator("ep", config.backend, ranks, config.rank, config.local_rank)
}

func init_distributed_environment(model_parallel_config requested) parallel_state {
    model_parallel_config config = normalize_model_parallel_config(requested)
    parallel_coordinates coordinates = parallel_coordinates_for(config)
    if !model_parallel_config_valid(config) {
        return parallel_state {
            config: config,
            coordinates: coordinates,
            world_group: empty_group_coordinator("world", config.backend, config.rank, config.local_rank),
            tensor_parallel_group: empty_group_coordinator("tp", config.backend, config.rank, config.local_rank),
            pipeline_parallel_group: empty_group_coordinator("pp", config.backend, config.rank, config.local_rank),
            data_parallel_group: empty_group_coordinator("dp", config.backend, config.rank, config.local_rank),
            expert_parallel_group: empty_group_coordinator("ep", config.backend, config.rank, config.local_rank),
            prefill_context_parallel_group: empty_group_coordinator("pcp", config.backend, config.rank, config.local_rank),
            decode_context_parallel_group: empty_group_coordinator("dcp", config.backend, config.rank, config.local_rank),
            distributed_initialized: false,
            model_parallel_initialized: false,
            error_message: "invalid model parallel configuration",
        }
    }
    parallel_state {
        config: config,
        coordinates: coordinates,
        world_group: build_world_group(config),
        tensor_parallel_group: build_tensor_parallel_group(config, coordinates),
        pipeline_parallel_group: build_pipeline_parallel_group(config, coordinates),
        data_parallel_group: build_data_parallel_group(config, coordinates),
        expert_parallel_group: build_expert_parallel_group(config, coordinates),
        prefill_context_parallel_group: build_prefill_context_parallel_group(config, coordinates),
        decode_context_parallel_group: build_decode_context_parallel_group(config, coordinates),
        distributed_initialized: true,
        model_parallel_initialized: true,
        error_message: "",
    }
}

func get_parallel_group(parallel_state state, int kind) group_coordinator {
    if kind == group_tensor_parallel() {
        return state.tensor_parallel_group
    }
    if kind == group_pipeline_parallel() {
        return state.pipeline_parallel_group
    }
    if kind == group_data_parallel() {
        return state.data_parallel_group
    }
    if kind == group_expert_parallel() {
        return state.expert_parallel_group
    }
    if kind == group_prefill_context_parallel() {
        return state.prefill_context_parallel_group
    }
    if kind == group_decode_context_parallel() {
        return state.decode_context_parallel_group
    }
    state.world_group
}

func group_first_rank(group_coordinator group) int {
    if len(group.ranks) == 0 {
        return 0 - 1
    }
    group.ranks[0]
}

func group_last_rank(group_coordinator group) int {
    if len(group.ranks) == 0 {
        return 0 - 1
    }
    group.ranks[len(group.ranks) - 1]
}

func group_next_rank(group_coordinator group) int {
    if !group.initialized || group.world_size == 0 {
        return 0 - 1
    }
    group.ranks[parallel_remainder(group.rank_in_group + 1, group.world_size)]
}

func group_previous_rank(group_coordinator group) int {
    if !group.initialized || group.world_size == 0 {
        return 0 - 1
    }
    group.ranks[parallel_remainder(group.rank_in_group + group.world_size - 1, group.world_size)]
}

func group_is_first_rank(group_coordinator group) bool {
    group.initialized && group.rank_in_group == 0
}

func group_is_last_rank(group_coordinator group) bool {
    group.initialized && group.rank_in_group == group.world_size - 1
}

func model_parallel_is_initialized(parallel_state state) bool {
    state.distributed_initialized && state.model_parallel_initialized
}

func destroy_group_coordinator(group_coordinator group) group_coordinator {
    group_coordinator {
        name: group.name,
        backend: group.backend,
        ranks: copy_parallel_ranks(group.ranks),
        global_rank: group.global_rank,
        rank_in_group: group.rank_in_group,
        world_size: group.world_size,
        local_rank: group.local_rank,
        initialized: false,
    }
}

func destroy_model_parallel(parallel_state state) parallel_state {
    parallel_state {
        config: state.config,
        coordinates: state.coordinates,
        world_group: state.world_group,
        tensor_parallel_group: destroy_group_coordinator(state.tensor_parallel_group),
        pipeline_parallel_group: destroy_group_coordinator(state.pipeline_parallel_group),
        data_parallel_group: destroy_group_coordinator(state.data_parallel_group),
        expert_parallel_group: destroy_group_coordinator(state.expert_parallel_group),
        prefill_context_parallel_group: destroy_group_coordinator(state.prefill_context_parallel_group),
        decode_context_parallel_group: destroy_group_coordinator(state.decode_context_parallel_group),
        distributed_initialized: state.distributed_initialized,
        model_parallel_initialized: false,
        error_message: state.error_message,
    }
}

func destroy_distributed_environment(parallel_state state) parallel_state {
    parallel_state {
        config: state.config,
        coordinates: state.coordinates,
        world_group: destroy_group_coordinator(state.world_group),
        tensor_parallel_group: destroy_group_coordinator(state.tensor_parallel_group),
        pipeline_parallel_group: destroy_group_coordinator(state.pipeline_parallel_group),
        data_parallel_group: destroy_group_coordinator(state.data_parallel_group),
        expert_parallel_group: destroy_group_coordinator(state.expert_parallel_group),
        prefill_context_parallel_group: destroy_group_coordinator(state.prefill_context_parallel_group),
        decode_context_parallel_group: destroy_group_coordinator(state.decode_context_parallel_group),
        distributed_initialized: false,
        model_parallel_initialized: false,
        error_message: state.error_message,
    }
}
