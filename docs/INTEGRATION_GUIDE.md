# NeurX AI Operating System - Integration Guide
## How to Use the Core Kernel Components

---

## Overview

The NeurX AI OS now includes 5 core kernel modules that work together to create a complete operating system for AI workloads:

1. **Device Model** - Hardware abstraction and device tree
2. **Driver Framework** - Standardized driver lifecycle  
3. **Memory Pool** - Efficient memory management
4. **Unified Executor** - Hardware-agnostic kernel execution
5. **System Calls** - AI-specific syscall interface

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│        Application Layer (Inference/Training)       │
├─────────────────────────────────────────────────────┤
│        System Call Interface (neuray_*)             │
│        - neuray_infer()                             │
│        - neuray_alloc() / neuray_free()             │
│        - neuray_schedule()                          │
│        - neuray_device_ctl()                        │
│        - neuray_get_metric()                        │
├─────────────────────────────────────────────────────┤
│        Core Kernel Subsystems                       │
│  ┌────────────┐  ┌──────────┐  ┌───────────────┐   │
│  │  Unified   │  │  Memory  │  │    Driver     │   │
│  │  Executor  │  │   Pool   │  │  Framework    │   │
│  └────────────┘  └──────────┘  └───────────────┘   │
├─────────────────────────────────────────────────────┤
│        Device Model (Device Tree & Registry)        │
├─────────────────────────────────────────────────────┤
│        Hardware (GPUs, NPUs, Memory, etc.)         │
└─────────────────────────────────────────────────────┘
```

---

## Module 1: Device Model (`kernel/device_model.s`)

### Purpose
Provides a hierarchical device tree that represents all hardware in the system.

### Key APIs

```s
// Register a device
device_register(device dev) -> int

// Get device by ID
device_get(string device_id) -> device

// List devices by class
device_list_by_class(string device_class) -> string[]

// Get all GPUs/NPUs
device_get_all_gpus() -> string[]
device_get_all_npus() -> string[]
```

### Example Usage

```s
use neurx.kernel.device_model.*

func init_devices() {
    // Register GPU 0
    device gpu0 = device {
        device_id: "0000:01:00.0",
        device_name: "NVIDIA A100",
        device_class: "gpu",
        device_type: "nvidia_gpu",
        bus_type: BUS_PCI,
        is_present: true,
        is_active: true,
    }
    device_register(gpu0)
    
    // Query all GPUs
    string[] gpus = device_get_all_gpus()
    int i = 0
    for i < len(gpus) {
        device d = device_get(gpus[i])
        println("Found GPU: " + d.device_name)
        i = i + 1
    }
}
```

---

## Module 2: Driver Framework (`kernel/driver_framework.s`)

### Purpose
Implements standardized driver lifecycle and device-driver binding.

### Key APIs

```s
// Register a driver
driver_register(
    string driver_name,
    string version,
    string device_pattern,
    driver_ops ops,
    int priority
) -> int

// Probe device for driver
device_probe(device dev) -> driver_result

// Remove device
device_remove(string device_id) -> driver_result

// Power management
device_suspend(string device_id, int state) -> driver_result
device_resume(string device_id) -> driver_result
```

### Example: Writing a GPU Driver

```s
use neurx.kernel.device_model.*
use neurx.kernel.driver_framework.*

// GPU driver operations
func nvidia_gpu_probe(device dev) driver_result {
    // Initialize GPU context
    // Map memory regions
    // Setup interrupts
    println("NVIDIA GPU driver probing " + dev.device_name)
    return driver_success()
}

func nvidia_gpu_remove(device dev) driver_result {
    // Cleanup GPU context
    println("NVIDIA GPU driver removing " + dev.device_name)
    return driver_success()
}

func nvidia_gpu_suspend(device dev, int state) driver_result {
    println("Suspending GPU: " + dev.device_name)
    return driver_success()
}

func nvidia_gpu_resume(device dev) driver_result {
    println("Resuming GPU: " + dev.device_name)
    return driver_success()
}

