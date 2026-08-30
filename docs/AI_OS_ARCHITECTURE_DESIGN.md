# NeurX AI Operating System - Architecture Design
## Inspired by Linux Kernel Design (2026-08-30)

---

## Executive Summary

This document outlines the transformation of NeurX from an inference framework into a **complete AI Operating System (AI OS)** by adopting core architectural patterns from the Linux kernel. The design emphasizes:

- **Device Driver Framework** - Unified interface for all accelerators (GPU, NPU, TPU, etc.)
- **Memory Management System** - AI-optimized buffer allocation and DMA handling
- **Modular Kernel Architecture** - Loadable kernel modules for components
- **Scalable Scheduler** - Workload-aware scheduling for AI inference
- **Standardized System Interface** - syscall-like API for applications
- **Power Management** - Dynamic resource scaling for efficiency

---

## Part 1: Architecture Overview

### 1.1 System Layers (Inspired by Linux 7-Layer Model)

```
┌─────────────────────────────────────────────────────────┐
│  Application & Service Layer                            │
│  (inference, training, serving, agents)                 │
├─────────────────────────────────────────────────────────┤
│  System Call Interface (AI-specific syscalls)           │
│  ├─ neuray_infer()     (inference request)              │
│  ├─ neuray_alloc()     (memory allocation)              │
│  ├─ neuray_schedule()  (workload scheduling)            │
│  └─ neuray_device_ctl()    (device control)             │
├─────────────────────────────────────────────────────────┤
│  Core Kernel (scheduler, mm, irq)                       │
│  ├─ AI Scheduler (workload-aware)                       │
│  ├─ Memory Manager (DMA, buffer pools)                  │
│  ├─ Device Manager (device tree, PM)                    │
│  └─ Module System (LKM support)                         │
├─────────────────────────────────────────────────────────┤
│  Device Driver Framework                                │
│  ├─ Device Model (platform, pci, acpi)                  │
│  ├─ Driver Model (probe, remove, suspend, resume)       │
│  ├─ Bus Support (PCIe, NVLink, Ethernet)                │
│  └─ Device Classes (gpu, accelerator, memory)           │
├─────────────────────────────────────────────────────────┤
│  Accelerator Subsystem                                  │
│  ├─ GPU Backend (NVIDIA, AMD, Intel)                    │
│  ├─ NPU Backend (Huawei CANN, others)                   │
│  ├─ TPU Backend (Google, custom)                        │
│  └─ Unified Executor (kernel abstraction)               │
├─────────────────────────────────────────────────────────┤
│  Hardware Abstraction Layer (HAL)                       │
│  ├─ Device I/O (registers, DMA, interrupts)             │
│  ├─ Clock/Power (DVFS, turbo boost)                     │
│  ├─ Thermal (temperature monitoring, throttling)        │
│  └─ Event System (device hotplug, errors)               │
├─────────────────────────────────────────────────────────┤
│  Hardware (GPUs, NPUs, TPUs, Memory Subsystem)          │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Comparison: Linux Kernel Structure vs NeurX AI OS

| Component | Linux | NeurX AI OS | Purpose |
|-----------|-------|-----------|---------|
| `drivers/` | 50+ categories | `driver/` (unified) | Device abstractions |
| `arch/` | Multi-ISA | `arch/x86_64/` (AI ops) | Architecture-specific |
| `kernel/sched/` | CFS, RT | `kernel/sched/ai_scheduler.s` | AI workload scheduling |
| `mm/` | Page cache, swapping | `mm/dma_buffer_pool.s` | GPU memory management |
| `kernel/irq/` | Exception handling | `kernel/irq/device_events.s` | Device interrupt model |
| `net/` | TCP/IP stack | `net/collective_comm.s` | All-reduce, all-gather |
| `kernel/module/` | LKM loader | `kernel/module/lkm_loader.s` | Dynamic component loading |

---

## Part 2: Core Subsystems

### 2.1 Device Driver Framework (DVF)

#### 2.1.1 Device Model Hierarchy

```
Device Tree Root
├─ Platform Device 1 (CPU, chipset)
├─ PCI Bus 0
│  ├─ GPU Device (0000:01:00.0)
│  │  ├─ driver: gpu_driver
│  │  ├─ resources: memory, irq, dma
│  │  └─ subsystems: compute, memory, thermal
│  └─ NIC Device (0000:02:00.0)
├─ I2C Bus (temperature, power sensors)
└─ ACPI Platform Devices
```

#### 2.1.2 Driver Interface (S Language)

```s
package neurx.kernel.driver

