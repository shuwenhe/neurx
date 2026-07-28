// Execution Plan API - Pre-planned kernel execution
//
// For Phase 11+ (Compiler, Fusion, CUDA Graph):
// - Graph operations are compiled to ExecutionPlan
// - Plan specifies kernel order, memory allocation, fusion
// - Can be reused for multiple forward passes
//
// ExecutionPlan -> Fusion -> CUDA Graph -> Kernel Launch
//
// This allows:
// - Memory reuse across iterations
// - Fused kernel execution
// - Graph capture and replay
// - Dynamic shape handling

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
    
    // Kernel execution order
    kernel_launches: []KernelLaunchInfo
    
    // Memory allocations
    memory_plan: []MemoryAllocationPlan
    
    // Fusion information
    fusion_groups: []FusionInfo
    
    // Total memory needed
    total_memory: i64
    
    // Estimated time (microseconds)
    estimated_time_us: i64
}

interface IExecutionPlan {
    // Properties
    plan_id() -> i64
    
    // Get kernel launches in order
    kernel_launches() -> []KernelLaunchInfo
    
    // Get memory plan
    memory_plan() -> []MemoryAllocationPlan
    
    // Get fusion groups
    fusion_groups() -> []FusionInfo
    
    // Total memory required
    total_memory() -> i64
    
    // Estimated execution time
    estimated_time() -> i64  // microseconds
}

interface IExecutionPlanner {
    // Build execution plan from computation graph
    build_plan(graph: ComputationGraph) -> ExecutionPlan
    
    // Optimize plan (fusion, memory reuse)
    optimize_plan(plan: ExecutionPlan) -> ExecutionPlan
    
    // Estimate memory usage
    estimate_memory(plan: ExecutionPlan) -> i64
    
    // Estimate execution time
    estimate_time(plan: ExecutionPlan) -> i64  // microseconds
}

interface IFusionOptimizer {
    // Find fusible kernels
    find_fusion_groups(plan: ExecutionPlan) -> []FusionInfo
    
    // Apply fusion
    apply_fusion(plan: ExecutionPlan, fusion: FusionInfo) -> ExecutionPlan
    
    // Check if two kernels can be fused
    can_fuse(k1: KernelLaunchInfo, k2: KernelLaunchInfo) -> bool
}

interface IMemoryPlanner {
    // Allocate memory for plan
    allocate_plan_memory(plan: ExecutionPlan) -> i64  // base address
    
    // Get allocation for tensor
    get_allocation(tensor_id: i64) -> MemoryAllocationPlan
    
    // Deallocate plan memory
    deallocate_plan_memory(base_addr: i64) -> void
}

interface ICUDAGraphBuilder {
    // Build CUDA graph from execution plan
    build_cuda_graph(plan: ExecutionPlan) -> i64  // graph handle
    
    // Launch CUDA graph
    launch_cuda_graph(graph_handle: i64, stream: Stream) -> void
    
    // Destroy CUDA graph
    destroy_cuda_graph(graph_handle: i64) -> void
    
    // Check if CUDA graph can be reused
    can_reuse_graph(plan: ExecutionPlan) -> bool
}

interface IDynamicShapeHandler {
    // Handle dynamic shapes in plan
    update_plan_for_shapes(plan: ExecutionPlan, shapes: [][]i64) -> ExecutionPlan
    
    // Check if plan is shape-compatible
    is_compatible(plan: ExecutionPlan, shapes: [][]i64) -> bool
}
