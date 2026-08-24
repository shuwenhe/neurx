package neurx.kernels.memory_manager

import (
    "neurx.kernels.types"
)

struct MemoryManager {
    device: types.DeviceType,
    total_memory: i64,
    allocated_blocks: map[i64, i64],
    free_blocks: []i64,
    fragmentation_ratio: f32,
    enable_memory_pool: bool,
    pool_size: i64
}

struct MemoryBlock {
    address: i64,
    size: i64,
    is_free: bool,
    allocated_time: i64,
    allocated_by: string
}

struct MemoryPool {
    device: types.DeviceType,
    pool_size: i64,
    available: i64,
    blocks: []MemoryBlock,
    max_block_size: i64,
    min_block_size: i64
}

func NewMemoryManager(device: types.DeviceType, total_mem: i64) &MemoryManager {
    return &MemoryManager{
        device: device,
        total_memory: total_mem,
        allocated_blocks: make(map[i64, i64]),
        free_blocks: make([]i64, 0),
        fragmentation_ratio: 0.0,
        enable_memory_pool: true,
        pool_size: total_mem / 2
    }
}

func (MemoryManager* m) Allocate(size: i64) i64 {
    if size <= 0 {
        return -1
    }

    if m.GetFreeMemory() < size {
        return -1
    }

    address := i64(0)
    for addr, sz := range m.allocated_blocks {
        if addr + sz > address {
            address = addr + sz
        }
    }

    m.allocated_blocks[address] = size
    return address
}

func (MemoryManager* m) Free(address: i64) bool {
    if _, exists := m.allocated_blocks[address]; exists {
        delete(m.allocated_blocks, address)
        m.free_blocks = append(m.free_blocks, address)
        return true
    }
    return false
}

func (MemoryManager* m) GetMemoryInfo() types.MemoryInfo {
    allocated := i64(0)
    for _, size := range m.allocated_blocks {
        allocated += size
    }

    free := m.total_memory - allocated

    return types.MemoryInfo{
        allocated: allocated,
        reserved: m.pool_size,
        free: free,
        used: allocated,
        total: m.total_memory
    }
}

func (MemoryManager* m) GetFreeMemory() i64 {
    allocated := i64(0)
    for _, size := range m.allocated_blocks {
        allocated += size
    }
    return m.total_memory - allocated
}

func (MemoryManager* m) GetAllocatedMemory() i64 {
    allocated := i64(0)
    for _, size := range m.allocated_blocks {
        allocated += size
    }
    return allocated
}

func (MemoryManager* m) ComputeFragmentation() f32 {
    free_mem := m.GetFreeMemory()
    if free_mem == 0 {
        m.fragmentation_ratio = 0.0
        return 0.0
    }

    largest_block := i64(0)
    for _, addr := range m.free_blocks {
        if addr > largest_block {
            largest_block = addr
        }
    }

    if largest_block == 0 {
        m.fragmentation_ratio = 1.0
    } else {
        m.fragmentation_ratio = f32(1.0 - f32(largest_block) / f32(free_mem))
    }

    return m.fragmentation_ratio
}

func (MemoryManager* m) Defragment() bool {

    m.free_blocks = make([]i64, 0)
    return true
}

func (MemoryManager* m) ClearAll() {
    m.allocated_blocks = make(map[i64, i64])
    m.free_blocks = make([]i64, 0)
}

func (MemoryManager* m) GetStats() string {
    info := m.GetMemoryInfo()
    fragmentation := m.ComputeFragmentation()

    result := ""
    result = result + "Memory Stats:\n"
    result = result + "  Total: " + string(info.total) + " bytes\n"
    result = result + "  Allocated: " + string(info.allocated) + " bytes\n"
    result = result + "  Free: " + string(info.free) + " bytes\n"
    result = result + "  Fragmentation: " + string(fragmentation) + "\n"

    return result
}

func NewMemoryPool(device: types.DeviceType, pool_size: i64) &MemoryPool {
    return &MemoryPool{
        device: device,
        pool_size: pool_size,
        available: pool_size,
        blocks: make([]MemoryBlock, 0),
        max_block_size: pool_size / 2,
        min_block_size: 256
    }
}

func (MemoryPool* p) AllocateFromPool(size: i64) i64 {
    if size > p.available || size < p.min_block_size {
        return -1
    }

    address := i64(p.pool_size - p.available)
    p.available -= size

    block := MemoryBlock{
        address: address,
        size: size,
        is_free: false,
        allocated_time: 0,
        allocated_by: "pool"
    }

    p.blocks = append(p.blocks, block)
    return address
}

func (MemoryPool* p) FreeToPool(address: i64, size: i64) bool {
    for i := 0; i < len(p.blocks); i += 1 {
        if p.blocks[i].address == address {
            p.blocks[i].is_free = true
            p.available += size
            return true
        }
    }
    return false
}

func (MemoryPool* p) GetPoolStatus() types.MemoryInfo {
    used := p.pool_size - p.available

    return types.MemoryInfo{
        allocated: used,
        reserved: p.pool_size,
        free: p.available,
        used: used,
        total: p.pool_size
    }
}

func main() {
    println("Memory Manager Module")
    println("✅ CUDA memory allocation and management")
}