// Device descriptor
struct device {
    string device_id        // "0000:01:00.0"
    string driver_name      // "gpu_driver"
    string device_class     // "gpu" or "accelerator"
    int bus_type           // PCI, platform, acpi
    
    // Resource descriptors
    int irq_count
    int[] irq_numbers
    
    // Driver-specific context
    int driver_private
    
    // Device state
    bool present
    bool active
    int power_state
}

// Driver interface - all drivers must implement this
struct driver_ops {
    // Device discovery and binding
    func probe(device dev) int         // 0=success, !0=error
    func remove(device dev) int
    func suspend(device dev, int state) int
    func resume(device dev) int
    
    // Interrupt handling
    func irq_handler(device dev, int irq) int
}

// Driver registration
struct registered_driver {
    string driver_name
    string device_pattern   // "gpu_*" or "0000:01:00.*"
    driver_ops ops
    int priority           // 0=highest, 10=lowest
}

// Module initialization - all drivers implement this
func driver_module_init() int {
    // Platform driver registration
    return driver_register(...driver_ops)
}
```

#### 2.1.3 Key Driver Implementations

1. **GPU Driver** (`driver/gpu/gpu_driver.s`)
   - Device enumeration via PCIe
   - Memory mapping (BAR0-BAR5)
   - Command queue registration
   - Interrupt handler setup

2. **NPU Driver** (`driver/npu/npu_driver.s`)
   - CANN device initialization
   - Context management
   - Stream creation and management

3. **Memory Driver** (`driver/memory/memory_driver.s`)
   - DMA buffer allocation
   - Page pinning/unpinning
   - IOMMU integration

### 2.2 Accelerator Subsystem (Unified Interface)

#### 2.2.1 Accelerator Abstraction

```s
package neurx.kernel.accelerator

// Accelerator capabilities
struct accelerator_caps {
    string device_name      // "nvidia:0" or "huawei:npu0"
    string device_type      // "gpu", "npu", "tpu"
    int compute_capability  // SM version (80 for RTX40) or equivalent
    
    // Memory subsystem
    int total_memory_bytes
    int l2_cache_bytes
    int shared_memory_per_sm
    
    // Compute metrics
    int max_warps_per_sm    // 32 for modern GPUs
    int max_threads_per_sm
    int max_blocks_per_sm
    
    // Clock and power
    int max_clock_mhz
    int tdp_watts
    
    // Features
    bool supports_nvlink
    bool supports_tensor_core
    bool supports_npu_ops
}

// Execution context (like CUDA context, but abstracted)
struct accelerator_context {
    string device_id
    int ctx_handle
    int stream_count
    int[] active_streams
    
    // Memory state
    int allocated_bytes
    int peak_allocated_bytes
    
    // Synchronization
    bool ready_for_compute
}

// Stream/Queue for async compute
struct accelerator_stream {
    int stream_id
    string device_id
    int priority           // 0=default, 1=high
    
    bool compute_ready
    int kernel_queue_depth
}

// Unified kernel execution interface
struct kernel_launch_config {
    int grid_size           // (grid_x, grid_y, grid_z)
    int block_size          // (block_x, block_y, block_z)
    int shared_mem_bytes
    string kernel_name
    []byte kernel_args      // serialized arguments
}

