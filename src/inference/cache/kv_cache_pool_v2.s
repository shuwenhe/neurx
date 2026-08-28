package inference
import "core"
import "tensor"
struct kv_block {
    block_id          int
    tokens_per_block  int32
    data              float[]32
    reference_count   int
    request_ids       int[]64
    is_prefix_block   bool
}

struct kv_allocation {
    block_table       int[]
    block_offsets     int[]32
    num_tokens        int32
    request_id        int64
}

struct kv_cache_config {
    num_blocks        int
    block_size        int32
    hidden_size       int32
    num_heads         int32
    head_dim          int32
    dtype             string
    enable_prefix_cache bool
}

struct kv_cache_pool_v2 {
    config            kv_cache_config
    blocks            []*kv_block
    free_blocks       int[]
    request_allocations map[int64]*kv_allocation
    request_to_blocks   map[int64]int[]
    prefix_cache_map    map[string]int[]
    total_allocated   int32
    total_free        int32
    eviction_count    int64
}

func NewKVCachePoolV2(config kv_cache_config) *kv_cache_pool_v2 {
    if config.num_blocks <= 0 {
        config.num_blocks = 1024
    }
    if config.block_size <= 0 {
        config.block_size = 16
    }
    pool := *kv_cache_pool_v2{
        config:              config,
        blocks:              []*kv_block{},
        free_blocks:         int[]{},
        request_allocations: make(map[int64]*kv_allocation),
        request_to_blocks:   make(map[int64]int[]),
        prefix_cache_map:    make(map[string]int[]),
        total_free:          int32(config.num_blocks),
    }
    for i := 0; i < config.num_blocks; i++ {
        block_data_size := config.block_size * config.hidden_size * 2
        block := *kv_block{
            block_id:          i,
            tokens_per_block:  config.block_size,
            data:              make(float[]32, int(block_data_size)),
            reference_count:   0,
            request_ids:       int[]64{},
            is_prefix_block:   false,
        }
        pool.blocks = append(pool.blocks, block)
        pool.free_blocks = append(pool.free_blocks, i)
    }
    return pool
}

func (kv_cache_pool_v2* p) Allocate(request_id int64, num_tokens int32) *kv_allocation {
    blocks_needed := (num_tokens + p.config.block_size - 1) / p.config.block_size
    if int32(len(p.free_blocks)) < blocks_needed {
        p.evictLRU()
    }
    if int32(len(p.free_blocks)) < blocks_needed {
        return nil
    }
    allocation := *kv_allocation{
        block_table:   int[]{},
        block_offsets: int[]32{},
        num_tokens:    num_tokens,
        request_id:    request_id,
    }
    for i := int32(0); i < blocks_needed; i++ {
        block_id := p.free_blocks[len(p.free_blocks)-1]
        p.free_blocks = p.free_blocks[:len(p.free_blocks)-1]
        block := p.blocks[block_id]
        block.reference_count = block.reference_count + 1
        block.request_ids = append(block.request_ids, request_id)
        allocation.block_table = append(allocation.block_table, block_id)
        allocation.block_offsets = append(allocation.block_offsets, 0)
    }
    p.request_allocations[request_id] = allocation
    p.request_to_blocks[request_id] = allocation.block_table
    p.total_allocated = p.total_allocated + int32(len(allocation.block_table))
    p.total_free = p.total_free - int32(len(allocation.block_table))
    return allocation
}

func (kv_cache_pool_v2* p) SharePrefix(source_id int64, target_id int64, prefix_tokens int32) bool {
    source_alloc, exists := p.request_allocations[source_id]
    if !exists {
        return false
    }
    blocks_to_share := (prefix_tokens + p.config.block_size - 1) / p.config.block_size
    if blocks_to_share > int32(len(source_alloc.block_table)) {
        blocks_to_share = int32(len(source_alloc.block_table))
    }
    target_alloc, exists := p.request_allocations[target_id]
    if !exists {
        target_alloc = *kv_allocation{
            block_table:   int[]{},
            block_offsets: int[]32{},
            num_tokens:    prefix_tokens,
            request_id:    target_id,
        }
        p.request_allocations[target_id] = target_alloc
    }
    for i := int32(0); i < blocks_to_share; i++ {
        block_id := source_alloc.block_table[i]
        block := p.blocks[block_id]
        block.reference_count = block.reference_count + 1
        block.is_prefix_block = true
        found := false
        for j := 0; j < len(block.request_ids); j++ {
            if block.request_ids[j] == target_id {
                found = true
                break
            }
        }
        if !found {
            block.request_ids = append(block.request_ids, target_id)
        }
        target_alloc.block_table = append(target_alloc.block_table, block_id)
        target_alloc.block_offsets = append(target_alloc.block_offsets, source_alloc.block_offsets[i])
    }
    additional_tokens := target_alloc.num_tokens - prefix_tokens
    additional_blocks := (additional_tokens + p.config.block_size - 1) / p.config.block_size
    if additional_blocks > 0 {
        for i := int32(0); i < additional_blocks; i++ {
            if len(p.free_blocks) == 0 {
                p.evictLRU()
                if len(p.free_blocks) == 0 {
                    return false
                }
            }
            block_id := p.free_blocks[len(p.free_blocks)-1]
            p.free_blocks = p.free_blocks[:len(p.free_blocks)-1]
            block := p.blocks[block_id]
            block.reference_count = block.reference_count + 1
            block.request_ids = append(block.request_ids, target_id)
            target_alloc.block_table = append(target_alloc.block_table, block_id)
            target_alloc.block_offsets = append(target_alloc.block_offsets, 0)
        }
    }
    return true
}

