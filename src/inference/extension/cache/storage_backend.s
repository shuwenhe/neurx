struct storage_tier {
    int tier_id
    string tier_name
    int64 capacity_bytes
    int64 used_bytes
    int64 hit_count
    int64 miss_count
    int max_blocks
    int current_blocks
}
struct tiered_storage {
    []storage_tier tiers
    int num_tiers
    int l1_tier_idx
    int l2_tier_idx
    int l3_tier_idx
    int64 total_capacity
    int64 total_used
}
func create_tiered_storage() tiered_storage {
    tiered_storage ts = tiered_storage{}
    ts.tiers = []storage_tier{cap: 3}
    ts.num_tiers = 0
    ts.l1_tier_idx = -1
    ts.l2_tier_idx = -1
    ts.l3_tier_idx = -1
    ts.total_capacity = 0
    ts.total_used = 0
    print("[TieredStorage] Initialized\n")
    return ts
}
func add_storage_tier(tiered_storage ts, string tier_name, int64 capacity_mb, int max_blocks_val) int {
    if ts.num_tiers >= 3 {
        print("[TieredStorage] Maximum 3 tiers supported\n")
        return -1
    }
    storage_tier tier = storage_tier{}
    tier.tier_id = ts.num_tiers
    tier.tier_name = tier_name
    tier.capacity_bytes = capacity_mb * 1048576
    tier.used_bytes = 0
    tier.hit_count = 0
    tier.miss_count = 0
    tier.max_blocks = max_blocks_val
    tier.current_blocks = 0
    if tier_name == "L1_MEMORY" {
        ts.l1_tier_idx = ts.num_tiers
    } else if tier_name == "L2_CPU" {
        ts.l2_tier_idx = ts.num_tiers
    } else if tier_name == "L3_DISK" {
        ts.l3_tier_idx = ts.num_tiers
    }
    ts.tiers[ts.num_tiers] = tier
    ts.num_tiers = ts.num_tiers + 1
    ts.total_capacity = ts.total_capacity + tier.capacity_bytes
    print("[TieredStorage] Added tier: " + tier_name + " (" + int_to_string(capacity_mb) + " MB)\n")
    return tier.tier_id
}
func tiered_storage_can_fit(tiered_storage ts, int tier_id, int64 size_bytes) int {
    if tier_id < 0 || tier_id >= ts.num_tiers {
        return 0
    }
    storage_tier tier = ts.tiers[tier_id]
    if tier.used_bytes + size_bytes <= tier.capacity_bytes {
        return 1
    }
    return 0
}
func tiered_storage_allocate(tiered_storage ts, int tier_id, int64 size_bytes) int {
    if tier_id < 0 || tier_id >= ts.num_tiers {
        print("[TieredStorage] Invalid tier ID: " + int_to_string(tier_id) + "\n")
        return 0
    }
    storage_tier tier = ts.tiers[tier_id]
    if tier.used_bytes + size_bytes > tier.capacity_bytes {
        print("[TieredStorage] Tier " + tier.tier_name + " full: " + int_to_string(tier.used_bytes) + "/" + int_to_string(tier.capacity_bytes) + "\n")
        return 0
    }
    if tier.current_blocks >= tier.max_blocks {
        print("[TieredStorage] Tier " + tier.tier_name + " block limit reached\n")
        return 0
    }
    ts.tiers[tier_id].used_bytes = tier.used_bytes + size_bytes
    ts.tiers[tier_id].current_blocks = tier.current_blocks + 1
    ts.total_used = ts.total_used + size_bytes
    print("[TieredStorage] Allocated " + int_to_string(size_bytes) + " bytes in " + tier.tier_name + "\n")
    return 1
}
func tiered_storage_promote(tiered_storage ts, int from_tier_id, int to_tier_id, int64 size_bytes) int {
    if from_tier_id == to_tier_id {
        return 1
    }
    if tiered_storage_can_fit(ts, to_tier_id, size_bytes) == 0 {
        print("[TieredStorage] Cannot promote: target tier full\n")
        return 0
    }
    storage_tier from_tier = ts.tiers[from_tier_id]
    storage_tier to_tier = ts.tiers[to_tier_id]
    ts.tiers[from_tier_id].used_bytes = from_tier.used_bytes - size_bytes
    ts.tiers[from_tier_id].current_blocks = from_tier.current_blocks - 1
    ts.tiers[to_tier_id].used_bytes = to_tier.used_bytes + size_bytes
    ts.tiers[to_tier_id].current_blocks = to_tier.current_blocks + 1
    print("[TieredStorage] Promoted from " + from_tier.tier_name + " to " + to_tier.tier_name + "\n")
    return 1
}
func tiered_storage_evict(tiered_storage ts, int tier_id) int {
    if tier_id < 0 || tier_id >= ts.num_tiers {
        return 0
    }
    storage_tier tier = ts.tiers[tier_id]
    if tier.current_blocks == 0 {
        return 0
    }
    int block_size_estimate = 7200
    ts.tiers[tier_id].used_bytes = tier.used_bytes - block_size_estimate
    ts.tiers[tier_id].current_blocks = tier.current_blocks - 1
    ts.total_used = ts.total_used - block_size_estimate
    print("[TieredStorage] Evicted from " + tier.tier_name + "\n")
    return 1
}
func tiered_storage_get_best_tier_for_read(tiered_storage ts) int {
    int best_tier = ts.l1_tier_idx
    if best_tier >= 0 && ts.tiers[best_tier].current_blocks > 0 {
        return best_tier
    }
    best_tier = ts.l2_tier_idx
    if best_tier >= 0 && ts.tiers[best_tier].current_blocks > 0 {
        return best_tier
    }
    best_tier = ts.l3_tier_idx
    if best_tier >= 0 && ts.tiers[best_tier].current_blocks > 0 {
        return best_tier
    }
    return -1
}
func tiered_storage_find_space(tiered_storage ts, int64 size_bytes) int {
    int tier_idx = ts.l1_tier_idx
    if tier_idx >= 0 && tiered_storage_can_fit(ts, tier_idx, size_bytes) == 1 {
        return tier_idx
    }
    tier_idx = ts.l2_tier_idx
    if tier_idx >= 0 && tiered_storage_can_fit(ts, tier_idx, size_bytes) == 1 {
        return tier_idx
    }
    tier_idx = ts.l3_tier_idx
    if tier_idx >= 0 && tiered_storage_can_fit(ts, tier_idx, size_bytes) == 1 {
        return tier_idx
    }
    return -1
}
func tiered_storage_get_stats(tiered_storage ts) string {
    string stats = "[TieredStorage] Total=" + int_to_string(ts.total_used) + "/" + int_to_string(ts.total_capacity) + " bytes\n"
    int i = 0
    for i < ts.num_tiers {
        storage_tier tier = ts.tiers[i]
        int percent = int(tier.used_bytes * 100 / (tier.capacity_bytes + 1))
        stats = stats + "  " + tier.tier_name + ": " + int_to_string(tier.current_blocks) + "/" + int_to_string(tier.max_blocks) + 
                " blocks, " + int_to_string(percent) + "% full\n"
        i = i + 1
    }
    return stats
}
func tiered_storage_clear(tiered_storage ts) {
    int i = 0
    for i < ts.num_tiers {
        ts.tiers[i].used_bytes = 0
        ts.tiers[i].current_blocks = 0
        ts.tiers[i].hit_count = 0
        ts.tiers[i].miss_count = 0
        i = i + 1
    }
    ts.total_used = 0
    print("[TieredStorage] Cleared all tiers\n")
}
func tiered_storage_record_hit(tiered_storage ts, int tier_id) {
    if tier_id >= 0 && tier_id < ts.num_tiers {
        ts.tiers[tier_id].hit_count = ts.tiers[tier_id].hit_count + 1
    }
}
func tiered_storage_record_miss(tiered_storage ts, int tier_id) {
    if tier_id >= 0 && tier_id < ts.num_tiers {
        ts.tiers[tier_id].miss_count = ts.tiers[tier_id].miss_count + 1
    }
}
