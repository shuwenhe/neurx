// Device API - Hardware abstraction (Resources only)
//
// Device manages:
// - Memory allocation/deallocation
// - Device properties and capabilities
// - Synchronization (device-level)
// - Basic info queries
//
// Device does NOT manage:
// - Stream creation (use StreamManager instead)
// - Event recording (use StreamManager instead)
// - Async operations (use Stream + Event instead)
//
// This keeps Device simple and focused on resource management.

enum DeviceType {
    CPU
    CUDA     // with device_id
    CANN     // with device_id
    Metal
    Custom
}

struct CPUDevice {
    id: i64
}

struct CUDADevice {
    id: i64
    compute_capability: string
}

struct CANNDevice {
    id: i64
    compute_capability: string
}

struct MetalDevice {
    id: i64
}

struct Device {
    device_type: DeviceType
    id: i64
}

interface IDevice {
    // === Identity ===
    device_type() -> DeviceType
    device_id() -> i64
    name() -> string
    
    // === Capabilities ===
    is_available() -> bool
    supports_fp16() -> bool
    supports_bfloat16() -> bool
    supports_fp64() -> bool
    supports_int8() -> bool
    
    // === Compute ===
    max_threads_per_block() -> i64
    warp_size() -> i64
    compute_capability() -> string
    
    // === Memory ===
    total_memory() -> i64
    allocated_memory() -> i64
    free_memory() -> i64
}

interface IDeviceMemory {
    // Allocate on device
    allocate(size: i64) -> MemoryPtr
    
    // Deallocate from device
    deallocate(ptr: MemoryPtr) -> void
    
    // Set memory value
    memset(ptr: MemoryPtr, value: i32, size: i64) -> void
    
    // Copy host to device
    memcpy_h2d(dst: MemoryPtr, src: i64, size: i64) -> void
    
    // Copy device to host
    memcpy_d2h(dst: i64, src: MemoryPtr, size: i64) -> void
    
    // Copy device to device
    memcpy_d2d(dst: MemoryPtr, src: MemoryPtr, size: i64) -> void
}

interface IDeviceSynchronization {
    // Block until all device work completes
    synchronize() -> void
    
    // Check if device is idle
    is_idle() -> bool
    
    // Block on stream (actual sync via Stream, not Device)
    // This is only for device-level synchronization
}

interface IDeviceProperties {
    // Get detailed device properties
    get_properties() -> map[string]string
    
    // Get architecture name
    get_arch_name() -> string
    
    // Get driver version
    get_driver_version() -> string
    
    // Get runtime version
    get_runtime_version() -> string
}

interface IDeviceFactory {
    // Create device by type
    create_device(device_type: DeviceType, device_id: i64) -> Device
    
    // Get device by ID
    get_device(device_type: DeviceType, device_id: i64) -> Device
    
    // List available devices
    list_devices(device_type: DeviceType) -> []Device
    
    // Get device count
    get_device_count(device_type: DeviceType) -> i64
}

interface IDeviceRegistry {
    // Register device type
    register_device(device_type: DeviceType, factory_ptr: i64) -> void
    
    // Get device factory
    get_factory(device_type: DeviceType) -> i64
}

interface IDeviceContext {
    // Set current device (thread-local)
    set_current_device(device: Device) -> void
    
    // Get current device
    get_current_device() -> Device
    
    // Push/pop device context (RAII)
    push_device(device: Device) -> void
    pop_device() -> void
}