// Functions
func accelerator_init(string device_id) accelerator_context { }
func accelerator_get_caps(string device_id) accelerator_caps { }
func accelerator_launch_kernel(
    accelerator_context ctx, 
    accelerator_stream stream,
    kernel_launch_config config
) int { }
func accelerator_stream_synchronize(accelerator_stream stream) int { }
func accelerator_mem_alloc(accelerator_context ctx, int bytes) int { }  // returns GPU ptr
```

#### 2.2.2 Backend Implementations
- NVIDIA CUDA adapter: `kernel/accelerator/cuda_backend.s`
- AMD HIP adapter: `kernel/accelerator/hip_backend.s`
- Huawei CANN adapter: `kernel/accelerator/cann_backend.s`
- Unified executor: `kernel/accelerator/unified_executor.s`

### 2.3 Memory Management (AI-Optimized)

#### 2.3.1 Memory Pool System

```s
package neurx.kernel.mm

// Unified memory pool for DMA and GPU memory
struct memory_pool {
    string pool_name        // "gpu_device_0", "dma_buffer"
    int pool_type          // GPU_DEVICE, GPU_HOST, DMA, UVM
    
    // Total budget
    int total_bytes
    int used_bytes
    int free_bytes
    
    // Allocation strategy
    string allocation_policy  // "buddy", "bitmap", "best_fit"
    
    // Fragmentation tracking
    int max_fragment_bytes
    int fragment_count
}

// Allocation request with hints
struct alloc_request {
    int bytes
    int alignment           // 256, 4096 for cache-line aligned
    bool persistent         // false = temporary, true = session-long
    bool requires_dma       // true = needs to be DMA-accessible
    int priority            // 0=normal, 1=high (latency-critical)
}

// Allocation result
struct alloc_result {
    int gpu_ptr
    int cpu_ptr             // for UVM/mapped memory
    int pool_id
    bool success
}

// Memory pressure callback
func on_memory_pressure(string device_id, int available_bytes) int {
    // Application-level memory reclamation
    // Return 0 if reclaimed successfully
    return 0
}

// Key functions
func mm_pool_create(memory_pool config) int { }
func mm_alloc(string device_id, alloc_request req) alloc_result { }
func mm_free(int gpu_ptr) int { }
func mm_defragment(string device_id) int { }
```

#### 2.3.2 Features
- **DMA Buffer Pool**: Pre-allocated pinned host memory
- **GPU Memory Pool**: Device-resident memory with buddy allocator
- **Unified Virtual Memory (UVM)**: Transparent GPU-CPU memory
- **Memory Pressure Callbacks**: Notify apps when memory is tight
- **Fragmentation Tracking**: Monitor and mitigate fragmentation

### 2.4 AI Scheduler (Workload-Aware)

#### 2.4.1 Workload Classification

```s
package neurx.kernel.sched

// AI workload types with different scheduling priorities
enum workload_type {
    INFERENCE_LATENCY_CRITICAL,  // Low-latency interactive
    INFERENCE_THROUGHPUT_BATCH,   // High-throughput batch
    TRAINING_DENSE,               // Dense compute (good for batching)
    TRAINING_SPARSE,              // Sparse compute
    DATA_LOAD,                     // I/O bound
    SYNC_POINT,                    // MPI collective
}

// Workload descriptor
struct ai_workload {
    int workload_id
    workload_type wl_type
    
    // Resource requirements
    int required_gpu_memory
    int required_compute_fraction  // 0-100 (%)
    int required_bandwidth_gbps
    
    // Time requirements
    int target_latency_ms
    int estimated_duration_ms
    
    // Dependencies
    int[] depends_on                // other workload IDs
    
    // Priority
    int priority                    // 0=highest, 10=lowest
    int deadline_ms                 // relative to now
}

// GPU allocation (like CPU core allocation in Linux)
struct gpu_allocation {
    string gpu_device_id
    int allocated_compute            // %
    int allocated_memory_bytes
    int allocated_bandwidth_portion   // %
    
    int sm_mask                      // which SMs allocated (bitmap)
}

// Scheduling decision
struct schedule_decision {
    ai_workload workload
    gpu_allocation[] allocations     // may span multiple GPUs
    int priority                     // final priority after scheduling
    bool should_execute              // false = defer or reject
}

