package neurx.distributed.pipelining
use neurx.strings
struct pipeline_stage {
    string name
    int stage_index
    int num_stages
    int rank
    int world_size
    string device
    bool first
    bool last
    string[] inputs
    string[] outputs
}
struct pipeline_plan {
    string name
    string strategy
    int num_stages
    int chunks
    string[] split_points
    []pipeline_stage stages
}
struct pipeline_schedule_state {
    pipeline_plan plan
    int stage_index
    int step
    int microbatch_id
    string[] ops
    bool warmup_done
    bool flush_done
    bool active
}
func copy_stage(pipeline_stage stage) pipeline_stage {
    pipeline_stage {
        name: stage.name,
        stage_index: stage.stage_index,
        num_stages: stage.num_stages,
        rank: stage.rank,
        world_size: stage.world_size,
        device: stage.device,
        first: stage.first,
        last: stage.last,
        inputs: copy_strings(stage.inputs),
        outputs: copy_strings(stage.outputs),
    }
}
func copy_stages([]pipeline_stage values) []pipeline_stage {
    []pipeline_stage out = []pipeline_stage{cap: len(values)}
    int i = 0
    for i < len(values) {
        out[i] = copy_stage(values[i])
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
func clamp_stage_index(int stage_index, int num_stages) int {
    if stage_index < 0 {
        return 0
    }
    if stage_index >= num_stages {
        return num_stages - 1
    }
    stage_index
}
func clamp_rank(int rank, int world_size) int {
    if rank < 0 {
        return 0
    }
    if rank >= world_size {
        return world_size - 1
    }
    rank
}
func split_point_beginning() string {
    "beginning"
}
func split_point_end() string {
    "end"
}
func pipe_split(string marker) string {
    marker
}
func new_pipeline_stage(string name, int stage_index, int num_stages, int rank, int world_size, string device) pipeline_stage {
    int normalized_stages = clamp_positive(num_stages, 1)
    int normalized_world = clamp_positive(world_size, 1)
    int normalized_index = clamp_stage_index(stage_index, normalized_stages)
    int normalized_rank = clamp_rank(rank, normalized_world)
    pipeline_stage {
        name: name,
        stage_index: normalized_index,
        num_stages: normalized_stages,
        rank: normalized_rank,
        world_size: normalized_world,
        device: device,
        first: normalized_index == 0,
        last: normalized_index == normalized_stages - 1,
        inputs: [],
        outputs: [],
    }
}
func pipeline_stage_state_dict(pipeline_stage stage) pipeline_stage {
    copy_stage(stage)
}
func pipeline_stage_load_state_dict(pipeline_stage stage, pipeline_stage other) pipeline_stage {
    copy_stage(other)
}
func pipeline_stage_name(pipeline_stage stage) string {
    stage.name
}
func pipeline_stage_index(pipeline_stage stage) int {
    stage.stage_index
}
func pipeline_stage_rank(pipeline_stage stage) int {
    stage.rank
}
func pipeline_stage_world_size(pipeline_stage stage) int {
    stage.world_size
}
func pipeline_stage_is_first(pipeline_stage stage) bool {
    stage.first
}
func pipeline_stage_is_last(pipeline_stage stage) bool {
    stage.last
}
func pipeline_stage_add_input(pipeline_stage stage, string value) pipeline_stage {
    string[] inputs = copy_strings(stage.inputs)
    inputs = append(inputs, value)
    pipeline_stage {
        name: stage.name,
        stage_index: stage.stage_index,
        num_stages: stage.num_stages,
        rank: stage.rank,
        world_size: stage.world_size,
        device: stage.device,
        first: stage.first,
        last: stage.last,
        inputs: inputs,
        outputs: copy_strings(stage.outputs),
    }
}
func pipeline_stage_add_output(pipeline_stage stage, string value) pipeline_stage {
    string[] outputs = copy_strings(stage.outputs)
    outputs = append(outputs, value)
    pipeline_stage {
        name: stage.name,
        stage_index: stage.stage_index,
        num_stages: stage.num_stages,
        rank: stage.rank,
        world_size: stage.world_size,
        device: stage.device,
        first: stage.first,
        last: stage.last,
        inputs: copy_strings(stage.inputs),
        outputs: outputs,
    }
}
func new_pipeline_plan(string name, string strategy, int num_stages, int chunks) pipeline_plan {
    pipeline_plan {
        name: name,
        strategy: strategy,
        num_stages: clamp_positive(num_stages, 1),
        chunks: clamp_positive(chunks, 1),
        split_points: [],
        stages: [],
    }
}
func pipeline_plan_state_dict(pipeline_plan plan) pipeline_plan {
    pipeline_plan {
        name: plan.name,
        strategy: plan.strategy,
        num_stages: plan.num_stages,
        chunks: plan.chunks,
        split_points: copy_strings(plan.split_points),
        stages: copy_stages(plan.stages),
    }
}
func pipeline_plan_load_state_dict(pipeline_plan plan, pipeline_plan other) pipeline_plan {
    pipeline_plan {
        name: other.name,
        strategy: other.strategy,
        num_stages: other.num_stages,
        chunks: other.chunks,
        split_points: copy_strings(other.split_points),
        stages: copy_stages(other.stages),
    }
}
func pipeline_name(pipeline_plan plan) string {
    plan.name
}
func pipeline_strategy(pipeline_plan plan) string {
    plan.strategy
}
func pipeline_num_stages(pipeline_plan plan) int {
    plan.num_stages
}
func pipeline_chunks(pipeline_plan plan) int {
    plan.chunks
}
func pipeline_split_count(pipeline_plan plan) int {
    len(plan.split_points)
}
func pipeline_stage_count(pipeline_plan plan) int {
    len(plan.stages)
}
func pipeline_add_split_point(pipeline_plan plan, string split_point) pipeline_plan {
    string[] split_points = copy_strings(plan.split_points)
    split_points = append(split_points, split_point)
    pipeline_plan {
        name: plan.name,
        strategy: plan.strategy,
        num_stages: plan.num_stages,
        chunks: plan.chunks,
        split_points: split_points,
        stages: copy_stages(plan.stages),
    }
}
func build_stage(pipeline_plan plan, int stage_index, int rank, int world_size, string device) pipeline_stage {
    string stage_name = "stage"
    new_pipeline_stage(stage_name, stage_index, plan.num_stages, rank, world_size, device)
}
func pipeline_add_stage(pipeline_plan plan, pipeline_stage stage) pipeline_plan {
    []pipeline_stage stages = copy_stages(plan.stages)
    stages = append(stages, copy_stage(stage))
    pipeline_plan {
        name: plan.name,
        strategy: plan.strategy,
        num_stages: plan.num_stages,
        chunks: plan.chunks,
        split_points: copy_strings(plan.split_points),
        stages: stages,
    }
}
func pipeline_with_default_stages(pipeline_plan plan, int world_size, string device) pipeline_plan {
    pipeline_plan current = pipeline_plan_state_dict(plan)
    int i = 0
    for i < current.num_stages {
        pipeline_stage stage = build_stage(current, i, i, world_size, device)
        current = pipeline_add_stage(current, stage)
        i = i + 1
    }
    current
}
func pipeline_is_valid(pipeline_plan plan) bool {
    bool split_ok = len(plan.split_points) == 0 || len(plan.split_points) == plan.num_stages - 1
    bool stage_ok = len(plan.stages) == 0 || len(plan.stages) == plan.num_stages
    split_ok && stage_ok
}
func schedule_total_slots(pipeline_plan plan) int {
    plan.num_stages + 2 * plan.chunks - 2
}
func schedule_pipeline_depth(pipeline_plan plan) int {
    plan.num_stages + plan.chunks - 1
}
func new_schedule_state(pipeline_plan plan, string[] ops) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(plan),
        stage_index: 0,
        step: 0,
        microbatch_id: 0,
        ops: copy_strings(ops),
        warmup_done: false,
        flush_done: false,
        active: true,
    }
}
func new_schedule_state_for_stage(pipeline_plan plan, int stage_index, string[] ops) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(plan),
        stage_index: clamp_stage_index(stage_index, plan.num_stages),
        step: 0,
        microbatch_id: 0,
        ops: copy_strings(ops),
        warmup_done: false,
        flush_done: false,
        active: true,
    }
}
func schedule_state_dict(pipeline_schedule_state state) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(state.plan),
        stage_index: state.stage_index,
        step: state.step,
        microbatch_id: state.microbatch_id,
        ops: copy_strings(state.ops),
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        active: state.active,
    }
}
func schedule_load_state_dict(pipeline_schedule_state state, pipeline_schedule_state other) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(other.plan),
        stage_index: other.stage_index,
        step: other.step,
        microbatch_id: other.microbatch_id,
        ops: copy_strings(other.ops),
        warmup_done: other.warmup_done,
        flush_done: other.flush_done,
        active: other.active,
    }
}
func schedule_stage_index(pipeline_schedule_state state) int {
    state.stage_index
}
func schedule_warmup_steps(pipeline_plan plan, int stage_index) int {
    int stage_idx = clamp_stage_index(stage_index, plan.num_stages)
    int steps = plan.num_stages - stage_idx - 1
    if steps < 0 {
        return 0
    }
    if steps > plan.chunks - 1 {
        return plan.chunks - 1
    }
    steps
}
func schedule_steady_steps(pipeline_plan plan, int stage_index) int {
    int warmup = schedule_warmup_steps(plan, stage_index)
    int steady = plan.chunks - warmup
    if steady < 1 {
        return 1
    }
    steady
}
func schedule_flush_steps(pipeline_plan plan, int stage_index) int {
    schedule_warmup_steps(plan, stage_index)
}
func schedule_total_ops(pipeline_schedule_state state) int {
    len(state.ops)
}
func schedule_ops_count(pipeline_schedule_state state) int {
    len(state.ops)
}
func schedule_is_active(pipeline_schedule_state state) bool {
    state.active
}
func schedule_step_index(pipeline_schedule_state state) int {
    state.step
}
func schedule_microbatch_id(pipeline_schedule_state state) int {
    state.microbatch_id
}
func schedule_current_op(pipeline_schedule_state state) string {
    if len(state.ops) == 0 {
        return ""
    }
    int idx = state.step
    if idx >= len(state.ops) {
        idx = len(state.ops) - 1
    }
    state.ops[idx]
}
func new_schedule_gpipe(pipeline_plan plan) pipeline_schedule_state {
    int n = plan.chunks
    string[] ops = string[]{cap: 2 * n}
    int i = 0
    for i < n {
        ops[i] = "forward"
        i = i + 1
    }
    int j = 0
    for j < n {
        ops[n + j] = "backward"
        j = j + 1
    }
    new_schedule_state(plan, ops)
}
func new_schedule_gpipe_for_stage(pipeline_plan plan, int stage_index) pipeline_schedule_state {
    int n = plan.chunks
    string[] ops = string[]{cap: 2 * n}
    int i = 0
    for i < n {
        ops[i] = "forward"
        i = i + 1
    }
    int j = 0
    for j < n {
        ops[n + j] = "backward"
        j = j + 1
    }
    new_schedule_state_for_stage(plan, stage_index, ops)
}
func new_schedule_1f1b(pipeline_plan plan) pipeline_schedule_state {
    new_schedule_1f1b_for_stage(plan, 0)
}
func new_schedule_1f1b_for_stage(pipeline_plan plan, int stage_index) pipeline_schedule_state {
    int n = plan.chunks
    int warmup = schedule_warmup_steps(plan, stage_index)
    int steady = schedule_steady_steps(plan, stage_index)
    int flush = schedule_flush_steps(plan, stage_index)
    string[] ops = string[]{cap: warmup + steady + flush}
    int i = 0
    for i < warmup {
        ops[i] = "forward"
        i = i + 1
    }
    int j = 0
    for j < steady {
        ops[warmup + j] = "fwd_bwd"
        j = j + 1
    }
    int k = 0
    for k < flush {
        ops[warmup + steady + k] = "backward"
        k = k + 1
    }
    new_schedule_state_for_stage(plan, stage_index, ops)
}
func schedule_next(pipeline_schedule_state state) pipeline_schedule_state {
    if !state.active {
        return state
    }
    int next_step = state.step + 1
    int next_microbatch = state.microbatch_id + 1
    if next_microbatch >= state.plan.chunks {
        next_microbatch = 0
    }
    bool warmup_done = state.warmup_done || next_step >= state.plan.num_stages - 1
    bool flush_done = state.flush_done || next_step >= len(state.ops)
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(state.plan),
        stage_index: state.stage_index,
        step: next_step,
        microbatch_id: next_microbatch,
        ops: copy_strings(state.ops),
        warmup_done: warmup_done,
        flush_done: flush_done,
        active: state.active,
    }
}
func schedule_stop(pipeline_schedule_state state) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(state.plan),
        stage_index: state.stage_index,
        step: state.step,
        microbatch_id: state.microbatch_id,
        ops: copy_strings(state.ops),
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        active: false,
    }
}
func schedule_resume(pipeline_schedule_state state) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(state.plan),
        stage_index: state.stage_index,
        step: state.step,
        microbatch_id: state.microbatch_id,
        ops: copy_strings(state.ops),
        warmup_done: state.warmup_done,
        flush_done: state.flush_done,
        active: true,
    }
}
func schedule_reset(pipeline_schedule_state state) pipeline_schedule_state {
    pipeline_schedule_state {
        plan: pipeline_plan_state_dict(state.plan),
        stage_index: state.stage_index,
        step: 0,
        microbatch_id: 0,
        ops: copy_strings(state.ops),
        warmup_done: false,
        flush_done: false,
        active: state.active,
    }
}
func pipeline(pipeline_plan plan) pipeline_schedule_state {
    if plan.strategy == "1f1b" {
        return new_schedule_1f1b(plan)
    }
    new_schedule_gpipe(plan)
}
