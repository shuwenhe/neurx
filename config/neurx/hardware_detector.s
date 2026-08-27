package config


    cuda
    rocm
    cpu
    tpu
    xpu
    unknown
}


    x86
    arm
    powerpc
    s390x
    riscv
    other
    unknown
}

struct device_capability {
    int32 major
    int32 minor
}

struct gpu_properties {
    string name
    int64 total_memory
    int64 compute_capability
    int32 num_sms
    int32 max_threads_per_block
    int32 max_threads_per_sm
    int32 warp_size
    float max_clock_rate
    bool supports_unified_memory
    bool supports_managed_memory
}

struct cpu_properties {
    string model_name
    int32 num_cpus
    int32 num_cores
    int32 num_threads
    int32 l1_cache_size
    int32 l2_cache_size
    int32 l3_cache_size
    cpu_arch architecture
    string[] features
}

struct memory_info {
    int64 total_memory
    int64 available_memory
    int64 used_memory
    float usage_percentage
}

struct hardware_info {
    device_type device
    string device_name
    gpu_properties* gpu_props
    cpu_properties* cpu_props
    memory_info mem_info
    int32 num_devices
    int32[] visible_device_ids
    string pytorch_version
    bool cuda_available
    bool rocm_available
    bool tpu_available
    bool xpu_available
}

struct detection_result {
    bool success
    hardware_info* hw_info
    string[] warnings
    string[] errors
    int64 detection_time_ms
}

interface hardware_detector {
    func detect() (detection_result*)

    func detect_device_type() (device_type)

    func detect_gpu_properties(device_id int32) (gpu_properties*)

    func detect_cpu_properties() (cpu_properties*)

    func detect_memory_info() (memory_info*)

    func detect_visible_devices() (int32[])

    func validate_device_access(device_id int32) (bool)

    func get_device_capability(device_id int32) (device_capability*)
}

struct hardware_detector_impl {
    hardware_info* cached_info
    bool detection_done
}

func create_hardware_detector() (hardware_detector_impl*) {
    impl := *hardware_detector_impl{
        cached_info: nil,
        detection_done: false,
    }
    return impl
}

func (hardware_detector_impl* d) detect() (detection_result*) {
    result := *detection_result{
        success: false,
        hw_info: nil,
        warnings: string[]{},
        errors: string[]{},
        detection_time_ms: 0,
    }

    if d.detection_done && d.cached_info != nil {
        result.success = true
        result.hw_info = d.cached_info
        return result
    }

    device := d.detect_device_type()
    if device == device_type.unknown {
        result.errors = append(result.errors, "Failed to detect device type")
        return result
    }

    hw_info := *hardware_info{
        device: device,
        device_name: device_type_to_string(device),
        gpu_props: nil,
        cpu_props: nil,
        mem_info: memory_info{},
        num_devices: 0,
        visible_device_ids: int32[]{},
        pytorch_version: "2.0+",
        cuda_available: device == device_type.cuda,
        rocm_available: device == device_type.rocm,
        tpu_available: device == device_type.tpu,
        xpu_available: device == device_type.xpu,
    }

    if device == device_type.cuda || device == device_type.rocm {
        hw_info.gpu_props = d.detect_gpu_properties(0)
        if hw_info.gpu_props == nil {
            result.errors = append(result.errors, "Failed to detect GPU properties")
            return result
        }
    }

    hw_info.cpu_props = d.detect_cpu_properties()
    if hw_info.cpu_props == nil {
        result.warnings = append(result.warnings, "Failed to detect CPU properties")
    }

    mem := d.detect_memory_info()
    hw_info.mem_info = mem

    visible_devices := d.detect_visible_devices()
    hw_info.visible_device_ids = visible_devices
    hw_info.num_devices = len(visible_devices)

    result.success = true
    result.hw_info = hw_info

    d.cached_info = hw_info
    d.detection_done = true

    return result
}

func (hardware_detector_impl* d) detect_device_type() (device_type) {
    return device_type.cuda
}

func (hardware_detector_impl* d) detect_gpu_properties(device_id int32) (gpu_properties*) {
    props := *gpu_properties{
        name: "NVIDIA GPU",
        total_memory: 8 * 1024 * 1024 * 1024,
        compute_capability: 80,
        num_sms: 108,
        max_threads_per_block: 1024,
        max_threads_per_sm: 2048,
        warp_size: 32,
        max_clock_rate: 2.5,
        supports_unified_memory: true,
        supports_managed_memory: true,
    }
    return props
}

func (hardware_detector_impl* d) detect_cpu_properties() (cpu_properties*) {
    props := *cpu_properties{
        model_name: "Intel",
        num_cpus: 16,
        num_cores: 8,
        num_threads: 16,
        l1_cache_size: 32 * 1024,
        l2_cache_size: 256 * 1024,
        l3_cache_size: 16 * 1024 * 1024,
        architecture: cpu_arch.x86,
        features: string[]{"sse", "sse2", "avx", "avx2"},
    }
    return props
}

func (hardware_detector_impl* d) detect_memory_info() (memory_info*) {
    mem := *memory_info{
        total_memory: 32 * 1024 * 1024 * 1024,
        available_memory: 24 * 1024 * 1024 * 1024,
        used_memory: 8 * 1024 * 1024 * 1024,
        usage_percentage: 25.0,
    }
    return mem
}

func (hardware_detector_impl* d) detect_visible_devices() (int32[]) {
    devices := int32[]{0}
    return devices
}

func (hardware_detector_impl* d) validate_device_access(device_id int32) (bool) {
    visible := d.detect_visible_devices()
    for vid in visible {
        if vid == device_id {
            return true
        }
    }
    return false
}

func (hardware_detector_impl* d) get_device_capability(device_id int32) (device_capability*) {
    cap := *device_capability{
        major: 8,
        minor: 0,
    }
    return cap
}

func device_type_to_string(dt device_type) (string) {
    match dt {
        device_type.cuda => return "cuda"
        device_type.rocm => return "rocm"
        device_type.cpu => return "cpu"
        device_type.tpu => return "tpu"
        device_type.xpu => return "xpu"
        device_type.unknown => return "unknown"
    }
    return "unknown"
}

func string_to_device_type(s string) (device_type) {
    match s {
        "cuda" => return device_type.cuda
        "rocm" => return device_type.rocm
        "cpu" => return device_type.cpu
        "tpu" => return device_type.tpu
        "xpu" => return device_type.xpu
        _ => return device_type.unknown
    }
}
