enum DeviceType {
    CPU
    CUDA
    CANN
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

    device_type() -> DeviceType
    device_id() -> i64
    name() -> string

    is_available() -> bool
    supports_fp16() -> bool
    supports_bfloat16() -> bool
    supports_fp64() -> bool
    supports_int8() -> bool

    max_threads_per_block() -> i64
    warp_size() -> i64
    compute_capability() -> string

    total_memory() -> i64
    allocated_memory() -> i64
    free_memory() -> i64
}

interface IDeviceMemory {

    allocate(size: i64) -> MemoryPtr

    deallocate(ptr: MemoryPtr) -> void

    memset(ptr: MemoryPtr, value: i32, size: i64) -> void

    memcpy_h2d(dst: MemoryPtr, src: i64, size: i64) -> void

    memcpy_d2h(dst: i64, src: MemoryPtr, size: i64) -> void

    memcpy_d2d(dst: MemoryPtr, src: MemoryPtr, size: i64) -> void
}

interface IDeviceSynchronization {

    synchronize() -> void

    is_idle() -> bool

}

interface IDeviceProperties {

    get_properties() -> map[string]string

    get_arch_name() -> string

    get_driver_version() -> string

    get_runtime_version() -> string
}

interface IDeviceFactory {

    create_device(device_type: DeviceType, device_id: i64) -> Device

    get_device(device_type: DeviceType, device_id: i64) -> Device

    list_devices(device_type: DeviceType) -> []Device

    get_device_count(device_type: DeviceType) -> i64
}

interface IDeviceRegistry {

    register_device(device_type: DeviceType, factory_ptr: i64) -> void

    get_factory(device_type: DeviceType) -> i64
}

interface IDeviceContext {

    set_current_device(device: Device) -> void

    get_current_device() -> Device

    push_device(device: Device) -> void
    pop_device() -> void
}
