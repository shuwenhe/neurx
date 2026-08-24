package neurx.platform.backends

struct backend_info {
    string name
    string path
    string description
    []string supported_architectures
}

func get_all_backends() []backend_info {
    [
        backend_info {
            name: "cuda",
            path: "neurx.platform.cuda",
            description: "NVIDIA CUDA GPU backend",
            supported_architectures: ["sm_50", "sm_60", "sm_70", "sm_75", "sm_80", "sm_86", "sm_89", "sm_90"]
        },
        backend_info {
            name: "rocm",
            path: "neurx.platform.rocm",
            description: "AMD ROCm GPU backend",
            supported_architectures: ["gfx906", "gfx908", "gfx90a", "gfx940", "gfx941", "gfx942", "gfx1100", "gfx1150", "gfx1201"]
        },
        backend_info {
            name: "cpu",
            path: "neurx.platform.cpu",
            description: "CPU backend for all architectures",
            supported_architectures: ["x86", "x86_64", "arm", "aarch64", "ppc64le", "s390x"]
        },
        backend_info {
            name: "mps",
            path: "neurx.platform.mps",
            description: "Apple Metal Performance Shaders backend",
            supported_architectures: ["apple_silicon_m1", "apple_silicon_m2", "apple_silicon_m3", "apple_silicon_m4"]
        },
        backend_info {
            name: "tpu",
            path: "neurx.platform.tpu",
            description: "Google TPU backend",
            supported_architectures: ["tpuv2", "tpuv3", "tpuv4", "tpuv5e"]
        },
        backend_info {
            name: "xpu",
            path: "neurx.platform.xpu",
            description: "Intel XPU backend",
            supported_architectures: ["gen12", "dg1", "alchemist"]
        },
        backend_info {
            name: "npu",
            path: "neurx.platform.npu",
            description: "Huawei Ascend NPU backend",
            supported_architectures: ["910a", "910b", "910c", "da"]
        },
        backend_info {
            name: "musa",
            path: "neurx.platform.musa",
            description: "Tencent MUSA GPU backend",
            supported_architectures: ["musa_compute_20", "musa_compute_22"]
        },
        backend_info {
            name: "mlx",
            path: "neurx.platform.mlx",
            description: "Apple MLX framework backend",
            supported_architectures: ["mlx_gpu", "mlx_cpu"]
        },
        backend_info {
            name: "zen",
            path: "neurx.platform.zen",
            description: "AMD Zen CPU specialized backend",
            supported_architectures: ["zen", "zen2", "zen3", "zen4"]
        }
    ]
}

func get_backend_by_name(string name) backend_info {
    backends = get_all_backends()
    i = 0
    while i < len(backends) {
        if backends[i].name == name {
            return backends[i]
        }
        i = i + 1
    }
    backend_info {
        name: "unknown",
        path: "neurx.platform.unknown",
        description: "Unknown backend",
        supported_architectures: []
    }
}

func backend_is_available(string name) bool {
    if name == "cuda" {
        return true
    }
    if name == "rocm" {
        return true
    }
    if name == "cpu" {
        return true
    }
    if name == "mps" {
        return true
    }
    false
}

func list_backend_paths() []string {
    [
        "neurx.platform.cuda",
        "neurx.platform.rocm",
        "neurx.platform.cpu",
        "neurx.platform.mps"
    ]
}

func get_backend_description(string name) string {
    info = get_backend_by_name(name)
    info.description
}

func get_supported_architectures(string backend_name) []string {
    info = get_backend_by_name(backend_name)
    info.supported_architectures
}
