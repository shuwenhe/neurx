package main
import (
    "neurx.inference.runtime.device_transformer."
    "neurx.inference.runtime.transformer_executor."
    "neurx.runtime.device.device_abi."
    "neurx.runtime.device.device_binding."
    "neurx.runtime.device.device_ops."
    "neurx.runtime.device.device_tensor."
    "neurx.runtime.device.vendor_lowering."
)

func main() {
    device_context context = device_open("cuda", 0, "{}")
    if !context.valid { print("FAIL: CUDA context: " + context.error_message + "\n"); return }
    device_tensor left = tensor_empty(context, [1024], "bf16")
    device_tensor right = tensor_empty(context, [1024], "bf16")
    device_tensor output = tensor_empty(context, [1024], "bf16")
    if !left.valid || !right.valid || !output.valid {
        print("FAIL: CUDA tensor allocation\n")
        tensor_release(output); tensor_release(right); tensor_release(left); device_close(context); return
    }
    lowered_op lowered = lower_device_op("cuda", true, op_residual_add("bf16", 1024))
    []string descriptor = make([]string, 1)
    descriptor[0] = lowered.descriptor
    transformer_execution_plan plan = transformer_descriptor_plan_compile(context, "cuda", descriptor, 0)
    []string binding = make([]string, 1)
    binding[0] = residual_add_binding(left.buffer, right.buffer, output.buffer, 1024)
    transformer_execution_result result = transformer_plan_execute(plan, binding, true)
    if result.success { print("PASS: S Transformer Executor launched CUDA BF16 Kernel\n") }
    else { print("FAIL: S Transformer Executor: " + result.error_message + "\n") }
    transformer_plan_release(plan)
    tensor_release(output); tensor_release(right); tensor_release(left); device_close(context)
}
