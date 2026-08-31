package neurx.inference.paged_kv_basic
func calculate_blocks_needed(int block_size, int num_tokens) int {
    return (num_tokens + block_size - 1) / block_size
}

func free_blocks(int currently_allocated, int num_blocks) int {
    int temp = currently_allocated - num_blocks
    if temp < 0 {
        return 0
    }
    return temp
}

func can_allocate(int available, int needed) bool {
    return available >= needed
}

func get_cache_utilization(int allocated, int total) float {
    if total <= 0 {
        return 0.0
    }
    return float(allocated) / float(total)
}

func allocate_block_ids(int num_blocks) []int {
    int[] ids = []int{}
    int i = 0
    for i < num_blocks {
        ids = append(ids, i)
        i = i + 1
    }
    return ids
}

func copy_block_ids(int[] src_blocks, int[] dst_blocks) int {
    int min_len = len(src_blocks)
    if len(dst_blocks) < min_len {
        min_len = len(dst_blocks)
    }
    return min_len
}

func new_stats(int total_blocks) []int {
    int[] stats = int[]{total_blocks, 0, 0, 0, 0, 0}
    return stats
}

func update_allocated(int[] stats, int blocks) []int {
    stats[1] = stats[1] + blocks
    return stats
}

func update_freed(int[] stats, int blocks) []int {
    stats[2] = stats[2] + blocks
    return stats
}

func record_eviction(int[] stats, int count) []int {
    stats[3] = stats[3] + count
    return stats
}

func record_hit(int[] stats) []int {
    stats[4] = stats[4] + 1
    return stats
}

func record_miss(int[] stats) []int {
    stats[5] = stats[5] + 1
    return stats
}

func get_allocated(int[] stats) int {
    return stats[1]
}

func get_utilization_percent(int[] stats) int {
    int total = stats[0]
    int allocated = stats[1]
    if total <= 0 {
        return 0
    }
    return (allocated * 100) / total
}

func format_stats(int[] stats) string {
    string result = "Stats:"
    result = result + " T="
    result = result + string(stats[0])
    result = result + " A="
    result = result + string(stats[1])
    result = result + " F="
    result = result + string(stats[2])
    result = result + " E="
    result = result + string(stats[3])
    result = result + " H="
    result = result + string(stats[4])
    result = result + " M="
    result = result + string(stats[5])
    return result
}

func reset_counters(int[] stats) []int {
    stats[3] = 0
    stats[4] = 0
    stats[5] = 0
    return stats
}
