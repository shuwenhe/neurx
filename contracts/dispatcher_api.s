package contracts
interface dispatcher {
    func select_kernel(op_name: string, device: device) -> Kernel
    func execute(op_name: string, inputs: []tensor, device: device) -> tensor
    func register_kernel(op_name: string, device_type: DeviceType, kernel: Kernel)
    func register_operator(op_name: string, impl: OperatorImpl)
    func has_implementation(op_name: string, device_type: DeviceType) -> bool
    func list_operations() -> []string
    func list_devices_for_op(op_name: string) -> []device_type
    func set_fallback_device(device_type: DeviceType)
    func get_fallback_device() -> DeviceType
}
interface operator_impl {
    func forward(inputs: []tensor) -> tensor
    func backward(grad_output: tensor, inputs: []tensor) -> []tensor
    func supports_device(device: device) -> bool
}

struct dispatch_context {
    preferred_device: device
    enable_autograd: bool
    enable_profiling: bool
}
