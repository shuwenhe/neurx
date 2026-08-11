import "execution_plan_api"
import "profiler_api"
enum execution_mode {
    eager
    compiled
    JIT
    AOT
}
struct execution_profile {
    total_time_us: i64
    kernel_profiles: map[string]kernel_profile
    memory_peak: i64
    memory_allocated: i64
    memory_freed: i64
    kernel_call_count: i64
}
interface i_executor {
    set_mode(mode: ExecutionMode) -> void
    get_mode() -> ExecutionMode
    execute_op(op_name: string, inputs: []tensor) -> tensor
    execute_graph(graph: computation_graph) -> tensor
    enable_profiling(enable: bool) -> void
    get_profile() -> execution_profile
    reset_profile() -> void
}
interface i_eager_executor {
    execute_with_profiling(op_name: string, inputs: []tensor) -> tensor
    execute_low_memory(op_name: string, inputs: []tensor) -> tensor
}
interface i_compiled_executor {
    compile(graph: computation_graph) -> execution_plan
    optimize(plan: execution_plan) -> execution_plan
    execute_plan(plan: execution_plan) -> tensor
    cache_plan(key: string, plan: execution_plan) -> void
    lookup_cached_plan(key: string) -> execution_plan
}
interface ijit_executor {
    get_or_compile(key: string, graph: computation_graph) -> execution_plan
    clear_cache() -> void
    get_cache_size() -> i64
    get_cache_hits() -> i64
    get_cache_misses() -> i64
}
interface iaot_executor {
    load_plan(path: string) -> execution_plan
    save_plan(path: string, plan: execution_plan) -> void
}
interface i_executor_memory_management {
    allocate_for_plan(plan: execution_plan) -> i64
    deallocate_plan(base_addr: i64) -> void
    get_memory_reuse_map(plan: execution_plan) -> map[string][]string
}
interface i_executor_stream_management {
    execute_on_stream(op_name: string, inputs: []tensor, stream: stream) -> tensor
    execute_plan_on_stream(plan: execution_plan, stream: stream) -> tensor
    wait_all_streams() -> void
}
interface i_executor_performance {
    estimate_time(graph: computation_graph) -> i64
    estimate_memory(graph: computation_graph) -> i64
    get_bottleneck_kernel(profile: execution_profile) -> string
}
