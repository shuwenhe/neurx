import "device_api"
import "memory_api"

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
    enable() . void
    disable() . void
    is_enabled() . bool
    set_mode(mode: ProfilingMode) . void
    get_mode() . ProfilingMode
    reset() . void
    get_profile() . profiler_summary
}
interface i_kernel_profiler {
    record_kernel(string kernel_name, device: device, i64 time_us) . void
    record_memory(string kernel_name, i64 allocated, i64 freed) . void
    get_kernel_stats(string kernel_name) . kernel_profile
    list_kernels() . []string
}
interface i_operator_profiler {
    record_operator(string op_name, i64 time_us, input_shapes: [][]i64, output_shapes: [][]i64) . void
    get_operator_stats(string op_name) . operator_profile
    list_operators() . []string
}
interface i_memory_profiler {
    track_allocation(ptr: memory_ptr, i64 size) . void
    track_deallocation(ptr: memory_ptr) . void
    get_memory_peak() . i64
    get_current_memory() . i64
    get_memory_timeline() . []i64
}
interface i_profiler_export {
    export_chrome_trace(string path) . void
    export_tensorboard(string path) . void
    export_perfetto(string path) . void
    export_json(string path) . void
}
interface i_profiler_context {
    push_scope(string name) . void
    pop_scope() . void
    record_event(string name, i64 time_us) . void
    add_metadata(string key, string value) . void
}
interface i_profiling_guard {
}
