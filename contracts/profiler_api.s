import "device_api"
import "memory_api"
enum profiling_mode {
    disabled
    enabled
    memory_only
    time_only
}
struct kernel_profile {
    kernel_name: string
    device: device
    call_count: i64
    total_time_us: i64
    avg_time_us: i64
    min_time_us: i64
    max_time_us: i64
    memory_allocated: i64
    memory_freed: i64
}
struct operator_profile {
    op_name: string
    call_count: i64
    total_time_us: i64
    avg_time_us: i64
    input_shapes: [][]i64
    output_shapes: [][]i64
    memory_peak: i64
}
struct profiler_summary {
    total_time_us: i64
    kernel_profiles: map[string]kernel_profile
    operator_profiles: map[string]operator_profile
    memory_timeline: []i64
    device: device
}
interface i_profiler {
    enable() -> void
    disable() -> void
    is_enabled() -> bool
    set_mode(mode: ProfilingMode) -> void
    get_mode() -> ProfilingMode
    reset() -> void
    get_profile() -> profiler_summary
}
interface i_kernel_profiler {
    record_kernel(kernel_name: string, device: device, time_us: i64) -> void
    record_memory(kernel_name: string, allocated: i64, freed: i64) -> void
    get_kernel_stats(kernel_name: string) -> kernel_profile
    list_kernels() -> []string
}
interface i_operator_profiler {
    record_operator(op_name: string, time_us: i64, input_shapes: [][]i64, output_shapes: [][]i64) -> void
    get_operator_stats(op_name: string) -> operator_profile
    list_operators() -> []string
}
interface i_memory_profiler {
    track_allocation(ptr: memory_ptr, size: i64) -> void
    track_deallocation(ptr: memory_ptr) -> void
    get_memory_peak() -> i64
    get_current_memory() -> i64
    get_memory_timeline() -> []i64
}
interface i_profiler_export {
    export_chrome_trace(path: string) -> void
    export_tensorboard(path: string) -> void
    export_perfetto(path: string) -> void
    export_json(path: string) -> void
}
interface i_profiler_context {
    push_scope(name: string) -> void
    pop_scope() -> void
    record_event(name: string, time_us: i64) -> void
    add_metadata(key: string, value: string) -> void
}
interface i_profiling_guard {
}
