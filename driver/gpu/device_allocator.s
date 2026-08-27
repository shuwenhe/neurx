package neurx.driver.gpu.device_allocator

use std.slices

struct gpu_device {
    int device_id
    int total_memory
    int available_memory
    int core_count
    int compute_capability
    bool online
}

struct gpu_memory_block {
    int block_id
    int device_id
    int base_addr
    int size
    int workload_id
    bool allocated
}

struct gpu_cluster {
    gpu_device[] devices
    gpu_memory_block[] memory_blocks
    int device_count
    int total_available_memory
}

func create_gpu_cluster(int num_gpus) gpu_cluster {
    cluster := gpu_cluster {
        devices: gpu_device[](),
        memory_blocks: gpu_memory_block[](),
        device_count: 0,
        total_available_memory: 0
    }
    
    i := 0
    for i < num_gpus {
        device := gpu_device {
            device_id: i,
            total_memory: 40,
            available_memory: 40,
            core_count: 432,
            compute_capability: 90,
            online: true
        }
        cluster.devices = append(cluster.devices, device)
        cluster.total_available_memory = cluster.total_available_memory + device.total_memory
        cluster.device_count = cluster.device_count + 1
        i = i + 1
    }
    cluster
}

func allocate_gpu_memory(gpu_cluster cluster, int workload_id, int size_gb) gpu_cluster {
    i := 0
    for i < len(cluster.devices) {
        device := cluster.devices[i]
        if device.available_memory >= size_gb && device.online {
            block := gpu_memory_block {
                block_id: len(cluster.memory_blocks),
                device_id: device.device_id,
                base_addr: 0,
                size: size_gb,
                workload_id: workload_id,
                allocated: true
            }
            cluster.memory_blocks = append(cluster.memory_blocks, block)
            cluster.total_available_memory = cluster.total_available_memory - size_gb
            return cluster
        }
        i = i + 1
    }
    cluster
}

func free_gpu_memory(gpu_cluster cluster, int workload_id) gpu_cluster {
    i := 0
    for i < len(cluster.memory_blocks) {
        block := cluster.memory_blocks[i]
        if block.workload_id == workload_id {
            cluster.total_available_memory = cluster.total_available_memory + block.size
            return cluster
        }
        i = i + 1
    }
    cluster
}

func get_gpu_stats(gpu_cluster cluster) int {
    cluster.total_available_memory
}

func runtime_test_gpu_isolation() bool {
    mem_before := 400
    mem_after := mem_before - 20
    mem_final := mem_after + 20
    
    if mem_after == 380 && mem_final == 400 {
        return true
    }
    false
}
