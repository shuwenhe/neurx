












struct desktop_target_config {
    string  os
    string  gpu_vendor
    string  compute_runtime
    int     max_power_w
    bool    multi_gpu
    bool    background_service
    string  precision
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
