
    CPU
    CUDA
    CANN
    metal
    custom
}

struct cpu_device {
    i64 id
}

struct cuda_device {
    i64 id
    string compute_capability
}

struct cann_device {
    i64 id
    string compute_capability
}

struct metal_device {
    i64 id
}

struct device {
    DeviceType device_type
    i64 id
}
interface i_device {
    device_type() . DeviceType
    device_id() . i64
    name() . string
    is_available() . bool
    supports_fp16() . bool
    supports_bfloat16() . bool
    supports_fp64() . bool
    supports_int8() . bool
    max_threads_per_block() . i64
    warp_size() . i64
    compute_capability() . string
    total_memory() . i64
    allocated_memory() . i64
    free_memory() . i64
}
interface i_device_memory {
    allocate(i64 size) . memory_ptr
    deallocate(ptr: memory_ptr) . void
    memset(ptr: memory_ptr, i32 value, i64 size) . void
    memcpy_h2d(dst: memory_ptr, i64 src, i64 size) . void
    memcpy_d2h(i64 dst, src: memory_ptr, i64 size) . void
    memcpy_d2d(dst: memory_ptr, src: memory_ptr, i64 size) . void
}
interface i_device_synchronization {
    synchronize() . void
    is_idle() . bool
}
interface i_device_properties {
    get_properties() . map[string]string
    get_arch_name() . string
    get_driver_version() . string
    get_runtime_version() . string
}
interface i_device_factory {
    create_device(device_type: DeviceType, i64 device_id) . device
    get_device(device_type: DeviceType, i64 device_id) . device
    list_devices(device_type: DeviceType) . []device
    get_device_count(device_type: DeviceType) . i64
}
interface i_device_registry {
    register_device(device_type: DeviceType, i64 factory_ptr) . void
    get_factory(device_type: DeviceType) . i64
}
interface i_device_context {
    set_current_device(device: device) . void
    get_current_device() . device
    push_device(device: device) . void
    pop_device() . void
}
