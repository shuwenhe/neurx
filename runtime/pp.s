package neurx.runtime.pp

struct pipeline_parallel_state {
    string name
    string strategy
    int num_stages
    int chunks
    int stage_id
    int world_size
    int rank
    int microbatch_id
    int step
    bool active
    bool warmup_done
    bool flush_done
    []string stages
    []int stage_ranks
    []string schedule
}

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func copy_ints([]int values) []int {
    []int out = []int{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func clamp_positive(int value, int fallback) int {
    if value > 0 {
        return value
    }
    fallback
}

func normalize_stage_id(int stage_id, int num_stages) int {
    if stage_id < 0 {
        return 0
    }
    if stage_id >= num_stages {
        return num_stages - 1
    }
    stage_id
}

func normalize_rank(int rank, int world_size) int {
    if rank < 0 {
        return 0
    }
    if rank >= world_size {
        return world_size - 1
    }
    rank
}

func mod_nonneg(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    int current = value
    while current >= divisor {
        current = current - divisor
    }
    while current < 0 {
        current = current + divisor
    }
    current
}

func new_pipeline_parallel_state(string name, string strategy, int num_stages, int chunks, int stage_id, int world_size, int rank) pipeline_parallel_state {
    int normalized_stages = clamp_positive(num_stages, 1)
    int normalized_chunks = clamp_positive(chunks, 1)
    int normalized_world = clamp_positive(world_size, 1)
    int normalized_stage_id = normalize_stage_id(stage_id, normalized_stages)
    int normalized_rank = normalize_rank(rank, normalized_world)
    pipeline_parallel_state {
        name: name,
        strategy: strategy,
        num_stages: normalized_stages,
        chunks: normalized_chunks,
        stage_id: normalized_stage_id,
        world_size: normalized_world,
        rank: normalized_rank,
        microbatch_id: 0,
        step: 0,
        active: true,
        warmup_done: false,
        flush_done: false,
        stages: [],
        stage_ranks: [],
        schedule: [],
    }
}

func pipeline_parallel_state_dict(pipeline_parallel_state state) pipeline_parallel_state {
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: state.active,
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        stages: copy_strings(state.stages),
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: copy_strings(state.schedule),
    }
}

func pipeline_parallel_load_state_dict(pipeline_parallel_state state, pipeline_parallel_state other) pipeline_parallel_state {
    pipeline_parallel_state {
        name: other.name,
        strategy: other.strategy,
        num_stages: other.num_stages,
        chunks: other.chunks,
        stage_id: other.stage_id,
        world_size: other.world_size,
        rank: other.rank,
        microbatch_id: other.microbatch_id,
        step: other.step,
        active: other.active,
        warmup_done: other.warmup_done,
        flush_done: other.flush_done,
        stages: copy_strings(other.stages),
        stage_ranks: copy_ints(other.stage_ranks),
        schedule: copy_strings(other.schedule),
    }
}

func pp_name(pipeline_parallel_state state) string {
    state.name
}

func pp_strategy(pipeline_parallel_state state) string {
    state.strategy
}

func pp_num_stages(pipeline_parallel_state state) int {
    state.num_stages
}

func pp_chunks(pipeline_parallel_state state) int {
    state.chunks
}

func pp_stage_id(pipeline_parallel_state state) int {
    state.stage_id
}

func pp_world_size(pipeline_parallel_state state) int {
    state.world_size
}

func pp_rank(pipeline_parallel_state state) int {
    state.rank
}

func pp_microbatch_id(pipeline_parallel_state state) int {
    state.microbatch_id
}

func pp_step(pipeline_parallel_state state) int {
    state.step
}

func pp_active(pipeline_parallel_state state) bool {
    state.active
}

func pp_stage_count(pipeline_parallel_state state) int {
    len(state.stages)
}

func pp_schedule_count(pipeline_parallel_state state) int {
    len(state.schedule)
}

func pp_is_ready(pipeline_parallel_state state) bool {
    state.active && state.num_stages > 0 && state.chunks > 0
}

func pp_pipeline_depth(pipeline_parallel_state state) int {
    state.num_stages + state.chunks - 1
}

func pp_total_slots(pipeline_parallel_state state) int {
    state.num_stages + 2 * state.chunks - 2
}

func pp_add_stage(pipeline_parallel_state state, string name) pipeline_parallel_state {
    []string stages = copy_strings(state.stages)
    stages.push(name)
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: state.active,
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        stages: stages,
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: copy_strings(state.schedule),
    }
}