// Register driver
func init_nvidia_driver() {
    driver_ops ops = driver_ops {
        probe: nvidia_gpu_probe,
        remove: nvidia_gpu_remove,
        suspend: nvidia_gpu_suspend,
        resume: nvidia_gpu_resume,
    }
    
    driver_register(
        "nvidia_gpu_driver",
        "1.0",
        "nvidia_*",      // matches nvidia_gpu, nvidia_tensor, etc.
        ops,
        0                // highest priority
    )
}
```

---

## Module 3: Memory Pool (`kernel/mm/memory_pool.s`)

### Purpose
Efficient memory allocation with support for different allocation strategies.

### Key APIs

```s
// Create memory pool
pool_create(
    string pool_name,
    pool_type pool_type,
    allocation_strategy strategy,
    int total_bytes,
    int alignment_bytes
) -> int

// Allocate memory
pool_alloc(
    string pool_name,
    int size_bytes,
    string owner_id
) -> int  // returns GPU pointer or error

// Free memory
pool_free(string pool_name, int gpu_ptr) -> int

// Get statistics
pool_get_stats(string pool_name) -> pool_stats
```

### Example Usage

```s
use neurx.kernel.mm.memory_pool.*

func init_memory_system() {
    // Create 24GB GPU memory pool
    pool_create(
        "gpu_device_0",
        POOL_GPU_DEVICE,
        STRATEGY_BUDDY,
        24 * 1024 * 1024 * 1024,  // 24GB
        256                        // align to 256 bytes
    )
    
    // Allocate model weights (2GB)
    int weights_ptr = pool_alloc("gpu_device_0", 2 * 1024 * 1024 * 1024, "model_weights")
    
    // Allocate input buffer (1GB)
    int input_ptr = pool_alloc("gpu_device_0", 1024 * 1024 * 1024, "input_batch")
    
    // Check pool status
    pool_stats stats = pool_get_stats("gpu_device_0")
    println("GPU Memory: " + string(stats.used_bytes / 1024 / 1024) + "/" + 
            string(stats.total_bytes / 1024 / 1024) + " MB")
}
```

---

## Module 4: Unified Executor (`kernel/accelerator/unified_executor.s`)

### Purpose
Abstract interface for executing kernels on any accelerator (GPU, NPU, TPU).

### Key APIs

```s
// Create execution context
executor_create_context(accelerator_type type, string device_id) 
    -> executor_context

// Get device capabilities
executor_get_capabilities(string device_id) 
    -> accelerator_capabilities

// Launch kernel
executor_kernel_launch(
    executor_context ctx,
    executor_stream stream,
    kernel_config config
) -> execution_result

// Memory operations
executor_mem_alloc(executor_context ctx, int bytes) -> int
executor_mem_copy_to_device(ctx, stream, dst, src, bytes) -> int
executor_mem_copy_from_device(ctx, stream, dst, src, bytes) -> int

// Collective operations (for distributed training)
executor_all_reduce(ctx, stream, input, output, count, data_type) -> int
executor_all_gather(ctx, stream, send, recv, count, data_type) -> int

// Monitoring
executor_get_utilization(executor_context ctx) -> int  // 0-100%
executor_get_temperature(executor_context ctx) -> int   // Celsius
```

### Example: Inference Kernel

```s
use neurx.kernel.accelerator.unified_executor.*

