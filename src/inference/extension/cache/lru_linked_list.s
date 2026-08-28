struct lru_node {
    string key
    int block_id
    int64 timestamp
    int access_count
    int prev_idx
    int next_idx
}
struct lru_cache {
    []lru_node nodes
    int head_idx
    int tail_idx
    int num_nodes
    int max_nodes
    int64 current_time
}
func create_lru_cache(int capacity) lru_cache {
    lru_cache lru = lru_cache{}
    lru.max_nodes = capacity
    lru.num_nodes = 0
    lru.head_idx = -1
    lru.tail_idx = -1
    lru.current_time = 0
    lru.nodes = []lru_node{cap: capacity}
    print("[LRUCache] Created with capacity " + int_to_string(capacity) + "\n")
    return lru
}
func lru_cache_put(lru_cache lru, string key, int block_id) int {
    int idx = 0
    for idx < lru.num_nodes {
        if lru.nodes[idx].key == key {
            lru.nodes[idx].access_count = lru.nodes[idx].access_count + 1
            lru.nodes[idx].timestamp = lru.current_time
            if lru.head_idx != idx {
                lru_cache_move_to_front(lru, idx)
            }
            return 1
        }
        idx = idx + 1
    }
    if lru.num_nodes >= lru.max_nodes {
        print("[LRUCache] Cache full, evicting tail\n")
        lru_cache_evict_tail(lru)
    }
    lru_node new_node = lru_node{}
    new_node.key = key
    new_node.block_id = block_id
    new_node.timestamp = lru.current_time
    new_node.access_count = 1
    new_node.prev_idx = -1
    new_node.next_idx = lru.head_idx
    int new_idx = lru.num_nodes
    lru.nodes[new_idx] = new_node
    if lru.head_idx >= 0 {
        lru.nodes[lru.head_idx].prev_idx = new_idx
    }
    lru.head_idx = new_idx
    if lru.tail_idx == -1 {
        lru.tail_idx = new_idx
    }
    lru.num_nodes = lru.num_nodes + 1
    print("[LRUCache] Added key " + key + " at head\n")
    return 1
}
func lru_cache_get(lru_cache lru, string key) int {
    int idx = 0
    for idx < lru.num_nodes {
        if lru.nodes[idx].key == key {
            lru.nodes[idx].access_count = lru.nodes[idx].access_count + 1
            lru.nodes[idx].timestamp = lru.current_time
            if lru.head_idx != idx {
                lru_cache_move_to_front(lru, idx)
            }
            print("[LRUCache] HIT for key " + key + " (block_id=" + int_to_string(lru.nodes[idx].block_id) + ")\n")
            return lru.nodes[idx].block_id
        }
        idx = idx + 1
    }
    print("[LRUCache] MISS for key " + key + "\n")
    return -1
}
func lru_cache_remove(lru_cache lru, string key) int {
    int idx = 0
    for idx < lru.num_nodes {
        if lru.nodes[idx].key == key {
            lru_node node = lru.nodes[idx]
            if node.prev_idx >= 0 {
                lru.nodes[node.prev_idx].next_idx = node.next_idx
            } else {
                lru.head_idx = node.next_idx
            }
            if node.next_idx >= 0 {
                lru.nodes[node.next_idx].prev_idx = node.prev_idx
            } else {
                lru.tail_idx = node.prev_idx
            }
            idx = idx + 1
            for idx < lru.num_nodes {
                lru.nodes[idx - 1] = lru.nodes[idx]
                idx = idx + 1
            }
            lru.num_nodes = lru.num_nodes - 1
            print("[LRUCache] Removed key " + key + "\n")
            return 1
        }
        idx = idx + 1
    }
    return 0
}
func lru_cache_move_to_front(lru_cache lru, int idx) {
    if idx == lru.head_idx {
        return
    }
    lru_node node = lru.nodes[idx]
    if node.prev_idx >= 0 {
        lru.nodes[node.prev_idx].next_idx = node.next_idx
    }
    if node.next_idx >= 0 {
        lru.nodes[node.next_idx].prev_idx = node.prev_idx
    } else {
        lru.tail_idx = node.prev_idx
    }
    node.prev_idx = -1
    node.next_idx = lru.head_idx
    if lru.head_idx >= 0 {
        lru.nodes[lru.head_idx].prev_idx = idx
    }
    lru.head_idx = idx
    lru.nodes[idx] = node
}
func lru_cache_evict_tail(lru_cache lru) string {
    if lru.tail_idx == -1 {
        return ""
    }
    int tail_idx = lru.tail_idx
    lru_node tail = lru.nodes[tail_idx]
    string evicted_key = tail.key
    if tail.prev_idx >= 0 {
        lru.nodes[tail.prev_idx].next_idx = -1
    }
    lru.tail_idx = tail.prev_idx
    if lru.tail_idx < 0 {
        lru.head_idx = -1
    }
    int idx = tail_idx
    for idx < lru.num_nodes - 1 {
        lru.nodes[idx] = lru.nodes[idx + 1]
        idx = idx + 1
    }
    lru.num_nodes = lru.num_nodes - 1
    print("[LRUCache] Evicted tail: " + evicted_key + "\n")
    return evicted_key
}
func lru_cache_clear(lru_cache lru) {
    lru.num_nodes = 0
    lru.head_idx = -1
    lru.tail_idx = -1
    print("[LRUCache] Cleared all nodes\n")
}
func lru_cache_get_lru_key(lru_cache lru) string {
    if lru.tail_idx == -1 {
        return ""
    }
    return lru.nodes[lru.tail_idx].key
}
func lru_cache_get_stats(lru_cache lru) string {
    int total_accesses = 0
    int idx = 0
    for idx < lru.num_nodes {
        total_accesses = total_accesses + lru.nodes[idx].access_count
        idx = idx + 1
    }
    string stats = "[LRUCache] Nodes=" + int_to_string(lru.num_nodes) + "/" + int_to_string(lru.max_nodes) + 
                   ", TotalAccesses=" + int_to_string(total_accesses)
    return stats
}
func lru_cache_update_time(lru_cache lru, int64 new_time) {
    lru.current_time = new_time
}
