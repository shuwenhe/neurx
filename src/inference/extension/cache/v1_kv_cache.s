package v1
type cache_location string
const (
    cache_gpu   cache_location = "gpu"
    cache_cpu   cache_location = "cpu"
    cache_hybrid cache_location = "hybrid"
)
struct kv_cache_metadata {
    int32 seq_id
    int32 seq_len
    int32 block_id
    int32 slot_id
    bool is_allocated
}
struct kv_block {
    int32 block_id
    int32 seq_id
    float32[] key_data
    float32[] value_data
    int32 token_count
    bool is_full
    int32 allocated_size
}
struct kv_cache_interface {
    cache_location location
    int32 block_size
    int32 num_blocks
    int32 num_allocated_blocks
    map[int32]kv_block* blocks
    map[int32]kv_cache_metadata* metadata
    int32 gpu_memory_used
    int32 cpu_memory_used
    bool enable_prefix_caching
    map[string]int32 prefix_cache_map
    bool enable_compression
    float32 compression_ratio
}
func create_kv_cache_interface(int32 num_blocks, int32 block_size) kv_cache_interface* {
    return *kv_cache_interface{
        location: cache_gpu,
        block_size: block_size,
        num_blocks: num_blocks,
        num_allocated_blocks: 0,
        blocks: make(map[int32]kv_block*),
        metadata: make(map[int32]kv_cache_metadata*),
        gpu_memory_used: 0,
        cpu_memory_used: 0,
        enable_prefix_caching: true,
        prefix_cache_map: make(map[string]int32),
        enable_compression: false,
        compression_ratio: 1.0,
    }
}
func (kv_cache_interface* cache) allocate_block(int32 seq_id) int32 {
    if cache.num_allocated_blocks >= cache.num_blocks {
        return -1
    }
    block_id := cache.num_allocated_blocks
    cache.num_allocated_blocks = cache.num_allocated_blocks + 1
    block := *kv_block{
        block_id: block_id,
        seq_id: seq_id,
        key_data: make(float32[]),
        value_data: make(float32[]),
        token_count: 0,
        is_full: false,
        allocated_size: cache.block_size,
    }
    cache.blocks[block_id] = block
    cache.metadata[block_id] = *kv_cache_metadata{
        seq_id: seq_id,
        seq_len: 0,
        block_id: block_id,
        slot_id: 0,
        is_allocated: true,
    }
    return block_id
}
func (kv_cache_interface* cache) put_kv(int32 seq_id, float32[] keys, float32[] values) bool {
    if len(cache.blocks) == 0 {
        cache.allocate_block(seq_id)
    }
    for block_id, block := range cache.blocks {
        if block.seq_id == seq_id && !block.is_full {
            block.key_data = append(block.key_data, keys...)
            block.value_data = append(block.value_data, values...)
            block.token_count = block.token_count + 1
            if len(block.key_data) >= cache.block_size {
                block.is_full = true
            }
            meta := cache.metadata[block_id]
            meta.seq_len = block.token_count
            return true
        }
    }
    return false
}
func (kv_cache_interface* cache) get_kv(int32 seq_id) option[float32[]] {
    for _, block := range cache.blocks {
        if block.seq_id == seq_id {
            return option[float32[]]{value: block.key_data}
        }
    }
    return option[float32[]]{}
}
func (kv_cache_interface* cache) free_block(int32 block_id) bool {
    if block, exists := cache.blocks[block_id]; exists {
        delete(cache.blocks, block_id)
        delete(cache.metadata, block_id)
        cache.num_allocated_blocks = cache.num_allocated_blocks - 1
        return true
    }
    return false
}
func (kv_cache_interface* cache) get_memory_usage() int32 {
    total := cache.gpu_memory_used + cache.cpu_memory_used
    return total
}
func (kv_cache_interface* cache) enable_compression(float32 ratio) {
    cache.enable_compression = true
    cache.compression_ratio = ratio
}
func (kv_cache_interface* cache) get_cache_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["num_blocks"] = cache.num_blocks
    stats["num_allocated"] = cache.num_allocated_blocks
    stats["memory_used"] = cache.get_memory_usage()
    stats["compression_enabled"] = cache.enable_compression
    return stats
}
func (kv_cache_interface* cache) clear() {
    cache.blocks = make(map[int32]kv_block*)
    cache.metadata = make(map[int32]kv_cache_metadata*)
    cache.num_allocated_blocks = 0
}
