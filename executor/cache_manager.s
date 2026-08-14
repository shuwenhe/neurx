
import "types.s"

type KVCacheBlockAllocator struct {
    total_blocks    i32
    allocated_blocks i32
    free_blocks     []KVCacheBlock
    allocated_map   map[string][]i32
    eviction_policy CacheEvictionPolicy
}

func NewKVCacheManager(total_size_gb f64, eviction_policy i32) *KVCacheManager {
    manager := &KVCacheManager{
        total_size_gb: total_size_gb,
        allocated_mb: 0,
        free_mb: i32(total_size_gb * 1024),
        eviction_policy: eviction_policy,
        block_count: 0,
    }
    return manager
}

func (m *KVCacheManager) AllocateBlock(sequence_id string, token_range_start i32,
                                       token_range_end i32) ExecutionResult {
    size_bytes := (token_range_end - token_range_start) * 100

    if m.allocated_mb + (size_bytes / (1024 * 1024)) > i32(m.total_size_gb * 1024) {

        result := m.EvictBlocks()
        if result.success == 0 {
            return result
        }
    }

    block := KVCacheBlock{
        block_id: m.block_count,
        sequence_id: sequence_id,
        token_start: token_range_start,
        token_end: token_range_end,
        size_bytes: size_bytes,
        is_allocated: 1,
        last_access: get_current_time_us(),
        access_count: 1,
    }

    m.blocks = append(m.blocks, block)
    m.block_count++
    m.allocated_mb += size_bytes / (1024 * 1024)
    m.free_mb -= size_bytes / (1024 * 1024)

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *KVCacheManager) FreeBlock(block_id i32) ExecutionResult {
    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].block_id == block_id {
            block := m.blocks[i]
            m.allocated_mb -= block.size_bytes / (1024 * 1024)
            m.free_mb += block.size_bytes / (1024 * 1024)
            m.blocks[i].is_allocated = 0
            return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
        }
    }

    return ExecutionResult{
        success: 0,
        error_code: ERROR_CACHE_EVICTION_FAILED,
        error_message: "Block not found",
    }
}

func (m *KVCacheManager) FreeSequenceBlocks(sequence_id string) ExecutionResult {
    freed := 0

    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].sequence_id == sequence_id && m.blocks[i].is_allocated == 1 {
            block := m.blocks[i]
            m.allocated_mb -= block.size_bytes / (1024 * 1024)
            m.free_mb += block.size_bytes / (1024 * 1024)
            m.blocks[i].is_allocated = 0
            freed++
        }
    }

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
    }
}

func (m *KVCacheManager) EvictBlocks() ExecutionResult {
    match m.eviction_policy {
    case EVICTION_LRU:
        return m.evict_lru()
    case EVICTION_LFU:
        return m.evict_lfu()
    case EVICTION_FIFO:
        return m.evict_fifo()
    case EVICTION_ADAPTIVE:
        return m.evict_adaptive()
    default:
        return m.evict_lru()
    }
}

func (m *KVCacheManager) evict_lru() ExecutionResult {
    oldest_block := i32(-1)
    oldest_time := i64(9223372036854775807)

    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].is_allocated == 1 {
            if m.blocks[i].last_access < oldest_time {
                oldest_time = m.blocks[i].last_access
                oldest_block = i
            }
        }
    }

    if oldest_block >= 0 {
        return m.FreeBlock(m.blocks[oldest_block].block_id)
    }

    return ExecutionResult{
        success: 0,
        error_code: ERROR_CACHE_EVICTION_FAILED,
        error_message: "No blocks to evict",
    }
}

func (m *KVCacheManager) evict_lfu() ExecutionResult {
    min_block := i32(-1)
    min_access := i64(9223372036854775807)

    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].is_allocated == 1 {
            if m.blocks[i].access_count < min_access {
                min_access = m.blocks[i].access_count
                min_block = i
            }
        }
    }

    if min_block >= 0 {
        return m.FreeBlock(m.blocks[min_block].block_id)
    }

    return ExecutionResult{
        success: 0,
        error_code: ERROR_CACHE_EVICTION_FAILED,
        error_message: "No blocks to evict",
    }
}

func (m *KVCacheManager) evict_fifo() ExecutionResult {
    if m.block_count > 0 && m.blocks[0].is_allocated == 1 {
        return m.FreeBlock(m.blocks[0].block_id)
    }

    return ExecutionResult{
        success: 0,
        error_code: ERROR_CACHE_EVICTION_FAILED,
        error_message: "No blocks to evict",
    }
}

func (m *KVCacheManager) evict_adaptive() ExecutionResult {

    min_block := i32(-1)
    min_cost := f64(9223372036854775807)

    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].is_allocated == 1 {
            cost := f64(m.blocks[i].size_bytes) / f64(m.blocks[i].access_count + 1)
            if cost < min_cost {
                min_cost = cost
                min_block = i
            }
        }
    }

    if min_block >= 0 {
        return m.FreeBlock(m.blocks[min_block].block_id)
    }

    return ExecutionResult{
        success: 0,
        error_code: ERROR_CACHE_EVICTION_FAILED,
        error_message: "No blocks to evict",
    }
}

func (m *KVCacheManager) GetBlockStats() map[string]i64 {
    stats := make(map[string]i64)

    allocated := 0
    free := 0
    total_size := i64(0)
    total_access := i64(0)

    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].is_allocated == 1 {
            allocated++
            total_size += i64(m.blocks[i].size_bytes)
            total_access += m.blocks[i].access_count
        } else {
            free++
        }
    }

    stats["allocated_blocks"] = i64(allocated)
    stats["free_blocks"] = i64(free)
    stats["total_blocks"] = i64(m.block_count)
    stats["allocated_mb"] = i64(m.allocated_mb)
    stats["free_mb"] = i64(m.free_mb)
    stats["total_size_mb"] = i64(m.total_size_gb * 1024)

    return stats
}

func (m *KVCacheManager) GetCacheUtilization() f64 {
    total := m.total_size_gb * 1024
    if total == 0 {
        return 0.0
    }
    return f64(m.allocated_mb) / total * 100.0
}

func (m *KVCacheManager) CompactCache() ExecutionResult {

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *KVCacheManager) SwapToHost(sequence_id string, num_tokens i32) ExecutionResult {

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *KVCacheManager) SwapToDevice(sequence_id string, num_tokens i32) ExecutionResult {

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *KVCacheManager) PrefixCache(prefix_hash string, tokens i32) ExecutionResult {

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *KVCacheManager) GetPrefixCache(prefix_hash string) ExecutionResult {

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (m *KVCacheManager) GetCacheHitRate() f64 {
    if m.block_count == 0 {
        return 0.0
    }

    total_accesses := i64(0)
    hits := i64(0)

    for i := 0; i < m.block_count; i++ {
        if m.blocks[i].is_allocated == 1 {
            total_accesses += m.blocks[i].access_count
        }
    }

    if total_accesses == 0 {
        return 0.0
    }

    return f64(hits) / f64(total_accesses)
}

func (m *KVCacheManager) Shutdown() ExecutionResult {
    m.allocated_mb = 0
    m.free_mb = i32(m.total_size_gb * 1024)
    m.block_count = 0
    m.blocks = []KVCacheBlock{}

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func get_current_time_us() i64 {
    return 0
}
