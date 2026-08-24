package neurx.inference.runtime.transformer_executor
use neurx.inference.runtime.device_transformer.{transformer_schedule}
use neurx.runtime.device.device_abi.{device_context, device_operation_launch, device_stream_synchronize, device_context_error, device_stream_open_handle, device_stream_close_handle, device_operation_open_handle, device_operation_close_handle}

struct transformer_execution_plan {
    int context_handle
    int stream_handle
    []int operation_handle
    int operation_count
    string backend
    bool valid
    string error_message
}

struct transformer_execution_result {
    bool success
    int completed_operations
    int failed_operation
    string error_message
}

func transformer_plan_invalid(string backend, string message) transformer_execution_plan {
    transformer_execution_plan {context_handle: 0, stream_handle: 0, operation_handle: [], operation_count: 0, backend: backend, valid: false, error_message: message}
}

func transformer_descriptor_plan_compile(device_context context, string backend, []string descriptor, int stream_priority) transformer_execution_plan {
    if !context.valid { return transformer_plan_invalid(backend, "invalid_device_context") }
    if len(descriptor) <= 0 { return transformer_plan_invalid(backend, "empty_descriptor_plan") }
    if context.backend != backend && !(context.backend == "cann" && backend == "ascend") {
        return transformer_plan_invalid(backend, "backend_mismatch")
    }
    int stream_handle = device_stream_open_handle(context.handle, stream_priority)
    if stream_handle <= 0 { return transformer_plan_invalid(backend, "stream_create_failed") }
    int count = len(descriptor)
    []int compiled = []int{cap: count}
    int index = 0
    while index < count {
        if len(descriptor[index]) == 0 {
            int release_index = 0
            while release_index < index { device_operation_close_handle(context.handle, compiled[release_index]); release_index = release_index + 1 }
            device_stream_close_handle(context.handle, stream_handle)
            return transformer_plan_invalid(backend, "empty_descriptor")
        }
        int operation_handle = device_operation_open_handle(context.handle, descriptor[index])
        if operation_handle <= 0 {
            int release_index = 0
            while release_index < index { device_operation_close_handle(context.handle, compiled[release_index]); release_index = release_index + 1 }
            device_stream_close_handle(context.handle, stream_handle)
            return transformer_plan_invalid(backend, "operation_compile_failed_at_" + string(index))
        }
        compiled[index] = operation_handle
        index = index + 1
    }
    transformer_execution_plan {context_handle: context.handle, stream_handle: stream_handle, operation_handle: compiled, operation_count: count, backend: backend, valid: true, error_message: ""}
}

func transformer_plan_binding_valid(transformer_execution_plan plan, []string binding) bool {
    plan.valid && plan.operation_count > 0 && len(binding) == plan.operation_count
}

func transformer_plan_execute(transformer_execution_plan plan, []string binding, bool synchronize) transformer_execution_result {
    if !plan.valid { return transformer_execution_result {success: false, completed_operations: 0, failed_operation: -1, error_message: plan.error_message} }
    if len(binding) != plan.operation_count {
        return transformer_execution_result {success: false, completed_operations: 0, failed_operation: -1, error_message: "binding_count_mismatch"}
    }
    int index = 0
    while index < plan.operation_count {
        if len(binding[index]) == 0 {
            return transformer_execution_result {success: false, completed_operations: index, failed_operation: index, error_message: "empty_binding"}
        }
        int status = device_operation_launch(plan.context_handle, plan.operation_handle[index], plan.stream_handle, binding[index])
        if status != 0 {
            return transformer_execution_result {success: false, completed_operations: index, failed_operation: index, error_message: device_context_error(plan.context_handle)}
        }
        index = index + 1
    }
    if synchronize {
        int status = device_stream_synchronize(plan.context_handle, plan.stream_handle)
        if status != 0 {
            return transformer_execution_result {success: false, completed_operations: index, failed_operation: -1, error_message: device_context_error(plan.context_handle)}
        }
    }
    transformer_execution_result {success: true, completed_operations: index, failed_operation: -1, error_message: ""}
}

func transformer_plan_synchronize(transformer_execution_plan plan) int {
    if !plan.valid { return -1 }
    device_stream_synchronize(plan.context_handle, plan.stream_handle)
}

func transformer_plan_release(transformer_execution_plan plan) int {
    if !plan.valid { return 0 }
    int status = 0
    int index = plan.operation_count - 1
    while index >= 0 {
        if device_operation_close_handle(plan.context_handle, plan.operation_handle[index]) != 0 { status = -1 }
        index = index - 1
    }
    if device_stream_close_handle(plan.context_handle, plan.stream_handle) != 0 { status = -1 }
    status
}
