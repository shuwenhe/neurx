struct fusion_info {
    kernel_ids: []i64
    fused_kernel_name: string
    expected_speedup: f64
}

struct kernel_launch_info {
    kernel_id: i64
    kernel_name: string
    device: device
    grid_size: []i64
    block_size: []i64
    shared_memory: i64
    stream: stream
}

struct memory_allocation_plan {
    tensor_id: i64
    offset: i64
    size: i64
    lifetime_start: i64
    lifetime_end: i64
}

struct execution_plan {
    id: i64
    kernel_launches: []kernel_launch_info
    memory_plan: []memory_allocation_plan
    fusion_groups: []fusion_info
    total_memory: i64
    estimated_time_us: i64
}
interface i_execution_plan {
    plan_id() -> i64
    kernel_launches() -> []kernel_launch_info
    memory_plan() -> []memory_allocation_plan
    fusion_groups() -> []fusion_info
    total_memory() -> i64
    estimated_time() -> i64
}
interface i_execution_planner {
    build_plan(graph: computation_graph) -> execution_plan
    optimize_plan(plan: execution_plan) -> execution_plan
    estimate_memory(plan: execution_plan) -> i64
    estimate_time(plan: execution_plan) -> i64
}
interface i_fusion_optimizer {
    find_fusion_groups(plan: execution_plan) -> []fusion_info
    apply_fusion(plan: execution_plan, fusion: fusion_info) -> execution_plan
    can_fuse(k1: kernel_launch_info, k2: kernel_launch_info) -> bool
}
interface i_memory_planner {
    allocate_plan_memory(plan: execution_plan) -> i64
    get_allocation(tensor_id: i64) -> memory_allocation_plan
    deallocate_plan_memory(base_addr: i64) -> void
}
interface icuda_graph_builder {
    build_cuda_graph(plan: execution_plan) -> i64
    launch_cuda_graph(graph_handle: i64, stream: stream) -> void
    destroy_cuda_graph(graph_handle: i64) -> void
    can_reuse_graph(plan: execution_plan) -> bool
}
interface i_dynamic_shape_handler {
    update_plan_for_shapes(plan: execution_plan, shapes: [][]i64) -> execution_plan
    is_compatible(plan: execution_plan, shapes: [][]i64) -> bool
}

