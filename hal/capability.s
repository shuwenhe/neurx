package neurx.hal

enum compute_capability {
    cpu_only,
    gpu_nvidia,
    gpu_amd,
    gpu_intel,
    tpu_google,
    asic_custom
}

struct device_capability {
    compute_capability compute_type
    int compute_cores
    int memory_gb
    int memory_bandwidth_gbps
    int peak_fp32_tflops
    int peak_fp16_tflops
    int peak_int8_tops
}

struct platform_capability {
    int socket_count
    int cpus_per_socket
    int numa_nodes
    vec[device_capability]* accelerators
    int total_memory_gb
    int network_bandwidth_gbps
}

func detect_platform_capability() platform_capability {
    platform_capability {
        socket_count: 1,
        cpus_per_socket: 8,
        numa_nodes: 1,
        accelerators: vec[device_capability](),
        total_memory_gb: 16,
        network_bandwidth_gbps: 10
    }
}

func detect_compute_device(index: int) device_capability {
    device_capability {
        compute_type: compute_capability::cpu_only,
        compute_cores: 8,
        memory_gb: 16,
        memory_bandwidth_gbps: 50,
        peak_fp32_tflops: 100,
        peak_fp16_tflops: 200,
        peak_int8_tops: 400
    }
}
