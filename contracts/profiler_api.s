import "device_api"
import "memory_api"















enum ProfilingMode {
    Disabled
    Enabled
    MemoryOnly
    TimeOnly
}

struct KernelProfile {
    kernel_name: string
    device: Device
    call_count: i64
    total_time_us: i64
    avg_time_us: i64
    min_time_us: i64
    max_time_us: i64
    memory_allocated: i64
    memory_freed: i64
}

struct OperatorProfile {
    op_name: string
    call_count: i64
    total_time_us: i64
    avg_time_us: i64
    input_shapes: [][]i64
    output_shapes: [][]i64
    memory_peak: i64
}

struct ProfilerSummary {
    total_time_us: i64
    kernel_profiles: map[string]KernelProfile
    operator_profiles: map[string]OperatorProfile
    memory_timeline: []i64
    device: Device
}

interface IProfiler {

    enable() -> void
    disable() -> void
    is_enabled() -> bool


    set_mode(mode: ProfilingMode) -> void
    get_mode() -> ProfilingMode


    reset() -> void


    get_profile() -> ProfilerSummary
}

interface IKernelProfiler {

    record_kernel(kernel_name: string, device: Device, time_us: i64) -> void


    record_memory(kernel_name: string, allocated: i64, freed: i64) -> void


    get_kernel_stats(kernel_name: string) -> KernelProfile


    list_kernels() -> []string
}

interface IOperatorProfiler {

    record_operator(op_name: string, time_us: i64, input_shapes: [][]i64, output_shapes: [][]i64) -> void


    get_operator_stats(op_name: string) -> OperatorProfile


    list_operators() -> []string
}

interface IMemoryProfiler {

    track_allocation(ptr: MemoryPtr, size: i64) -> void


    track_deallocation(ptr: MemoryPtr) -> void


    get_memory_peak() -> i64


    get_current_memory() -> i64


    get_memory_timeline() -> []i64
}

interface IProfilerExport {

    export_chrome_trace(path: string) -> void


    export_tensorboard(path: string) -> void


    export_perfetto(path: string) -> void


    export_json(path: string) -> void
}

interface IProfilerContext {

    push_scope(name: string) -> void


    pop_scope() -> void


    record_event(name: string, time_us: i64) -> void


    add_metadata(key: string, value: string) -> void
}

interface IProfilingGuard {





}
