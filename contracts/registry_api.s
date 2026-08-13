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
    lookup(component_type: ComponentType, string name) -> registry_entry
    lookup_namespaced(component_type: ComponentType, string namespace, string name) -> registry_entry
    has(component_type: ComponentType, string name) -> bool
    list(component_type: ComponentType) -> []registry_entry
    unregister(component_type: ComponentType, string name) -> void
}
interface i_kernel_registry {
    register_kernel(device: device, string op_name, kernel_impl: Kernel) -> void
    get_kernel(string op_name, device: device) -> Kernel
    list_kernels(string op_name) -> []kernel
    has_kernel(string op_name, device: device) -> bool
}
interface i_operator_registry {
    register_operator(string op_name, impl: OperatorImpl) -> void
    get_operator(string op_name) -> OperatorImpl
    list_operators() -> []string
}
interface i_device_registry {
    register_device(string device_type, i64 factory_ptr) -> void
    get_device_factory(string device_type) -> i64
    list_devices() -> []string
}
interface i_allocator_registry {
    register_allocator(device: device, string name, allocator: IAllocator) -> void
    get_allocator(device: device, string name) -> IAllocator
    get_default_allocator(device: device) -> IAllocator
    list_allocators(device: device) -> []string
}
interface i_optimizer_registry {
    register_optimizer(string name, i64 factory_ptr) -> void
    create_optimizer(string name, params: []tensor) -> Optimizer
    list_optimizers() -> []string
}
interface i_data_format_registry {
    register_format(string format_name, i64 converter_ptr) -> void
    get_format_converter(string from_format, string to_format) -> i64
    list_formats() -> []string
}
interface i_plugin_manager {
    load_plugin(string path) -> void
    unload_plugin(string path) -> void
    list_plugins() -> []string
    get_plugin_info(string plugin_name) -> map[string]string
}
interface i_global_registry {
    instance() -> IGlobalRegistry
    get_registry(component_type: ComponentType) -> IRegistry
    register_custom_registry(string name, registry: IRegistry) -> void
}
interface i_registry_thread_safety {
    acquire_write_lock() -> void
    release_write_lock() -> void
    is_locked() -> bool
}
