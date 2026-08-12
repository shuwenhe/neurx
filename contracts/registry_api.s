enum component_type {
    kernel
    operator
    device
    allocator
    optimizer
    executor
    data_format
    custom
}
struct registry_entry {
    component_type: ComponentType
    name: string
    namespace: string
    version: string
    impl_ptr: i64
    metadata: map[string]string
}
interface i_registry {
    register(entry: registry_entry) -> void
    lookup(component_type: ComponentType, name: string) -> registry_entry
    lookup_namespaced(component_type: ComponentType, namespace: string, name: string) -> registry_entry
    has(component_type: ComponentType, name: string) -> bool
    list(component_type: ComponentType) -> []registry_entry
    unregister(component_type: ComponentType, name: string) -> void
}
interface i_kernel_registry {
    register_kernel(device: device, op_name: string, kernel_impl: Kernel) -> void
    get_kernel(op_name: string, device: device) -> Kernel
    list_kernels(op_name: string) -> []kernel
    has_kernel(op_name: string, device: device) -> bool
}
interface i_operator_registry {
    register_operator(op_name: string, impl: OperatorImpl) -> void
    get_operator(op_name: string) -> OperatorImpl
    list_operators() -> []string
}
interface i_device_registry {
    register_device(device_type: string, factory_ptr: i64) -> void
    get_device_factory(device_type: string) -> i64
    list_devices() -> []string
}
interface i_allocator_registry {
    register_allocator(device: device, name: string, allocator: IAllocator) -> void
    get_allocator(device: device, name: string) -> IAllocator
    get_default_allocator(device: device) -> IAllocator
    list_allocators(device: device) -> []string
}
interface i_optimizer_registry {
    register_optimizer(name: string, factory_ptr: i64) -> void
    create_optimizer(name: string, params: []tensor) -> Optimizer
    list_optimizers() -> []string
}
interface i_data_format_registry {
    register_format(format_name: string, converter_ptr: i64) -> void
    get_format_converter(from_format: string, to_format: string) -> i64
    list_formats() -> []string
}
interface i_plugin_manager {
    load_plugin(path: string) -> void
    unload_plugin(path: string) -> void
    list_plugins() -> []string
    get_plugin_info(plugin_name: string) -> map[string]string
}
interface i_global_registry {
    instance() -> IGlobalRegistry
    get_registry(component_type: ComponentType) -> IRegistry
    register_custom_registry(name: string, registry: IRegistry) -> void
}
interface i_registry_thread_safety {
    acquire_write_lock() -> void
    release_write_lock() -> void
    is_locked() -> bool
}
