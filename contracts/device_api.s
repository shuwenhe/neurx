// NeurX Device API Interface
// Phase -1: Architecture Contracts
// Purpose: Define device abstraction for CPU, CUDA, CANN, Metal

package contracts

// Device Type Enum
type DeviceType interface {
    name() string
}

type CPU struct {}
type CUDA struct { device_id: int }
type CANN struct { device_id: int }
type Metal struct {}

func (CPU) name() string { return "cpu" }
func (c CUDA) name() string { return "cuda:" + string(c.device_id) }
func (c CANN) name() string { return "cann:" + string(c.device_id) }
func (Metal) name() string { return "metal" }

// Device Interface - Unified hardware abstraction
interface Device {
    // Device identification
    func device_type() -> DeviceType
    func is_available() -> bool
    func supports_bfloat16() -> bool
    func supports_fp16() -> bool
    
    // Memory management
    func allocate(bytes: int) -> int          // Returns device pointer (int for simplicity)
    func deallocate(ptr: int)                 // Free device memory
    func memset(ptr: int, value: int, bytes: int)
    func memcpy_h2d(host_ptr: []byte, device_ptr: int, bytes: int)  // Host to Device
    func memcpy_d2h(device_ptr: int, host_ptr: []byte, bytes: int)  // Device to Host
    func memcpy_d2d(src_ptr: int, dst_ptr: int, bytes: int)         // Device to Device
    
    // Device properties
    func max_threads_per_block() -> int
    func total_memory() -> int
    func free_memory() -> int
    func compute_capability() -> string       // e.g., "8.0" for RTX 3090
    
    // Synchronization
    func synchronize()                        // Block until all operations complete
    func record_event() -> int                // Record a CUDA-like event
    func wait_event(event_id: int)           // Wait for event
    
    // Capability checking
    func supports_operation(op_name: string) -> bool
}

// DeviceProperties - Configuration for device
struct DeviceProperties {
    device_type: DeviceType
    compute_capability: string
    max_threads_per_block: int
    shared_memory_per_block: int
    num_blocks: int
}

// AllocationStrategy
type AllocationStrategy interface {
    name() string
}

type SimpleAlloc struct {}           // malloc on demand
type PoolAlloc struct {
    pool_size: int
    block_size: int
}

func (SimpleAlloc) name() string { return "simple" }
func (PoolAlloc) name() string { return "pool" }

// MemoryAllocator Interface
interface MemoryAllocator {
    func init(device: Device, strategy: AllocationStrategy)
    func allocate(bytes: int) -> int
    func deallocate(ptr: int)
    func clear_cache()
    func get_memory_stats() -> map[string]int
}

// Phase -1 Verification
// Constraints from ARCHITECTURE_PRINCIPLES:
// Rule 9: New Device Isolation
//   - New device only modifies runtime/device/* and runtime/kernel/*
//   - Does NOT modify Operator code
//   - Registers with Dispatcher, and existing Operators work automatically

// Once implemented, verify:
// [ ] Memory allocation works on target device
// [ ] Synchronization blocks correctly
// [ ] Can query device properties
// [ ] Memory can be copied between host and device
// [ ] Multiple devices can be managed independently
