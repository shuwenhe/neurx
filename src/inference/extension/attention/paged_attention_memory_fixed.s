package neurx.attention.paged_attention_memory
struct physical_block {
    int block_id
    int layer_id
    int seq_id
    int start_pos
    int end_pos
    bool is_allocated
}

struct block_table {
    int seq_id
    int[] physical_blocks
    int num_tokens
    int num_blocks
}

struct paged_kv_cache_manager {
    []physical_block blocks
    []block_table sequences
    int block_size
    int num_layers
    int hidden_dim
    int num_heads
    int head_dim
    int total_blocks
    int allocated_blocks
    int freed_blocks
    int evictions
    int cache_hits
    int cache_misses
}

func new_paged_kv_cache_manager(
    int num_blocks,
    int block_size,
    int num_layers,
    int num_heads,
    int hidden_dim
) paged_kv_cache_manager {
    []physical_block blocks = []
    []block_table sequences = []
    int i
    i = 0
    for i < num_blocks {
        physical_block pb
        pb.block_id = i
        pb.layer_id = -1
        pb.seq_id = -1
        pb.start_pos = -1
        pb.end_pos = -1
        pb.is_allocated = false
        blocks = append(blocks, pb)
        i = i + 1
    }
    int head_dim
    head_dim = hidden_dim / num_heads
    paged_kv_cache_manager result
    result.blocks = blocks
    result.sequences = sequences
    result.block_size = block_size
    result.num_layers = num_layers
    result.hidden_dim = hidden_dim
    result.num_heads = num_heads
    result.head_dim = head_dim
    result.total_blocks = num_blocks
    result.allocated_blocks = 0
    result.freed_blocks = 0
    result.evictions = 0
    result.cache_hits = 0
    result.cache_misses = 0
    return result
}

func allocate_blocks(
    paged_kv_cache_manager mgr,
    int seq_id,
    int num_tokens
) (paged_kv_cache_manager, int[]) {
    int blocks_needed
    blocks_needed = (num_tokens + mgr.block_size - 1) / mgr.block_size
    int[] allocated_block_ids = []
    int i
    i = 0
    for i < len(mgr.blocks) {
        if len(allocated_block_ids) >= blocks_needed {
            break
        }
        if !mgr.blocks[i].is_allocated {
            mgr.blocks[i].is_allocated = true
            mgr.blocks[i].seq_id = seq_id
            mgr.blocks[i].layer_id = 0
            mgr.blocks[i].start_pos = len(allocated_block_ids) * mgr.block_size
            mgr.blocks[i].end_pos = mgr.blocks[i].start_pos + mgr.block_size
            allocated_block_ids = append(allocated_block_ids, mgr.blocks[i].block_id)
            mgr.allocated_blocks = mgr.allocated_blocks + 1
        }
        i = i + 1
    }
    if len(allocated_block_ids) < blocks_needed {
        mgr.evictions = mgr.evictions + (blocks_needed - len(allocated_block_ids))
    }
    return mgr, allocated_block_ids
}

func free_sequence_blocks(
    paged_kv_cache_manager mgr,
    int seq_id
) paged_kv_cache_manager {
    i := 0
    for i < len(mgr.blocks) {
        if mgr.blocks[i].seq_id == seq_id && mgr.blocks[i].is_allocated {
            mgr.blocks[i].is_allocated = false
            mgr.blocks[i].seq_id = -1
            mgr.freed_blocks = mgr.freed_blocks + 1
            mgr.allocated_blocks = mgr.allocated_blocks - 1
        }
        i = i + 1
    }
    return mgr
}

func copy_blocks(
    paged_kv_cache_manager mgr,
    int[] src_blocks,
    int[] dst_blocks
) paged_kv_cache_manager {
    min_len := len(src_blocks)
    if len(dst_blocks) < min_len {
        min_len = len(dst_blocks)
    }
    i := 0
    for i < min_len {
        src_id := src_blocks[i]
        dst_id := dst_blocks[i]
        if src_id >= 0 && src_id < len(mgr.blocks) {
            if dst_id >= 0 && dst_id < len(mgr.blocks) {
                mgr.blocks[dst_id].start_pos = mgr.blocks[src_id].start_pos
                mgr.blocks[dst_id].end_pos = mgr.blocks[src_id].end_pos
                mgr.cache_hits = mgr.cache_hits + 1
            }
        }
        i = i + 1
    }
    return mgr
}

func get_cache_stats(paged_kv_cache_manager mgr) string {
    result := "KVCache Stats:\n"
    result = result + "  Total Blocks: " + string(mgr.total_blocks) + "\n"
    result = result + "  Allocated: " + string(mgr.allocated_blocks) + "\n"
    result = result + "  Freed: " + string(mgr.freed_blocks) + "\n"
    result = result + "  Evictions: " + string(mgr.evictions) + "\n"
    result = result + "  Cache Hits: " + string(mgr.cache_hits) + "\n"
    result = result + "  Cache Misses: " + string(mgr.cache_misses) + "\n"
    return result
}

func reset_cache_stats(paged_kv_cache_manager mgr) paged_kv_cache_manager {
    mgr.cache_hits = 0
    mgr.cache_misses = 0
    mgr.evictions = 0
    return mgr
}

func get_block_utilization(paged_kv_cache_manager mgr) float {
    if mgr.total_blocks <= 0 {
        return 0.0
    }
    return float(mgr.allocated_blocks) / float(mgr.total_blocks)
}

func can_allocate_blocks(paged_kv_cache_manager mgr, int num_tokens) bool {
    blocks_needed := (num_tokens + mgr.block_size - 1) / mgr.block_size
    available := 0
    i := 0
    for i < len(mgr.blocks) {
        if !mgr.blocks[i].is_allocated {
            available = available + 1
        }
        i = i + 1
    }
    return available >= blocks_needed
}