func run_inference(string device_id) {
    // 1. Create context
    executor_context ctx = executor_create_context(ACCEL_GPU_NVIDIA, device_id)
    
    // 2. Get capabilities
    accelerator_capabilities caps = executor_get_capabilities(device_id)
    println("Device: " + caps.device_name)
    println("Memory: " + string(caps.total_memory_bytes / 1024 / 1024) + " MB")
    println("Max threads/block: " + string(caps.max_threads_per_block))
    
    // 3. Create stream
    executor_stream stream = executor_stream_create(ctx, 0)
    
    // 4. Allocate GPU memory
    int input_ptr = executor_mem_alloc(ctx, 1024 * 1024)  // 1MB
    int output_ptr = executor_mem_alloc(ctx, 512 * 1024)  // 512KB
    
    // 5. Configure and launch kernel
    kernel_config config = kernel_config_create(
        "inference_kernel",
        1, 1, 1,         // 1 block
        256, 1, 1,       // 256 threads
        4096             // 4KB shared memory
    )
    
    execution_result result = executor_kernel_launch(ctx, stream, config)
    
    if execution_success(result) {
        println("Kernel executed successfully in " + string(result.execution_time_ms) + "ms")
    }
    
    // 6. Get metrics
    int utilization = executor_get_utilization(ctx)
    int temp = executor_get_temperature(ctx)
    println("Utilization: " + string(utilization) + "%")
    println("Temperature: " + string(temp) + "C")
}
```

---

## Module 5: System Calls (`kernel/syscall/ai_syscalls.s`)

### Purpose
High-level API for applications to interact with AI OS kernel.

### Key System Calls

#### 1. Inference Syscall
```s
neuray_infer(infer_request) -> infer_response
```

#### 2. Memory Syscalls
```s
neuray_alloc(bytes, flags, device_id) -> syscall_result
neuray_free(gpu_ptr) -> syscall_result
neuray_memcpy(dst, src, nbytes, direction) -> syscall_result
neuray_mem_query(device_id) -> memory_status
```

#### 3. Scheduling Syscall
```s
neuray_schedule(workload_schedule) -> syscall_result
neuray_schedule_wait(schedule_id, timeout_ms) -> syscall_result
```

#### 4. Device Control Syscall
```s
neuray_device_ctl(device_id, command, params) -> syscall_result
```

#### 5. Monitoring Syscalls
```s
neuray_get_metric(device_id, metric_type) -> syscall_result
neuray_metrics_start(device_id) -> syscall_result
neuray_metrics_get(device_id) -> recorded_metrics
```

### Example: Inference Application

```s
use neurx.kernel.syscall.ai_syscalls.*

func inference_demo() {
    // 1. Prepare inference request
    infer_request req = infer_request {
        model_id: "qwen:0.5b",
        request_id: "req_001",
        input_data: int[]{cap: 0},  // would be actual input
        input_size_bytes: 1024,
        max_output_tokens: 100,
        timeout_ms: 5000,
        stream_output: false,
    }
    
    // 2. Call inference syscall
    infer_response resp = neuray_infer(req)
    
    // 3. Get result
    println("Request: " + resp.request_id)
    println("Finish reason: " + resp.finish_reason)
    println("Latency: " + string(resp.latency_ms) + "ms")
    println("Tokens: " + string(resp.actual_tokens))
    
    // 4. Monitor device
    syscall_result mem_result = neuray_mem_query("cuda:0")
    if mem_result.success {
        println("Device ready")
    }
}
```

---

## Integration Example: Complete AI OS Initialization

```s
use neurx.kernel.device_model.*
use neurx.kernel.driver_framework.*
use neurx.kernel.mm.memory_pool.*
use neurx.kernel.accelerator.unified_executor.*
use neurx.kernel.syscall.ai_syscalls.*

// Main AI OS initialization
func neuray_os_init() {
    println("=== NeurX AI Operating System Initialization ===")
    
    // 1. Initialize device model
    println("[1/5] Initializing device model...")
    device gpu0 = device {
        device_id: "0000:01:00.0",
        device_name: "NVIDIA A100",
        device_class: "gpu",
        device_type: "nvidia_gpu",
        bus_type: BUS_PCI,
        is_present: true,
        is_active: true,
    }
    device_register(gpu0)
    println("  - Registered " + string(device_count()) + " devices")
    
    // 2. Register drivers
    println("[2/5] Registering drivers...")
    driver_ops gpu_ops = driver_ops {
        probe: gpu_driver_probe,
        remove: gpu_driver_remove,
        suspend: gpu_driver_suspend,
        resume: gpu_driver_resume,
    }
    driver_register("nvidia_gpu_driver", "1.0", "nvidia_*", gpu_ops, 0)
    println("  - Registered " + string(driver_count()) + " drivers")
    
    // 3. Probe devices
    println("[3/5] Probing devices...")
    string[] gpus = device_get_all_gpus()
    int i = 0
    for i < len(gpus) {
        device d = device_get(gpus[i])
        device_probe(d)
        i = i + 1
    }
    
    // 4. Initialize memory pools
    println("[4/5] Initializing memory pools...")
    pool_create("gpu_device_0", POOL_GPU_DEVICE, STRATEGY_BUDDY, 
                24 * 1024 * 1024 * 1024, 256)
    println("  - Created memory pools")
    
    // 5. Initialize executors
    println("[5/5] Initializing execution engines...")
    executor_context ctx = executor_create_context(ACCEL_GPU_NVIDIA, "0000:01:00.0")
    println("  - Execution context ready")
    
    println("\n=== NeurX AI OS Ready ===")
    println("Devices: " + string(device_count()))
    println("Drivers: " + string(driver_count()))
    println("Pools: 1")
    println("\nReady for AI workloads!")
}