func (kv_cache_pool_v2* p) Release(request_id int64) {
    alloc, exists := p.request_allocations[request_id]
    if !exists {
        return
    }
    for i := 0; i < len(alloc.block_table); i++ {
        block_id := alloc.block_table[i]
        block := p.blocks[block_id]
        block.reference_count = block.reference_count - 1
        for j := 0; j < len(block.request_ids); j++ {
            if block.request_ids[j] == request_id {
                block.request_ids = append(block.request_ids[:j], block.request_ids[j+1:]...)
                break
            }
        }
        if block.reference_count <= 0 {
            p.free_blocks = append(p.free_blocks, block_id)
            block.is_prefix_block = false
        }
    }
    delete(p.request_allocations, request_id)
    delete(p.request_to_blocks, request_id)
    p.total_allocated = p.total_allocated - int32(len(alloc.block_table))
    p.total_free = p.total_free + int32(len(alloc.block_table))
}

func (kv_cache_pool_v2* p) GetAllocation(request_id int64) *kv_allocation {
    return p.request_allocations[request_id]
}

func (kv_cache_pool_v2* p) GetFreeBlocks() int {
    return len(p.free_blocks)
}

func (kv_cache_pool_v2* p) GetUsedBlocks() int {
    return p.config.num_blocks - len(p.free_blocks)
}

func (kv_cache_pool_v2* p) GetMemoryUsage() int64 {
    block_size_bytes := p.config.block_size * p.config.hidden_size * 2 * 4
    used := p.config.num_blocks - len(p.free_blocks)
    return int64(used) * int64(block_size_bytes)
}

func (kv_cache_pool_v2* p) evictLRU() {
    if len(p.free_blocks) > 0 {
        return
    }
    for block_id := 0; block_id < len(p.blocks); block_id++ {
        block := p.blocks[block_id]
        if block.reference_count == 1 && len(block.request_ids) > 0 {
            req_id := block.request_ids[0]
            if alloc, exists := p.request_allocations[req_id]; exists {
                for i := 0; i < len(alloc.block_table); i++ {
                    if alloc.block_table[i] == block_id {
                        alloc.block_table = append(alloc.block_table[:i], alloc.block_table[i+1:]...)
                        break
                    }
                }
            }
            block.reference_count = 0
            block.request_ids = int[]64{}
            p.free_blocks = append(p.free_blocks, block_id)
            p.eviction_count = p.eviction_count + 1
            return
        }
    }
}

func (kv_cache_pool_v2* p) GetStats() map[string]int64 {
    stats := make(map[string]int64)
    stats["total_blocks"] = int64(p.config.num_blocks)
    stats["used_blocks"] = int64(p.GetUsedBlocks())
    stats["free_blocks"] = int64(p.GetFreeBlocks())
    stats["active_requests"] = int64(len(p.request_allocations))
    stats["evictions"] = p.eviction_count
    return stats
}

func main() {
    config := kv_cache_config{
        num_blocks:      256,
        block_size:      16,
        hidden_size:     768,
        num_heads:       12,
        head_dim:        64,
        dtype:           "float32",
        enable_prefix_cache: true,
    }
    pool := NewKVCachePoolV2(config)
    alloc := pool.Allocate(1, 256)
    core.Println("KV Cache Pool V2 initialized")
    core.Println("Free blocks:", pool.GetFreeBlocks())
    core.Println("Allocated blocks:", len(alloc.block_table))
}
