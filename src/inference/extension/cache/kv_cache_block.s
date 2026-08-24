struct kv_cache_block {
    int block_id
    int layer_id
    int token_count
    int location
    int64 size_bytes
    int64 timestamp
    int hit_count
    []float kv_data
}

int LOCATION_MEMORY = 0
int LOCATION_DISK = 1
int LOCATION_NETWORK = 2

struct cache_block_meta {
    int block_id
    int layer_id
    int token_count
    int64 timestamp
    int hit_count
}

func create_kv_cache_block(int block_id, int layer_id, int token_count, int hidden_dim) kv_cache_block {
    kv_cache_block block = kv_cache_block{}
    block.block_id = block_id
    block.layer_id = layer_id
    block.token_count = token_count
    block.location = LOCATION_MEMORY
    block.size_bytes = int64(token_count * hidden_dim * 2 * 4)
    block.timestamp = 0
    block.hit_count = 0
    
    int total_size = token_count * hidden_dim * 2
    block.kv_data = []float{cap: total_size}
    
    print("[KVBlock] Created block " + int_to_string(block_id) + " (layer=" + int_to_string(layer_id) + ", tokens=" + int_to_string(token_count) + ")\n")
    return block
}

func cache_block_size_bytes(kv_cache_block block) int64 {
    return block.size_bytes
}

func cache_block_matches_layer(kv_cache_block block, int target_layer) int {
    if block.layer_id == target_layer {
        return 1
    }
    return 0
}

func cache_block_get_hit_count(kv_cache_block block) int {
    return block.hit_count
}

func cache_block_increment_hits(kv_cache_block block) {
    block.hit_count = block.hit_count + 1
}

func cache_block_is_in_memory(kv_cache_block block) int {
    if block.location == LOCATION_MEMORY {
        return 1
    }
    return 0
}

func cache_block_update_timestamp(kv_cache_block block, int64 timestamp) {
    block.timestamp = timestamp
}

func cache_block_get_location_name(int location) string {
    if location == LOCATION_MEMORY {
        return "MEMORY"
    } else if location == LOCATION_DISK {
        return "DISK"
    } else if location == LOCATION_NETWORK {
        return "NETWORK"
    }
    return "UNKNOWN"
}
