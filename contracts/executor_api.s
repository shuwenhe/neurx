









import "execution_plan_api"
import "profiler_api"

enum ExecutionMode {
    Eager
    Compiled
    JIT
    AOT
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

    set_mode(mode: ExecutionMode) -> void
    get_mode() -> ExecutionMode


    execute_op(op_name: string, inputs: []Tensor) -> Tensor


    execute_graph(graph: ComputationGraph) -> Tensor


    enable_profiling(enable: bool) -> void
    get_profile() -> ExecutionProfile
    reset_profile() -> void
}

interface IEagerExecutor {




    execute_with_profiling(op_name: string, inputs: []Tensor) -> Tensor


    execute_low_memory(op_name: string, inputs: []Tensor) -> Tensor
}

interface ICompiledExecutor {




    compile(graph: ComputationGraph) -> ExecutionPlan


    optimize(plan: ExecutionPlan) -> ExecutionPlan


    execute_plan(plan: ExecutionPlan) -> Tensor


    cache_plan(key: string, plan: ExecutionPlan) -> void
    lookup_cached_plan(key: string) -> ExecutionPlan
}

interface IJITExecutor {



    get_or_compile(key: string, graph: ComputationGraph) -> ExecutionPlan


    clear_cache() -> void


    get_cache_size() -> i64
    get_cache_hits() -> i64
    get_cache_misses() -> i64
}

interface IAOTExecutor {



    load_plan(path: string) -> ExecutionPlan


    save_plan(path: string, plan: ExecutionPlan) -> void
}

interface IExecutorMemoryManagement {

    allocate_for_plan(plan: ExecutionPlan) -> i64


    deallocate_plan(base_addr: i64) -> void


    get_memory_reuse_map(plan: ExecutionPlan) -> map[string][]string
}

interface IExecutorStreamManagement {

    execute_on_stream(op_name: string, inputs: []Tensor, stream: Stream) -> Tensor


    execute_plan_on_stream(plan: ExecutionPlan, stream: Stream) -> Tensor


    wait_all_streams() -> void
}

interface IExecutorPerformance {

    estimate_time(graph: ComputationGraph) -> i64


    estimate_memory(graph: ComputationGraph) -> i64


    get_bottleneck_kernel(profile: ExecutionProfile) -> string
}

