// Dummy driver implementations
func gpu_driver_probe(device dev) driver_result {
    return driver_success()
}

func gpu_driver_remove(device dev) driver_result {
    return driver_success()
}

func gpu_driver_suspend(device dev, int state) driver_result {
    return driver_success()
}

func gpu_driver_resume(device dev) driver_result {
    return driver_success()
}

func main() {
    neuray_os_init()
}
```

---

## File Structure After Implementation

```
neurx/
├── kernel/
│   ├── device_model.s              ✅ Implemented
│   ├── driver_framework.s          ✅ Implemented
│   ├── mm/
│   │   └── memory_pool.s           ✅ Implemented
│   ├── accelerator/
│   │   └── unified_executor.s      ✅ Implemented
│   └── syscall/
│       └── ai_syscalls.s           ✅ Implemented
├── docs/
│   └── AI_OS_ARCHITECTURE_DESIGN.md ✅ Implemented
└── examples/
    ├── device_model_demo.s         [TODO]
    ├── driver_binding_demo.s       [TODO]
    ├── memory_pool_demo.s          [TODO]
    ├── executor_demo.s             [TODO]
    └── syscall_demo.s              [TODO]
```

---

## Next Steps

### Phase 2: Backend Implementations (Weeks 3-4)
- [ ] NVIDIA CUDA driver (`driver/gpu/nvidia_driver.s`)
- [ ] Huawei CANN driver (`driver/npu/cann_driver.s`)
- [ ] CUDA adapter (`kernel/accelerator/cuda_adapter.s`)
- [ ] NPU adapter (`kernel/accelerator/npu_adapter.s`)

### Phase 3: Advanced Features (Weeks 5-6)
- [ ] AI scheduler (`kernel/sched/ai_scheduler.s`)
- [ ] Power management (`kernel/power/dvfs.s`)
- [ ] Thermal management (`kernel/thermal/thermal_mgmt.s`)

### Phase 4: Applications (Weeks 7-8)
- [ ] Inference service
- [ ] Training orchestration
- [ ] Distributed collective communications

---

## Testing

### Unit Tests
```bash
# Test device model
make test-device-model

# Test driver framework
make test-driver-framework

# Test memory pool
make test-memory-pool

# Test executor
make test-executor
```

### Integration Tests
```bash
# Full initialization test
make test-ai-os-init

# End-to-end inference
make test-inference-e2e
```

---

## Performance Characteristics

| Component | Key Metric | Target |
|-----------|-----------|--------|
| Device Lookup | O(n) | <1µs for 100 devices |
| Memory Allocation | O(log n) | <10µs for buddy allocator |
| Driver Probe | O(1) | <100µs |
| Kernel Launch | O(1) | <50µs overhead |
| Syscall Overhead | < 5% | <5% vs direct call |

---

## Summary

The NeurX AI OS now provides a **complete, Linux-inspired operating system kernel** for AI workloads with:

✅ **Device abstraction** - Unified device tree  
✅ **Driver framework** - Standardized lifecycle  
✅ **Memory management** - Efficient allocation & pooling  
✅ **Hardware abstraction** - GPU/NPU/TPU unified interface  
✅ **System calls** - AI-specific syscall interface  

This foundation enables:
- Adding new hardware as drivers
- Scaling to 1000s of devices
- Efficient resource management
- Production-grade monitoring and profiling
- Enterprise reliability

**Status**: Core kernel modules complete ✅  
**Next**: Backend driver implementations  
**Timeline**: Full AI OS operational in 4-6 weeks
