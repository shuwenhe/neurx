enum ComponentType {
    Kernel
    Operator
    device
    Allocator
    Optimizer
    Executor
    DataFormat
    Custom
}
struct registry_entry {
    component_type: ComponentType
    name: string
    namespace: string
    version: string
    impl_ptr: i64
    metadata: map[string]string
}
interface IRegistry {
    register(entry: registry_entry) -> void
    lookup(component_type: ComponentType, name: string) -> registry_entry
    lookup_namespaced(component_type: ComponentType, namespace: string, name: string) -> registry_entry
    has(component_type: ComponentType, name: string) -> bool
    list(component_type: ComponentType) -> []registry_entry
    unregister(component_type: ComponentType, name: string) -> void
}
interface IKernelRegistry {
    register_kernel(device: device, op_name: string, kernel_impl: Kernel) -> void
    get_kernel(op_name: string, device: device) -> Kernel
    list_kernels(op_name: string) -> []Kernel
    has_kernel(op_name: string, device: device) -> bool
}
interface IOperatorRegistry {
    register_operator(op_name: string, impl: OperatorImpl) -> void
    get_operator(op_name: string) -> OperatorImpl
    list_operators() -> []string
}
interface IDeviceRegistry {
    register_device(device_type: string, factory_ptr: i64) -> void
    get_device_factory(device_type: string) -> i64
    list_devices() -> []string
}
interface IAllocatorRegistry {
    register_allocator(device: device, name: string, allocator: IAllocator) -> void
    get_allocator(device: device, name: string) -> IAllocator
    get_default_allocator(device: device) -> IAllocator
    list_allocators(device: device) -> []string
}
interface IOptimizerRegistry {
    register_optimizer(name: string, factory_ptr: i64) -> void
    create_optimizer(name: string, params: []tensor) -> Optimizer
    list_optimizers() -> []string
}
interface IDataFormatRegistry {
    register_format(format_name: string, converter_ptr: i64) -> void
    get_format_converter(from_format: string, to_format: string) -> i64
    list_formats() -> []string
}
interface IPluginManager {
    load_plugin(path: string) -> void
    unload_plugin(path: string) -> void
    list_plugins() -> []string
    get_plugin_info(plugin_name: string) -> map[string]string
}
interface IGlobalRegistry {
    instance() -> IGlobalRegistry
    get_registry(component_type: ComponentType) -> IRegistry
    register_custom_registry(name: string, registry: IRegistry) -> void
}
interface IRegistryThreadSafety {
    acquire_write_lock() -> void
    release_write_lock() -> void
    is_locked() -> bool
}