func pp_add_stage_rank(pipeline_parallel_state state, int rank) pipeline_parallel_state {
    []int stage_ranks = copy_ints(state.stage_ranks)
    stage_ranks.push(normalize_rank(rank, state.world_size))
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: state.active,
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        stages: copy_strings(state.stages),
        stage_ranks: stage_ranks,
        schedule: copy_strings(state.schedule),
    }
}

func pp_add_schedule_step(pipeline_parallel_state state, string step_name) pipeline_parallel_state {
    []string schedule = copy_strings(state.schedule)
    schedule.push(step_name)
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: state.active,
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        stages: copy_strings(state.stages),
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: schedule,
    }
}

func pp_assign_default_stage_ranks(pipeline_parallel_state state) pipeline_parallel_state {
    []int stage_ranks = []int{cap: state.num_stages}
    int i = 0
    while i < state.num_stages {
        stage_ranks[i] = mod_nonneg(i, state.world_size)
        i = i + 1
    }
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: state.active,
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        stages: copy_strings(state.stages),
        stage_ranks: stage_ranks,
        schedule: copy_strings(state.schedule),
    }
}

func pp_stage_owner(pipeline_parallel_state state, int stage_idx) int {
    if stage_idx < 0 {
        return 0
    }
    if stage_idx >= state.num_stages {
        return state.world_size - 1
    }
    if stage_idx < len(state.stage_ranks) {
        return state.stage_ranks[stage_idx]
    }
    mod_nonneg(stage_idx, state.world_size)
}

func pp_prepare_schedule(pipeline_parallel_state state) pipeline_parallel_state {
    []string schedule = []string{cap: 2 * state.chunks}
    int i = 0
    while i < state.chunks {
        schedule[i] = "forward"
        i = i + 1
    }
    int j = 0
    while j < state.chunks {
        schedule[state.chunks + j] = "backward"
        j = j + 1
    }
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: state.active,
        warmup_done: false,
        flush_done: false,
        stages: copy_strings(state.stages),
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: schedule,
    }
}

func pp_next_microbatch(pipeline_parallel_state state) pipeline_parallel_state {
    if !state.active {
        return state
    }
    int next_microbatch = state.microbatch_id + 1
    if next_microbatch >= state.chunks {
        next_microbatch = 0
    }
    bool warmup_done = state.warmup_done
    if state.step + 1 >= state.num_stages - 1 {
        warmup_done = true
    }
    bool flush_done = state.flush_done
    if state.step + 1 >= pp_total_slots(state) {
        flush_done = true
    }
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: next_microbatch,
        step: state.step + 1,
        active: state.active,
        warmup_done: warmup_done,
        flush_done: flush_done,
        stages: copy_strings(state.stages),
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: copy_strings(state.schedule),
    }
}

func pp_set_active(pipeline_parallel_state state, bool active) pipeline_parallel_state {
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: state.microbatch_id,
        step: state.step,
        active: active,
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        stages: copy_strings(state.stages),
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: copy_strings(state.schedule),
    }
}

func pp_stop(pipeline_parallel_state state) pipeline_parallel_state {
    pp_set_active(state, false)
}

func pp_resume(pipeline_parallel_state state) pipeline_parallel_state {
    pp_set_active(state, true)
}

func pp_reset_progress(pipeline_parallel_state state) pipeline_parallel_state {
    pipeline_parallel_state {
        name: state.name,
        strategy: state.strategy,
        num_stages: state.num_stages,
        chunks: state.chunks,
        stage_id: state.stage_id,
        world_size: state.world_size,
        rank: state.rank,
        microbatch_id: 0,
        step: 0,
        active: state.active,
        warmup_done: false,
        flush_done: false,
        stages: copy_strings(state.stages),
        stage_ranks: copy_ints(state.stage_ranks),
        schedule: copy_strings(state.schedule),
    }
}