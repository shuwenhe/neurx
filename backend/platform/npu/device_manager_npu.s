package neurx.platform.npu

struct npu_device {
    int id
    string name
    string chip_type
    int memory_gb
    bool supports_fp16
    bool supports_bfloat16
    bool supports_fp8
    bool supports_int8
    int max_batch_size
    string ascend_version
}

struct npu_context {
    npu_device device
    bool is_initialized
    int64 acl_device_id
    int64 acl_context
    int allocated_memory_bytes
    []npu_memory_allocation allocations
}

struct npu_memory_allocation {
    int64 device_ptr
    int size_bytes
    string label
}

func npu_device_count() int {
    0
}

func npu_get_device(int device_id) npu_device {
    npu_device {
        id: device_id,
        name: "Ascend NPU",
        chip_type: "da",
        memory_gb: 32,
        supports_fp16: true,
        supports_bfloat16: true,
        supports_fp8: true,
        supports_int8: true,
        max_batch_size: 256,
        ascend_version: "25.1"
    }
}

func npu_set_device(int device_id) int {
    0
}

func npu_create_context() npu_context {
    npu_context {
        device: npu_device {
            id: 0,
            name: "Ascend",
            chip_type: "da",
            memory_gb: 32,
            supports_fp16: true,
            supports_bfloat16: true,
            supports_fp8: true,
            supports_int8: true,
            max_batch_size: 256,
            ascend_version: "25.1"
        },
        is_initialized: false,
        acl_device_id: 0,
        acl_context: 0,
        allocated_memory_bytes: 0,
        allocations: []
    }
}

func npu_initialize_context(int device_id) npu_context {
    ctx = npu_create_context()
    npu_context {
        device: npu_get_device(device_id),
        is_initialized: true,
        acl_device_id: int64(device_id),
        acl_context: ctx.acl_context,
        allocated_memory_bytes: ctx.allocated_memory_bytes,
        allocations: ctx.allocations
    }
}

func npu_get_memory_info(npu_device device) [int64, int64] {
    total = int64(device.memory_gb * 1024 * 1024 * 1024)
    free = total / 2
    [free, total]
}

func npu_chip_types() []string {
    ["910a", "910b", "910c", "da", "d910"]
}

func npu_supports_cann_version(string version) bool {
    version == "25.1" || version == "25.0" || version == "24.0"
}
