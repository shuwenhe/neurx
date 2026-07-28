import "device_api"
import "memory_api"

// Profiler API - Performance monitoring and analysis
//
// Profiler is NOT embedded in Kernel.
// Profiler is at Executor/Dispatcher level.
//
// Kernel never knows profiler exists.
// Profiler hooks at:
// - Executor (overall time)
// - Dispatcher (kernel selection)
// - Operator (math operation time)
// - Stream (device time)
//
// Outputs to: Chrome Trace, TensorBoard, Perfetto, etc.

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
    memory_timeline: []i64  // memory usage over time
    device: Device
}

interface IProfiler {
    // Enable/disable profiling
    enable() -> void
    disable() -> void
    is_enabled() -> bool
    
    // Set mode
    set_mode(mode: ProfilingMode) -> void
    get_mode() -> ProfilingMode
    
    // Reset profiling data
    reset() -> void
    
    // Get execution profile
    get_profile() -> ProfilerSummary
}

interface IKernelProfiler {
    // Record kernel execution
    record_kernel(kernel_name: string, device: Device, time_us: i64) -> void
    
    // Record kernel memory
    record_memory(kernel_name: string, allocated: i64, freed: i64) -> void
    
    // Get kernel stats
    get_kernel_stats(kernel_name: string) -> KernelProfile
    
    // List all kernels
    list_kernels() -> []string
}

interface IOperatorProfiler {
    // Record operator execution
    record_operator(op_name: string, time_us: i64, input_shapes: [][]i64, output_shapes: [][]i64) -> void
    
    // Get operator stats
    get_operator_stats(op_name: string) -> OperatorProfile
    
    // List all operators
    list_operators() -> []string
}

interface IMemoryProfiler {
    // Track memory allocation
    track_allocation(ptr: MemoryPtr, size: i64) -> void
    
    // Track memory deallocation
    track_deallocation(ptr: MemoryPtr) -> void
    
    // Get memory peak
    get_memory_peak() -> i64
    
    // Get current memory usage
    get_current_memory() -> i64
    
    // Get memory timeline
    get_memory_timeline() -> []i64
}

interface IProfilerExport {
    // Export to Chrome trace format
    export_chrome_trace(path: string) -> void
    
    // Export to TensorBoard format
    export_tensorboard(path: string) -> void
    
    // Export to Perfetto format
    export_perfetto(path: string) -> void
    
    // Export to JSON
    export_json(path: string) -> void
}

interface IProfilerContext {
    // Push scope (for nested timing)
    push_scope(name: string) -> void
    
    // Pop scope
    pop_scope() -> void
    
    // Record event
    record_event(name: string, time_us: i64) -> void
    
    // Add metadata
    add_metadata(key: string, value: string) -> void
}

interface IProfilingGuard {
    // RAII guard for profiling a scope
    // Usage: guard = create_profiling_guard("kernel_name")
    // ... code to profile ...
    // guard.finish()
    // (automatically records time)
}
