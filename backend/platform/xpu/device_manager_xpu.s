package neurx.platform.xpu

struct xpu_device {
    int id
    string name
    string gpu_type
    int slices
    int sub_slices_per_slice
    int total_memory_bytes
    int free_memory_bytes
    bool supports_fp16
    bool supports_bfloat16
    bool supports_int8
    int max_compute_units
}

struct xpu_context {
    xpu_device device
    bool is_initialized
    int64 oneapi_handle
    int64 level_zero_handle
    int allocated_memory_bytes
    []xpu_memory_allocation allocations
}

struct xpu_memory_allocation {
    int64 device_ptr
    int size_bytes
    string label
}

func xpu_device_count() int {
    0
}

func xpu_get_device(int device_id) xpu_device {
    xpu_device {
        id: device_id,
        name: "Intel Arc GPU",
        gpu_type: "arc",
        slices: 8,
        sub_slices_per_slice: 16,
        total_memory_bytes: 8589934592,
        free_memory_bytes: 6442450944,
        supports_fp16: true,
        supports_bfloat16: true,
        supports_int8: true,
        max_compute_units: 128
    }
}

func xpu_set_device(int device_id) int {
    0
}

func xpu_create_context() xpu_context {
    xpu_context {
        device: xpu_device {
            id: 0,
            name: "Intel GPU",
            gpu_type: "arc",
            slices: 8,
            sub_slices_per_slice: 16,
            total_memory_bytes: 8589934592,
            free_memory_bytes: 6442450944,
            supports_fp16: true,
            supports_bfloat16: true,
            supports_int8: true,
            max_compute_units: 128
        },
        is_initialized: false,
        oneapi_handle: 0,
        level_zero_handle: 0,
        allocated_memory_bytes: 0,
        allocations: []
    }
}

func xpu_initialize_context(int device_id) xpu_context {
    ctx = xpu_create_context()
    xpu_context {
        device: xpu_get_device(device_id),
        is_initialized: true,
        oneapi_handle: ctx.oneapi_handle,
        level_zero_handle: ctx.level_zero_handle,
        allocated_memory_bytes: ctx.allocated_memory_bytes,
        allocations: ctx.allocations
    }
}

func xpu_get_memory_info(xpu_device device) [int, int] {
    [device.free_memory_bytes, device.total_memory_bytes]
}

func xpu_supported_compute_capabilities() string[] {
    ["gen12", "dg1", "alchemist"]
}

func xpu_get_compute_capability(xpu_device device) string {
    if device.max_compute_units > 256 {
        return "alchemist"
    }
    if device.max_compute_units > 128 {
        return "dg1"
    }
    "gen12"
}
