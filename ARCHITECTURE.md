# NeurX-OS: AI Operating System Architecture Guide

## Complete 9-Layer Architecture

### Layer 0: Initialization (`init/`)
**Purpose:** Boot sequence and kernel startup

**Key Files:**
- `bootloader.s` - Bootloader integration, hardware detection, parameter parsing

**Responsibilities:**
- Detect CPU/GPU count and memory
- Parse boot arguments
- Initialize early subsystems
- Establish boot context

**Entry Points:**
```
func init_system() boot_context
```

---

### Layer 1: Hardware Abstraction (`hal/`)
**Purpose:** Unified hardware capability detection

**Key Files:**
- `capability.s` - Device capability detection and reporting

**Structures:**
- `device_capability` - Single device specs (compute cores, memory, bandwidth, TFLOPS)
- `platform_capability` - Full platform specs (sockets, NUMA nodes, total memory)

**Responsibilities:**
- Detect platform capabilities
- Report device features
- Provide hardware-agnostic abstraction

**Key Functions:**
```
func detect_platform_capability() platform_capability
func detect_compute_device(index: int) device_capability
```

---

### Layer 2: Architecture-Specific (`arch/`)
**Purpose:** CPU, GPU, ASIC platform optimizations

**Structure:**
```
arch/
├── x86/           - Intel/AMD 64-bit
├── arm/           - ARM processors (ARM64)
├── gpu/
│   ├── nvidia/    - NVIDIA CUDA/Grace
│   ├── amd/       - AMD RDNA/MI series
│   └── intel/     - Intel Arc/Data Center GPU
└── asic/
    ├── tpu/       - Google TPU
    └── hopper/    - NVIDIA Hopper specialized
```

**Responsibilities:**
- ISA-specific optimizations
- Vector instruction tuning
- Cache hierarchy optimization
- Performance counters

---

### Layer 3: Hardware Drivers (`drivers/`)
**Purpose:** Hardware device abstraction and control

**Subdirectories:**

#### `drivers/gpu/`
- GPU driver abstraction (CUDA, ROCm, oneAPI)
- Memory allocation/deallocation
- Kernel launching
- Stream management

**Key Functions:**
```
func init_gpu_driver(driver_type: gpu_driver_type) result[gpu_driver*, string]
func allocate_gpu_memory(device_id: int, size_mb: int) result[int, string]
func launch_gpu_kernel(device_id: int, kernel_ptr: int) result[int, string]
```

#### `drivers/network/`
- Ethernet (10G, 100G)
- InfiniBand (HDR)
- RDMA support
- Collective communication primitives

**Key Functions:**
```
func init_network_driver(protocol: network_protocol, device_count: int) result[network_driver, string]
func send_packet(device: network_device*, data_ptr: int, data_size: int) result[int, string]
func enable_rdma(device: network_device*) result[int, string]
```

#### `drivers/sensor/`
- LiDAR (3D point clouds)
- Cameras (RGB, Thermal)
- Radar (range, velocity)
- IMU (6-DOF inertial)
- Encoders, GPS

**Key Functions:**
```
func init_sensor(sensor_type: sensor_type, sampling_rate_hz: int) result[sensor_driver, string]
func read_sensor(driver: sensor_driver*) result[sensor_data, string]
func start_streaming(driver: sensor_driver*) result[int, string]
```

#### `drivers/actuator/`
- Brushless motors
- Precision servos
- Linear actuators
- Solenoids

**Key Functions:**
```
func init_actuator(actuator_type: actuator_type) result[actuator_driver, string]
func home_actuator(driver: actuator_driver*) result[int, string]
func send_command(driver: actuator_driver*, cmd: actuator_command*) result[int, string]
func read_feedback(driver: actuator_driver*) result[feedback, string]
```

#### `drivers/storage/`
- NVMe/SSD
- Distributed cache
- Model storage

#### `drivers/interconnect/`
- NVLink (GPU-GPU)
- PCIe (device fabric)
- InfiniBand switch fabric

#### `drivers/power/`, `drivers/cooling/`
- Power distribution units
- Temperature monitoring
- Thermal management

---

### Layer 4: Core Kernel (`kernel/`)
**Purpose:** Core OS services and synchronization

#### `kernel/sched/`
- Task scheduling (training vs inference)
- Priority management
- CPU/GPU affinity
- Real-time constraints

**Key Structures:**
- `task_type` - training_task, inference_task, system_task
- `scheduler` - Global task scheduler

**Key Functions:**
```
func schedule_training_task(sched: scheduler*, priority: int) int
func schedule_inference_task(sched: scheduler*, priority: int) int
```

#### `kernel/locking/`
- Mutex, RWLock, Spinlock
- Semaphores
- Wait queue management

**Key Functions:**
```
func create_lock(lock_type: lock_type) lock
func acquire_lock(lock: lock*) result[int, string]
func release_lock(lock: lock*) result[int, string]
func try_acquire_lock(lock: lock*) bool
```

