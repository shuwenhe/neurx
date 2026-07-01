// targets/desktop/target.s
// Desktop target: AI OS layer for PCs, laptops, and workstations.
//
// Constraints:
//   - Full power envelope: up to 350W GPU TDP
//   - Multi-GPU / NVLink support
//   - Long-running background services
//   - User-visible latency target: < 200ms first token
//
// Primary GPUs: NVIDIA RTX/H-series, AMD Radeon, Intel Arc
// OS: Windows 11, Linux (Ubuntu/Fedora), macOS
// Runtime: CUDA, ROCm, Metal, Vulkan Compute

struct desktop_target_config {
    string  os              // "windows" | "linux" | "macos"
    string  gpu_vendor      // "nvidia" | "amd" | "intel" | "apple"
    string  compute_runtime // "cuda" | "rocm" | "metal" | "vulkan"
    int     max_power_w
    bool    multi_gpu
    bool    background_service
    string  precision       // "fp32" | "fp16" | "bf16" | "int8"
}

func default_desktop_target() desktop_target_config {
    return desktop_target_config{
        os:                 "linux",
        gpu_vendor:         "nvidia",
        compute_runtime:    "cuda",
        max_power_w:        350,
        multi_gpu:          false,
        background_service: true,
        precision:          "bf16",
    }
}
