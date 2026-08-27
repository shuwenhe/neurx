struct hash_entry {
    string key
    int[] block_ids
    int64 timestamp
    int access_count
    int next_idx
}

struct hash_table {
    []hash_entry buckets
    int num_buckets
    int num_entries
    int max_entries
    int64 current_time
    int collision_count
    float load_factor_threshold
}

func hash_function(string key, int table_size) int {
    int hash = 0
    int i = 0
    for i < len(key) {
        int byte_val = __host_slice(key, i, i + 1)[0]
        hash = (hash * 31 + byte_val) % 2147483647
        i = i + 1
    }
    
    int index = (hash % table_size)
    if index < 0 { index = index + table_size }
    return index
}

func create_hash_table(int bucket_count, int max_entries_val) hash_table {
    hash_table ht = hash_table{}
    ht.num_buckets = bucket_count
    ht.max_entries = max_entries_val
    ht.num_entries = 0
    ht.collision_count = 0
    ht.load_factor_threshold = 0.75
    ht.current_time = 0
    ht.buckets = []hash_entry{cap: bucket_count * 10}
    
    int i = 0
    for i < bucket_count {
        hash_entry entry = hash_entry{}
        entry.key = ""
        entry.block_ids = int[]{cap: 32}
        entry.next_idx = -1
        entry.timestamp = 0
        entry.access_count = 0
        ht.buckets[i] = entry
        i = i + 1
    }
    
    print("[HashTable] Created with " + int_to_string(bucket_count) + " buckets\n")
    return ht
}

func hash_table_insert(hash_table ht, string key, int[] block_ids) int {
    if ht.num_entries >= ht.max_entries {
        print("[HashTable] Table full, cannot insert key " + key + "\n")
        return 0
    }
    
    int index = hash_function(key, ht.num_buckets)
    
    int entry_idx = index
    int prev_idx = -1
    
    for entry_idx >= 0 && entry_idx < len(ht.buckets) {
        hash_entry current = ht.buckets[entry_idx]
        
        if len(current.key) == 0 {
            ht.buckets[entry_idx].key = key
            ht.buckets[entry_idx].block_ids = block_ids
            ht.buckets[entry_idx].timestamp = ht.current_time
            ht.buckets[entry_idx].access_count = 1
            ht.buckets[entry_idx].next_idx = -1
            ht.num_entries = ht.num_entries + 1
            print("[HashTable] Inserted key " + key + " at bucket " + int_to_string(index) + "\n")
            return 1
        }
        
        if current.key == key {
            ht.buckets[entry_idx].block_ids = block_ids
            ht.buckets[entry_idx].timestamp = ht.current_time
            ht.buckets[entry_idx].access_count = ht.buckets[entry_idx].access_count + 1
            print("[HashTable] Updated key " + key + " (accesses=" + int_to_string(ht.buckets[entry_idx].access_count) + ")\n")
            return 1
        }
        
        prev_idx = entry_idx
        entry_idx = current.next_idx
    }
    
    int new_idx = ht.num_buckets + ht.collision_count
    if new_idx >= len(ht.buckets) {
        print("[HashTable] Collision chain overflow\n")
        return 0
    }
    
    hash_entry new_entry = hash_entry{}
    new_entry.key = key
    new_entry.block_ids = block_ids
    new_entry.timestamp = ht.current_time
    new_entry.access_count = 1
    new_entry.next_idx = -1
    
    ht.buckets[new_idx] = new_entry
    ht.buckets[prev_idx].next_idx = new_idx
    ht.collision_count = ht.collision_count + 1
    ht.num_entries = ht.num_entries + 1
    
    print("[HashTable] Collision chain extended, collisions=" + int_to_string(ht.collision_count) + "\n")
    return 1
}

func hash_table_lookup(hash_table ht, string key) int[] {
    int index = hash_function(key, ht.num_buckets)
    
    int entry_idx = index
    for entry_idx >= 0 && entry_idx < len(ht.buckets) {
        hash_entry current = ht.buckets[entry_idx]
        
        if current.key == key {
            ht.buckets[entry_idx].access_count = ht.buckets[entry_idx].access_count + 1
            ht.buckets[entry_idx].timestamp = ht.current_time
            print("[HashTable] HIT for key " + key + " (accesses=" + int_to_string(current.access_count) + ")\n")
            return current.block_ids
        }
        
        entry_idx = current.next_idx
    }
    
    print("[HashTable] MISS for key " + key + "\n")
    return int[]{cap: 0}
}

func hash_table_remove(hash_table ht, string key) int {
    int index = hash_function(key, ht.num_buckets)
    
    int entry_idx = index
    int prev_idx = -1
    
    for entry_idx >= 0 && entry_idx < len(ht.buckets) {
        hash_entry current = ht.buckets[entry_idx]
        
        if current.key == key {
            if prev_idx == -1 {
                if current.next_idx != -1 {
                    hash_entry next_entry = ht.buckets[current.next_idx]
                    ht.buckets[entry_idx].key = next_entry.key
                    ht.buckets[entry_idx].block_ids = next_entry.block_ids
                    ht.buckets[entry_idx].timestamp = next_entry.timestamp
                    ht.buckets[entry_idx].access_count = next_entry.access_count
                    ht.buckets[entry_idx].next_idx = next_entry.next_idx
                } else {
                    ht.buckets[entry_idx].key = ""
                    ht.buckets[entry_idx].next_idx = -1
                }
            } else {
                ht.buckets[prev_idx].next_idx = current.next_idx
            }
            
            ht.num_entries = ht.num_entries - 1
            print("[HashTable] Removed key " + key + "\n")
            return 1
        }
        
        prev_idx = entry_idx
        entry_idx = current.next_idx
    }
    
    print("[HashTable] Key not found: " + key + "\n")
    return 0
}

func hash_table_get_stats(hash_table ht) string {
    float load_factor = float(ht.num_entries) / float(ht.num_buckets)
    string stats = "[HashTable] Entries=" + int_to_string(ht.num_entries) + "/" + int_to_string(ht.max_entries) +
                   ", Buckets=" + int_to_string(ht.num_buckets) +
                   ", LoadFactor=" + int_to_string(int(load_factor * 100)) + "%" +
                   ", Collisions=" + int_to_string(ht.collision_count)
    return stats
}

func hash_table_clear(hash_table ht) {
    int i = 0
    for i < len(ht.buckets) {
        ht.buckets[i].key = ""
        ht.buckets[i].next_idx = -1
        ht.buckets[i].access_count = 0
        ht.buckets[i].timestamp = 0
        i = i + 1
    }
    ht.num_entries = 0
    ht.collision_count = 0
    print("[HashTable] Cleared all entries\n")
}

func hash_table_update_time(hash_table ht, int64 new_time) {
    ht.current_time = new_time
}

func hash_table_should_resize(hash_table ht) int {
    float load_factor = float(ht.num_entries) / float(ht.num_buckets)
    if load_factor > ht.load_factor_threshold {
        return 1
    }
    return 0
}

func hash_table_get_lru_entry(hash_table ht) string {
    int lru_idx = 0
    int64 oldest_time = ht.buckets[0].timestamp
    
    int i = 1
    for i < ht.num_buckets {
        if len(ht.buckets[i].key) > 0 && ht.buckets[i].timestamp < oldest_time {
            oldest_time = ht.buckets[i].timestamp
            lru_idx = i
        }
        i = i + 1
    }
    
    if len(ht.buckets[lru_idx].key) > 0 {
        return ht.buckets[lru_idx].key
    }
    return ""
}