// Scheduler interface
func ai_scheduler_enqueue(ai_workload wl) int { }
func ai_scheduler_get_next_batch(int batch_size) schedule_decision[] { }
func ai_scheduler_complete(int workload_id, int execution_time_ms) int { }
```

#### 2.4.2 Scheduling Policies
- **Latency-First**: For interactive inference
- **Throughput-Max**: For batch inference
- **Fair-Share**: For mixed workloads
- **Priority-Driven**: For real-time guarantees
- **Deadline-Driven**: For deadline-critical tasks

### 2.5 System Call Interface (AI-Specific)

```s
package neurx.kernel.syscall

// AI-specific system calls (similar to Linux syscalls but for AI ops)

// Inference syscall
func neuray_infer(
    string model_id,
    []byte input_data,
    int timeout_ms
) ([]byte output, string error_code) { }

// Memory allocation syscall
func neuray_alloc(
    int bytes,
    string device_type,      // "gpu" or "npu"
    int flags               // DMA, persistent, etc.
) (int gpu_ptr, string error) { }

// Memory free syscall
func neuray_free(int gpu_ptr) int { }

// Workload scheduling syscall
func neuray_schedule(
    ai_workload workload,
    int priority
) int { }

// Device control syscall
func neuray_device_ctl(
    string device_id,
    string command,         // "power_down", "reset", "query_status"
    []byte params
) string { }

// Profiling/monitoring syscall
func neuray_get_metrics(
    string device_id,
    string metric_name      // "utilization", "power", "temperature"
) []byte { }
```

### 2.6 Module System (Loadable Kernel Modules)

```s
package neurx.kernel.module

// Module metadata
struct kernel_module {
    string name
    string version
    string description
    
    // Entry points
    func module_init() int
    func module_exit() int
    
    // Capabilities
    string[] provides          // "gpu_driver", "inference_backend"
    string[] requires          // "device_framework", "memory_manager"
    
    // Module parameters
    string[] params
}

// Module loader
func load_kernel_module(string module_path) int { }
func unload_kernel_module(string module_name) int { }
func list_loaded_modules() string[] { }
```

---

## Part 3: Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [ ] Device Model Framework (`kernel/device_model.s`)
- [ ] Driver Registration System (`kernel/driver_framework.s`)
- [ ] Basic GPU Driver for NVIDIA (`driver/gpu/nvidia_driver.s`)
- [ ] Memory Pool Allocator (`kernel/mm/memory_pool.s`)

### Phase 2: Accelerator Integration (Weeks 3-4)
- [ ] Unified Accelerator Abstraction (`kernel/accelerator/unified_executor.s`)
- [ ] CUDA Backend Adapter (`kernel/accelerator/cuda_adapter.s`)
- [ ] NPU Backend Adapter (`kernel/accelerator/npu_adapter.s`)
- [ ] Context and Stream Management

### Phase 3: Scheduling and System Calls (Weeks 5-6)
- [ ] AI Workload Scheduler (`kernel/sched/ai_scheduler.s`)
- [ ] AI System Call Interface (`kernel/syscall/ai_syscalls.s`)
- [ ] System Call Dispatcher

### Phase 4: Advanced Features (Weeks 7-8)
- [ ] Power Management (`kernel/power/dvfs.s`)
- [ ] Thermal Management (`kernel/thermal/thermal_mgmt.s`)
- [ ] Module Loader (`kernel/module/lkm_loader.s`)
- [ ] Profiling/Monitoring

### Phase 5: Integration & Testing (Weeks 9-10)
- [ ] Integration tests for all subsystems
- [ ] Performance benchmarks
- [ ] Documentation and examples

---

## Part 4: Key Design Principles

### 4.1 Principle 1: Abstraction Layers
Like Linux, NeurX AI OS provides clear abstraction layers:
- **Device Layer**: Hardware-specific details hidden
- **Driver Layer**: Standardized driver interface
- **Service Layer**: High-level APIs for applications

### 4.2 Principle 2: Modularity
- Independent modules with clear interfaces
- Loadable kernel modules for extensibility
- No hard dependencies between subsystems

### 4.3 Principle 3: Resource Management
- Pre-allocation and resource guarantees (like cgroups)
- Memory pools for predictable latency
- Power awareness for efficiency

### 4.4 Principle 4: Standardization
- All devices exposed through device model
- All drivers implement standard interface
- All accelerators through unified executor

### 4.5 Principle 5: Transparency
- Full visibility into device state and workloads
- Comprehensive monitoring and profiling
- Debugging interfaces for diagnosis

---

## Part 5: File Structure

```
neurx/
├── kernel/
│   ├── device_model.s              # Device tree and registration
│   ├── driver_framework.s          # Driver interface and lifecycle
│   ├── driver/
│   │   ├── gpu/
│   │   │   ├── nvidia_driver.s
│   │   │   ├── amd_driver.s
│   │   │   └── device_mgmt.s
│   │   ├── npu/
│   │   │   └── cann_driver.s
│   │   └── memory/
│   │       └── dma_driver.s
│   ├── mm/
│   │   ├── memory_pool.s
│   │   ├── dma_buffer_pool.s
│   │   ├── gpu_memory.s
│   │   └── uvm.s
│   ├── sched/
│   │   ├── ai_scheduler.s
│   │   ├── workload_classifier.s
│   │   └── resource_allocator.s
│   ├── accelerator/
│   │   ├── unified_executor.s
│   │   ├── cuda_adapter.s
│   │   ├── hip_adapter.s
│   │   └── cann_adapter.s
│   ├── syscall/
│   │   ├── ai_syscalls.s
│   │   └── syscall_dispatcher.s
│   ├── module/
│   │   └── lkm_loader.s
│   ├── power/
│   │   ├── dvfs.s
│   │   └── power_state.s
│   ├── thermal/
│   │   └── thermal_mgmt.s
│   └── irq/
│       └── device_events.s
├── api/
│   ├── ai_os_api.s                 # Public API for applications
│   └── device_management_api.s
└── examples/
    ├── simple_inference.s
    ├── gpu_memory_alloc.s
    ├── driver_binding.s
    └── module_loading.s
