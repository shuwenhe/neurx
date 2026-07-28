// Executor API - Operation execution strategies
//
// Different execution modes for different scenarios:
// - Eager: immediate execution (training)
// - Compiled: pre-compiled (inference)
// - JIT: compile on-the-fly
// - AOT: ahead-of-time compilation
//
// Executor hooks into Profiler for measurement

import "execution_plan_api"
import "profiler_api"

enum ExecutionMode {
    Eager      // Execute immediately
    Compiled   // Pre-compiled execution
    JIT        // Compile on first run, cache
    AOT        // Ahead-of-time compiled
}

struct ExecutionProfile {
    total_time_us: i64
    kernel_profiles: map[string]KernelProfile
    memory_peak: i64
    memory_allocated: i64
    memory_freed: i64
    kernel_call_count: i64
}

interface IExecutor {
    // === Mode Management ===
    set_mode(mode: ExecutionMode) -> void
    get_mode() -> ExecutionMode
    
    // === Single Operation Execution ===
    execute_op(op_name: string, inputs: []Tensor) -> Tensor
    
    // === Graph Execution ===
    execute_graph(graph: ComputationGraph) -> Tensor
    
    // === Profiling ===
    enable_profiling(enable: bool) -> void
    get_profile() -> ExecutionProfile
    reset_profile() -> void
}

interface IEagerExecutor {
    // Eager execution: execute immediately
    // Used for training with dynamic graphs
    
    // Execute and record profiling
    execute_with_profiling(op_name: string, inputs: []Tensor) -> Tensor
    
    // Memory efficient (minimal buffering)
    execute_low_memory(op_name: string, inputs: []Tensor) -> Tensor
}

interface ICompiledExecutor {
    // Pre-compiled execution: compile then run
    // Used for inference
    
    // Compile graph to execution plan
    compile(graph: ComputationGraph) -> ExecutionPlan
    
    // Optimize execution plan
    optimize(plan: ExecutionPlan) -> ExecutionPlan
    
    // Execute compiled plan
    execute_plan(plan: ExecutionPlan) -> Tensor
    
    // Cache compiled plans
    cache_plan(key: string, plan: ExecutionPlan) -> void
    lookup_cached_plan(key: string) -> ExecutionPlan
}

interface IJITExecutor {
    // JIT execution: compile once, reuse
    
    // Get or compile
    get_or_compile(key: string, graph: ComputationGraph) -> ExecutionPlan
    
    // Clear JIT cache
    clear_cache() -> void
    
    // JIT statistics
    get_cache_size() -> i64
    get_cache_hits() -> i64
    get_cache_misses() -> i64
}

interface IAOTExecutor {
    // Ahead-of-time execution: pre-compiled binaries
    
    // Load pre-compiled plan
    load_plan(path: string) -> ExecutionPlan
    
    // Save compiled plan
    save_plan(path: string, plan: ExecutionPlan) -> void
}

interface IExecutorMemoryManagement {
    // Pre-allocate memory based on execution plan
    allocate_for_plan(plan: ExecutionPlan) -> i64  // base address
    
    // Deallocate plan memory
    deallocate_plan(base_addr: i64) -> void
    
    // Memory reuse tracking
    get_memory_reuse_map(plan: ExecutionPlan) -> map[string][]string
}

interface IExecutorStreamManagement {
    // Execute on specific stream (for async)
    execute_on_stream(op_name: string, inputs: []Tensor, stream: Stream) -> Tensor
    
    // Execute plan on stream
    execute_plan_on_stream(plan: ExecutionPlan, stream: Stream) -> Tensor
    
    // Synchronization
    wait_all_streams() -> void
}

interface IExecutorPerformance {
    // Estimate execution time
    estimate_time(graph: ComputationGraph) -> i64  // microseconds
    
    // Estimate memory
    estimate_memory(graph: ComputationGraph) -> i64
    
    // Get bottleneck kernel
    get_bottleneck_kernel(profile: ExecutionProfile) -> string
}

// === EXECUTION FLOW ===
// Training (Eager Mode):
// 1. Forward pass (Eager)
//    Operator → Dispatcher → Kernel → Device
// 2. Backward pass (Eager)
//    Gradient flows backward through graph
// 3. Optimizer step
//    Update parameters
//
// Inference (Compiled Mode):
// 1. Compile once
//    Graph → ExecutionPlan (with fusion, memory plan)
// 2. Execute repeatedly
//    ExecutionPlan → Fused Kernels → Device
// 3. No backward tracking
//    No computation graph overhead
