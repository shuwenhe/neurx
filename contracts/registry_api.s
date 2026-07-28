// Registry API - Centralized component registration
//
// All components register through Registry:
// - Kernels
// - Operators
// - Devices
// - Allocators
// - Optimizers
// - Data formats
//
// This is the plugin system foundation for:
// - Custom backends
// - Extensions
// - Custom kernels
//
// Inspired by:
// - PyTorch (Dispatcher)
// - LLVM (Registry)
// - ONNX Runtime (KernelRegistry)

enum ComponentType {
    Kernel
    Operator
    Device
    Allocator
    Optimizer
    Executor
    DataFormat
    Custom
}

struct RegistryEntry {
    component_type: ComponentType
    name: string
    namespace: string
    version: string
    impl_ptr: i64
    metadata: map[string]string
}

interface IRegistry {
    // Register a component
    register(entry: RegistryEntry) -> void
    
    // Lookup component by name
    lookup(component_type: ComponentType, name: string) -> RegistryEntry
    
    // Lookup with namespace
    lookup_namespaced(component_type: ComponentType, namespace: string, name: string) -> RegistryEntry
    
    // Check if registered
    has(component_type: ComponentType, name: string) -> bool
    
    // List all registered components
    list(component_type: ComponentType) -> []RegistryEntry
    
    // Unregister component
    unregister(component_type: ComponentType, name: string) -> void
}

interface IKernelRegistry {
    // Register kernel
    register_kernel(device: Device, op_name: string, kernel_impl: Kernel) -> void
    
    // Get kernel for op
    get_kernel(op_name: string, device: Device) -> Kernel
    
    // List all kernels for op
    list_kernels(op_name: string) -> []Kernel
    
    // Check if kernel exists
    has_kernel(op_name: string, device: Device) -> bool
}

interface IOperatorRegistry {
    // Register operator
    register_operator(op_name: string, impl: OperatorImpl) -> void
    
    // Get operator
    get_operator(op_name: string) -> OperatorImpl
    
    // List all operators
    list_operators() -> []string
}

interface IDeviceRegistry {
    // Register device type
    register_device(device_type: string, factory_ptr: i64) -> void
    
    // Get device factory
    get_device_factory(device_type: string) -> i64
    
    // List supported devices
    list_devices() -> []string
}

interface IAllocatorRegistry {
    // Register allocator for device
    register_allocator(device: Device, name: string, allocator: IAllocator) -> void
    
    // Get allocator
    get_allocator(device: Device, name: string) -> IAllocator
    
    // Get default allocator
    get_default_allocator(device: Device) -> IAllocator
    
    // List allocators for device
    list_allocators(device: Device) -> []string
}

interface IOptimizerRegistry {
    // Register optimizer
    register_optimizer(name: string, factory_ptr: i64) -> void
    
    // Create optimizer by name
    create_optimizer(name: string, params: []Tensor) -> Optimizer
    
    // List optimizers
    list_optimizers() -> []string
}

interface IDataFormatRegistry {
    // Register data format
    register_format(format_name: string, converter_ptr: i64) -> void
    
    // Get format converter
    get_format_converter(from_format: string, to_format: string) -> i64
    
    // List formats
    list_formats() -> []string
}

interface IPluginManager {
    // Load plugin from library
    load_plugin(path: string) -> void
    
    // Unload plugin
    unload_plugin(path: string) -> void
    
    // List loaded plugins
    list_plugins() -> []string
    
    // Get plugin metadata
    get_plugin_info(plugin_name: string) -> map[string]string
}

interface IGlobalRegistry {
    // Get singleton instance
    instance() -> IGlobalRegistry
    
    // Get component registry
    get_registry(component_type: ComponentType) -> IRegistry
    
    // Register custom registry
    register_custom_registry(name: string, registry: IRegistry) -> void
}

// Thread-safety guarantee:
// All registry operations are thread-safe (internal locking)
// Multiple readers, single writer lock for modifications

interface IRegistryThreadSafety {
    // Lock registry for exclusive access
    acquire_write_lock() -> void
    release_write_lock() -> void
    
    // Check if locked
    is_locked() -> bool
}