```

---

## Part 6: Benefits of This Architecture

| Aspect | Benefit |
|--------|---------|
| **Scalability** | Support 1-N GPUs/NPUs/TPUs uniformly |
| **Portability** | Add new hardware via drivers (no core changes) |
| **Efficiency** | Resource-aware scheduling, power management |
| **Reliability** | Driver isolation, fault recovery |
| **Observability** | Unified monitoring and profiling |
| **Extensibility** | Loadable modules for custom logic |
| **Standards Compliance** | Familiar to Linux kernel engineers |

---

## Part 7: Migration Path from Current NeurX

### Current Structure → New AI OS Structure

```
Existing: inference/ → New: kernel/accelerator/
Existing: backends/ → New: kernel/accelerator/*/adapter.s
Existing: serving/ → New: api/inference_service.s (uses syscalls)
Existing: mm/ → Reorganized to kernel/mm/
Existing: sched/ → Enhanced with ai_scheduler.s
New: kernel/device_model.s (not in current)
New: kernel/driver_framework.s (not in current)
```

### Backward Compatibility
- Existing inference APIs remain unchanged
- New syscalls coexist with direct API calls
- Old drivers wrapped in new device model

---

## Summary

By adopting Linux kernel's design patterns, NeurX AI OS becomes:
1. **A true operating system** for AI workloads
2. **Hardware-agnostic** (add new accelerators as drivers)
3. **Scalable** (handle 1 to 1000s of devices)
4. **Modular and extensible** (loadable modules)
5. **Enterprise-grade** (monitoring, power, thermal management)

This architecture enables NeurX to evolve from a specialized inference framework to a **general-purpose AI operating system** comparable to Linux's role in general computing.

---

## References

- Linux Kernel: `drivers/` subsystem (50,000+ lines)
- Linux Device Model: `kernel/device.c`, `drivers/base/`
- Linux Driver Framework: `include/linux/device.h`
- Linux Scheduler: `kernel/sched/`
- Linux Module System: `kernel/module/`

---

**Document Version**: 1.0
**Last Updated**: 2026-08-30
**Status**: Architecture Design Complete - Ready for Implementation
