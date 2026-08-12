package contracts
interface dispatcher {
    func select_kernel(string op_name, device: device) -> Kernel
    func execute(string op_name, inputs: []tensor, device: device) -> tensor
    func register_kernel(string op_name, device_type: DeviceType, kernel: Kernel)
    func register_operator(string op_name, impl: OperatorImpl)
    func has_implementation(string op_name, device_type: DeviceType) -> bool
    func list_operations() -> []string
    func list_devices_for_op(string op_name) -> []device_type
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