#### `kernel/time/`, `kernel/workqueue/`, `kernel/irq/`, `kernel/rcu/`, `kernel/events/`
- Timer management
- Background work queues
- Interrupt handlers
- Lock-free read-copy-update
- Performance event monitoring

---

### Layer 5: Memory Management (`mm/`)
**Purpose:** Efficient memory allocation and management

#### `mm/allocator/`
- Memory pool management
- Tensor-specific allocator
- Alignment and coalescing

**Key Structures:**
- `memory_pool` - Heap storage
- `tensor_allocator` - Aligned tensor allocation

**Key Functions:**
```
func create_memory_pool(size_mb: int) result[memory_pool, string]
func allocate_tensor(allocator: tensor_allocator*, size_mb: int) result[allocation_result, string]
func deallocate_tensor(allocator: tensor_allocator*, ptr: int) result[int, string]
```

#### `mm/slab/` (future)
- Slab allocator for objects
- Object pooling

#### `mm/dma/` (future)
- DMA buffer pools
- GPU memory management

#### `mm/kv_cache/` (future)
- KV cache allocation
- L1/L2/L3 cache hierarchy
- Eviction policies

---

### Layer 6: File Systems (`fs/`)
**Purpose:** Model and data storage management

#### `fs/model_registry/` → `sys/model_registry/`
- Model registration
- Version management
- Metadata tracking

**Key Structures:**
- `model_metadata` - Model info (size, quantization, framework)
- `model_location` - Storage location (path, type, cache status)

**Key Functions:**
```
func register_model(registry: model_registry*, metadata: model_metadata*) result[string, string]
func locate_model(registry: model_registry*, model_id: string*) result[model_location, string]
func list_models(registry: model_registry*) result[model_metadata*, string]
```

#### `fs/neurx/` (future)
- Custom filesystem for models
- Distributed model storage

#### `fs/cache/` (future)
- Model cache management
- Prefetching strategies

---

### Layer 7: Networking (`net/`)
**Purpose:** Distributed training and inference

#### `net/collective/`
- AllReduce (gradient aggregation)
- AllGather (result collection)
- Broadcast (model distribution)
- ReduceScatter (segmented reduce)

**Key Functions:**
```
func create_collective_group(participant_ids: int*, count: int) result[collective_group, string]
func execute_allreduce(group: collective_group*, data_ptr: int, data_size: int) result[collective_result, string]
func execute_allgather(group: collective_group*, local_data: int*, local_size: int) result[collective_result, string]
func execute_broadcast(group: collective_group*, root_id: int, data_ptr: int, data_size: int) result[collective_result, string]
```

#### `net/transport/` (future)
- High-performance transport (RDMA, gRPC)
- Message reliability

#### `net/qos/` (future)
- QoS for inference SLAs
- Priority-based scheduling

#### `net/security/` (future)
- Encrypted collective ops
- Authentication

---

### Layer 8: System Services (`sys/`)
**Purpose:** High-level AI orchestration and management

#### `sys/inference/`
- Inference engine
- Model loading
- Request queuing
- Token generation

**Key Structures:**
- `inference_request` - Prompt, max_tokens, temperature, top_k, top_p
- `inference_response` - Completion, latency, model_id

**Key Functions:**
```
func create_inference_engine() inference_engine
func load_model(engine: inference_engine*, model_id: string*, precision: model_precision) result[int, string]
func infer(engine: inference_engine*, request: inference_request*) result[inference_response, string]
```

#### `sys/training/`
- Training coordination
- Optimizer selection
- Checkpoint management
- Metrics tracking

**Key Structures:**
- `training_config` - Batch size, learning rate, optimizer, epochs
- `training_state` - Current epoch, loss, params, distributed flag

**Key Functions:**
```
func create_training_coordinator(config: training_config*) training_coordinator
func start_training(coordinator: training_coordinator*) result[int, string]
func save_checkpoint(coordinator: training_coordinator*, checkpoint_path: string*) result[int, string]
func get_training_metrics(coordinator: training_coordinator*) training_state
```

#### `sys/scheduler/`
- Global workload scheduling
- Resource allocation
- Deployment target selection
- SLA management

**Key Structures:**
- `workload` - workload_id, target (datacenter/automotive/robotics/edge), priority, deadline
- `resource_request` - GPU/memory/bandwidth/CPU requirements
- `schedule_result` - Feasibility, node assignment, ETA

**Key Functions:**
```
func evaluate_workload(workload: workload*, resource: resource_request*) schedule_result
func allocate_resources(workload_id: string*, gpu_count: int, memory_gb: int) result[int, string]
```

#### `sys/monitor/`
- Real-time metrics collection
- System health monitoring
- Latency/throughput tracking
- GPU utilization reporting
- Temperature monitoring

**Key Structures:**
- `metric` - Type, value, unit, timestamp
- `system_health` - Healthy GPUs, avg temp, memory utilization, network utilization

**Key Functions:**
```
func create_monitoring_service(interval_ms: int) monitoring_service
func start_monitoring(service: monitoring_service*) result[int, string]
func collect_metric(service: monitoring_service*, metric: metric*) result[int, string]
func get_system_health(service: monitoring_service*) system_health
```

