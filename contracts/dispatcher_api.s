package contracts
interface dispatcher {
    func select_kernel(string op_name, device device) -> Kernel

    func execute(string op_name, []tensor inputs, device device) -> tensor

    func register_kernel(string op_name, DeviceType device_type, Kernel kernel)

    func register_operator(string op_name, OperatorImpl impl)

    func has_implementation(string op_name, DeviceType device_type) -> bool

    func list_operations() -> []string

    func list_devices_for_op(string op_name) -> []device_type

    func set_fallback_device(DeviceType device_type)

    func get_fallback_device() -> DeviceType
}
interface operator_impl {
    func forward([]tensor inputs) -> tensor

    func backward(tensor grad_output, []tensor inputs) -> []tensor

    func supports_device(device device) -> bool
}

struct dispatch_context {
    preferred_device: device
    enable_autograd: bool
    enable_profiling: bool
}
