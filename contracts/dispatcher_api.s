package contracts

interface Dispatcher {

    func select_kernel(op_name: string, device: Device) -> Kernel
    func execute(op_name: string, inputs: []Tensor, device: Device) -> Tensor

    func register_kernel(op_name: string, device_type: DeviceType, kernel: Kernel)
    func register_operator(op_name: string, impl: OperatorImpl)

    func has_implementation(op_name: string, device_type: DeviceType) -> bool
    func list_operations() -> []string
    func list_devices_for_op(op_name: string) -> []DeviceType

    func set_fallback_device(device_type: DeviceType)
    func get_fallback_device() -> DeviceType
}

interface OperatorImpl {
    func forward(inputs: []Tensor) -> Tensor
    func backward(grad_output: Tensor, inputs: []Tensor) -> []Tensor
    func supports_device(device: Device) -> bool
}

struct DispatchContext {
    preferred_device: Device
    enable_autograd: bool
    enable_profiling: bool
}