#### `sys/resource/` (future)
- Resource pooling
- Allocation tracking
- Quota management

#### `sys/rpc/`
- Distributed RPC framework
- Message serialization
- Service discovery

**Key Structures:**
- `rpc_message` - Message ID, call type (request/response/error), method name, payload
- `rpc_server` - Server with port and connection tracking
- `rpc_client` - Client with connection parameters

**Key Functions:**
```
func create_rpc_server(port: int) rpc_server
func start_rpc_server(server: rpc_server*) result[int, string]
func send_rpc_call(client: rpc_client*, method: string*, payload: int*, payload_size: int) result[rpc_message, string]
```

#### `sys/model_registry/`
- Model catalog
- Version tracking
- Metadata management
- Cache invalidation

**Key Functions:**
```
func create_model_registry() model_registry
func register_model(registry: model_registry*, metadata: model_metadata*) result[string, string]
func locate_model(registry: model_registry*, model_id: string*) result[model_location, string]
```

---

### Layer 9: Applications & Tools

#### `tools/automotive/`
- Vehicle controller integration
- Sensor fusion pipeline
- Real-time control (<30ms latency)
- Safety verification

**Key Functions:**
```
func create_vehicle_controller(latency_ms: int) vehicle_controller
func process_sensor_fusion(vehicle_state: vehicle_state*) result[control_output, string]
func verify_safety(output: control_output*) bool
func execute_control(output: control_output*) result[int, string]
```

#### `tools/robotics/`
- Robot arm control
- Joint configuration
- Inverse kinematics
- Real-time feedback (1000Hz)

**Key Functions:**
```
func create_robot_arm(name: string*, num_joints: int, frequency_hz: int) robot_arm
func send_arm_command(arm: robot_arm*, cmd: arm_command*) result[int, string]
func get_arm_feedback(arm: robot_arm*) result[arm_feedback, string]
func inverse_kinematics(arm: robot_arm*, target_position: float*, target_orientation: float*) result[float*, string]
```

#### `tools/datacenter/` (future)
- Multi-GPU orchestration
- Cluster management
- Job scheduler
- Resource monitoring

#### `cmd/serve/`
- Inference serving entry point
- HTTP/gRPC endpoints
- Model loading from registry

#### `cmd/train/`
- Training entry point
- Distributed training setup
- Checkpoint management

#### `cmd/monitor/`
- System monitoring CLI
- Metrics reporting
- Health checks

---

## Integration Points

### Existing Codebase Integration
- `src/inference/` ← connects to `sys/inference/`
- `src/training/` ← connects to `sys/training/`
- `backend/platform/` ← implementations of `drivers/` and `arch/`
- `src/distributed/` ← uses `net/collective/` and `sys/rpc/`

### Deployment-Specific Flows

#### Datacenter Flow
```
init/bootloader → hal/capability → drivers/network → sys/scheduler
→ sys/inference/training → net/collective → sys/monitor
```

#### Autonomous Vehicle Flow
```
init/bootloader → hal/capability → drivers/sensor → drivers/actuator
→ tools/automotive/vehicle_controller → sys/monitor
```

#### Robotics Flow
```
init/bootloader → hal/capability → drivers/sensor → drivers/actuator
→ tools/robotics/robot_arm → kernel/sched (1000Hz) → sys/monitor
```

---

## Implementation Priority

### Phase 1: Foundations (Week 1-4)
1. ✅ Directory structure complete
2. Complete `init/bootloader.s` full implementation
3. Complete `hal/capability.s` detection logic
4. Driver interface definitions

### Phase 2: Core Systems (Week 5-8)
1. `kernel/sched/` scheduling policy
2. `kernel/locking/` full lock implementations
3. `mm/allocator/` tensor allocation
4. `sys/scheduler/` global orchestration

### Phase 3: Distributed (Week 9-12)
1. `net/collective/` AllReduce/AllGather
2. `sys/rpc/` distributed RPC
3. `sys/training/` distributed training
4. Collective communication tests

### Phase 4: Deployment (Week 13-16)
1. Datacenter deployment tools
2. Automotive vehicle integration
3. Robotics control integration
4. Real-time scheduling guarantees

### Phase 5: Optimization (Week 17-20)
1. Performance tuning
2. Security hardening
3. Documentation completion
4. Production hardening

---

## Key Design Principles

1. **Modular**: Each layer independent with clear interfaces
2. **Hardware-Agnostic**: Drivers abstract hardware details
3. **Scalable**: From edge to 100,000+ GPU datacenters
4. **Deterministic**: Zero GC pauses, predictable latency
5. **Observable**: Comprehensive monitoring built-in
6. **Self-Describing**: Clear naming, no comments needed
7. **Pure S**: 100% S language (except critical paths)
8. **Production-Ready**: Enterprise error handling

---

## Next Steps

1. ✅ Create directory structure (done)
2. ✅ Define core interfaces (done)
3. Complete Phase 1 implementations
4. Write integration tests
5. Benchmark against Linux kernel patterns
6. Deploy to test infrastructure
