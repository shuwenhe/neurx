package neurx.kernel.syscall.ai_syscalls

use neurx.kernel.accelerator.unified_executor.{executor_context, execution_result}

enum syscall_error {
    ESYSCALL_OK,
    ESYSCALL_INVALID_ARG,
    ESYSCALL_NO_MEMORY,
    ESYSCALL_NO_DEVICE,
    ESYSCALL_TIMEOUT,
    ESYSCALL_NOT_SUPPORTED,
    ESYSCALL_PERMISSION_DENIED,
    ESYSCALL_BUSY,
    ESYSCALL_UNKNOWN,
}

struct syscall_result {
    bool success
    syscall_error error_code
    string error_message
    int return_value
}

struct infer_request {
    string model_id
    string request_id
    []byte input_data
    int input_size_bytes
    int max_output_tokens
    int timeout_ms
    bool stream_output
}

struct infer_response {
    string request_id
    []byte output_data
    int output_size_bytes
    int actual_tokens
    string finish_reason
    int latency_ms
}

func neuray_infer(infer_request req) infer_response {

    return infer_response {
        request_id: req.request_id,
        output_data: make([]byte, 0),
        output_size_bytes: 0,
        actual_tokens: 0,
        finish_reason: "error",
        latency_ms: 0,
    }
}

func neuray_infer_async(infer_request req) string {

    return req.request_id
}

func neuray_infer_result_get(string request_id) infer_response {

    return infer_response {
        request_id: request_id,
        output_data: make([]byte, 0),
        output_size_bytes: 0,
        finish_reason: "pending",
        latency_ms: 0,
    }
}

enum mem_alloc_flags {
    MEM_GPU_DEVICE,
    MEM_GPU_HOST,
    MEM_DMA_BUFFER,
    MEM_PERSISTENT,
    MEM_ASYNC_READY,
}

func neuray_alloc(
    int bytes,
    mem_alloc_flags flags,
    string device_id
) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

func neuray_free(int gpu_ptr) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

enum memcpy_direction {
    MEMCPY_H2D,
    MEMCPY_D2H,
    MEMCPY_D2D,
}

func neuray_memcpy(
    int dst_ptr,
    int src_ptr,
    int bytes,
    memcpy_direction direction,
    string dst_device,
    string src_device,
    int timeout_ms
) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

struct memory_status {
    int total_bytes
    int allocated_bytes
    int free_bytes
    int peak_allocated_bytes
    int fragmentation_percent
}

func neuray_mem_query(string device_id) memory_status {
    return memory_status {
        total_bytes: 0,
        allocated_bytes: 0,
        free_bytes: 0,
        peak_allocated_bytes: 0,
        fragmentation_percent: 0,
    }
}

enum workload_type {
    WL_INFERENCE_LATENCY,
    WL_INFERENCE_BATCH,
    WL_TRAINING,
    WL_DATA_LOAD,
    WL_SYNC_POINT,
}

struct workload_schedule {
    string workload_id
    workload_type wl_type
    int priority
    int deadline_ms
    []string resource_hints
}

func neuray_schedule(workload_schedule wl) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

func neuray_schedule_wait(
    int schedule_id,
    int timeout_ms
) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

enum device_ctl_command {
    DEV_CTL_QUERY_STATUS,
    DEV_CTL_SET_CLOCK,
    DEV_CTL_SET_POWER_LIMIT,
    DEV_CTL_RESET,
    DEV_CTL_SUSPEND,
    DEV_CTL_RESUME,
    DEV_CTL_GET_METRICS,
}

func neuray_device_ctl(
    string device_id,
    device_ctl_command cmd,
    []byte params,
    int params_size
) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

enum metric_type {
    METRIC_UTILIZATION,
    METRIC_POWER,
    METRIC_TEMPERATURE,
    METRIC_MEMORY_USED,
    METRIC_BANDWIDTH,
    METRIC_LATENCY,
}

func neuray_get_metric(
    string device_id,
    metric_type metric
) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

func neuray_metrics_start(string device_id) syscall_result {
    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

struct recorded_metrics {
    int sample_count
    []int timestamps
    []int utilization
    []int power_watts
    []int temperature_c
    []int bandwidth_gbps
}

func neuray_metrics_get(string device_id) recorded_metrics {
    return recorded_metrics {
        sample_count: 0,
        timestamps: []int{},
        utilization: []int{},
        power_watts: []int{},
        temperature_c: []int{},
        bandwidth_gbps: []int{},
    }
}

func neuray_get_error() string {

    return ""
}

func neuray_clear_error() syscall_result {
    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

func neuray_trace_enable(string component) syscall_result {

    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

func neuray_trace_disable(string component) syscall_result {
    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: 0,
    }
}

enum syscall_id {
    SYS_INFER = 1,
    SYS_ALLOC = 2,
    SYS_FREE = 3,
    SYS_MEMCPY = 4,
    SYS_SCHEDULE = 5,
    SYS_DEVICE_CTL = 6,
    SYS_GET_METRIC = 7,
    SYS_GET_ERROR = 8,
}

struct syscall_dispatcher {

}

func syscall_ok(int return_value) syscall_result {
    return syscall_result {
        success: true,
        error_code: ESYSCALL_OK,
        error_message: "",
        return_value: return_value,
    }
}

func syscall_error(syscall_error error_code, string message) syscall_result {
    return syscall_result {
        success: false,
        error_code: error_code,
        error_message: message,
        return_value: -1,
    }
}

func error_to_string(syscall_error err) string {
    if err == ESYSCALL_OK { return "OK" }
    if err == ESYSCALL_INVALID_ARG { return "INVALID_ARG" }
    if err == ESYSCALL_NO_MEMORY { return "NO_MEMORY" }
    if err == ESYSCALL_NO_DEVICE { return "NO_DEVICE" }
    if err == ESYSCALL_TIMEOUT { return "TIMEOUT" }
    if err == ESYSCALL_NOT_SUPPORTED { return "NOT_SUPPORTED" }
    if err == ESYSCALL_PERMISSION_DENIED { return "PERMISSION_DENIED" }
    if err == ESYSCALL_BUSY { return "BUSY" }
    return "UNKNOWN"
}
