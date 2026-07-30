














struct FusionInfo {
    kernel_ids: []i64
    fused_kernel_name: string
    expected_speedup: f64
}

struct KernelLaunchInfo {
    kernel_id: i64
    kernel_name: string
    device: Device
    grid_size: []i64
    block_size: []i64
    shared_memory: i64
    stream: Stream
}

struct MemoryAllocationPlan {
    tensor_id: i64
    offset: i64
    size: i64
    lifetime_start: i64
    lifetime_end: i64
}

struct ExecutionPlan {
    id: i64


    kernel_launches: []KernelLaunchInfo


    memory_plan: []MemoryAllocationPlan


    fusion_groups: []FusionInfo


    total_memory: i64


    estimated_time_us: i64
}

interface IExecutionPlan {

    plan_id() -> i64


    kernel_launches() -> []KernelLaunchInfo


    memory_plan() -> []MemoryAllocationPlan


    fusion_groups() -> []FusionInfo


    total_memory() -> i64


    estimated_time() -> i64
}

interface IExecutionPlanner {

    build_plan(graph: ComputationGraph) -> ExecutionPlan


    optimize_plan(plan: ExecutionPlan) -> ExecutionPlan


    estimate_memory(plan: ExecutionPlan) -> i64


    estimate_time(plan: ExecutionPlan) -> i64
}

interface IFusionOptimizer {

    find_fusion_groups(plan: ExecutionPlan) -> []FusionInfo


    apply_fusion(plan: ExecutionPlan, fusion: FusionInfo) -> ExecutionPlan


    can_fuse(k1: KernelLaunchInfo, k2: KernelLaunchInfo) -> bool
}

interface IMemoryPlanner {

    allocate_plan_memory(plan: ExecutionPlan) -> i64


    get_allocation(tensor_id: i64) -> MemoryAllocationPlan


    deallocate_plan_memory(base_addr: i64) -> void
}

interface ICUDAGraphBuilder {

    build_cuda_graph(plan: ExecutionPlan) -> i64


    launch_cuda_graph(graph_handle: i64, stream: Stream) -> void


    destroy_cuda_graph(graph_handle: i64) -> void


    can_reuse_graph(plan: ExecutionPlan) -> bool
}

interface IDynamicShapeHandler {

    update_plan_for_shapes(plan: ExecutionPlan, shapes: [][]i64) -> ExecutionPlan


    is_compatible(plan: ExecutionPlan, shapes: [][]i64) -> bool
}
