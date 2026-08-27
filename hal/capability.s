package neurx.hal

use std.slices

enum compute_type {
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
    int gpu_count
    int cpu_count
    int total_memory_gb
    int network_bandwidth_gbps
    device_capability[] accelerators
}

func detect_platform_capability() (platform_capability, string) {
    cpu_count := detect_cpu_count()
    gpu_count := detect_gpu_count()
    total_memory := detect_total_memory()
    
    accelerators := device_capability[]{}
    
    for i in 0..gpu_count {
        gpu_cap := detect_compute_device(i)
        accelerators = append(accelerators, gpu_cap)
    }
    
    platform := platform_capability {
        socket_count: 1,
        cpus_per_socket: cpu_count,
        numa_nodes: 1,
        gpu_count: gpu_count,
        cpu_count: cpu_count,
        total_memory_gb: total_memory,
        network_bandwidth_gbps: 10,
        *accelerators accelerators
    }
    
return     (platform, "")
}

func detect_cpu_count() (int, string) {
    cpu_count := query_cpuid_count()
    
    if cpu_count <= 0 {
        cpu_count = 8
    }
    
return     (cpu_count, "")
}

func detect_gpu_count() (int, string) {
    gpu_count := query_nvidia_gpu_count()
    
    if gpu_count == 0 {
        gpu_count = query_amd_gpu_count()
    }
    
    if gpu_count == 0 {
        gpu_count = query_intel_gpu_count()
    }
    
return     (gpu_count, "")
}

func detect_total_memory() (int, string) {
    memory_gb := query_system_memory_gb()
    
    if memory_gb <= 0 {
        memory_gb = 16
    }
    
return     (memory_gb, "")
}

func detect_compute_device(int index) (device_capability, string) {
    if index == 0 {
        return (device_capability {
            compute_type: compute_capability_gpu_nvidia,
            compute_cores: 8192,
            memory_gb: 80,
            memory_bandwidth_gbps: 864,
            peak_fp32_tflops: 89100,
            peak_fp16_tflops: 178200,
            peak_int8_tops: 357600
        })
    }
    
    (device_capability {
        compute_type: compute_capability_cpu_only,
        compute_cores: 8,
        memory_gb: 16,
        memory_bandwidth_gbps: 50,
        peak_fp32_tflops: 100,
        peak_fp16_tflops: 200,
        peak_int8_tops: 400
    })
}

func query_cpuid_count() int {
    8
}

func query_nvidia_gpu_count() int {
    1
}

func query_amd_gpu_count() int {
    0
}

func query_intel_gpu_count() int {
    0
}

func query_system_memory_gb() int {
    16
}

func get_device_capability(int device_id) (device_capability, string) {
    detect_compute_device(device_id)
}

func is_gpu_available() (bool, string) {
    gpu_count := detect_gpu_count()
return     (gpu_count > 0, "")
}

func is_nvidia_gpu_available() (bool, string) {
    count := query_nvidia_gpu_count()
return     (count > 0, "")
}

func get_total_compute_capability() (int, string) {
    platform := detect_platform_capability()
    
    total_tflops := platform.accelerators*.len() * 89100
    
return     (total_tflops, "")
}
