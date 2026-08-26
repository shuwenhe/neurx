package neurx.kernel.mm.allocator

use std.vec.vec

struct memory_region {
    int base_addr
    int size
    bool is_free
    int device_id
}

struct tensor_metadata {
    int addr
    int size
    int dtype
    int shape_rank
    int device_id
}

struct tensor_pool {
    int base_addr
    int total_size
    int allocated_size
    vec[memory_region] regions
}

struct pool_stats {
    int allocated
    int free
    int total
}

func create_tensor_pool(int base_addr, int total_size) tensor_pool {
    pool := tensor_pool {
        base_addr: base_addr,
        total_size: total_size,
        allocated_size: 0,
        regions: vec[memory_region]()
    }
    pool
}

func allocate_tensor(&mut tensor_pool pool, int size, int device_id) int {
    i := 0
    for i < pool.regions.len() {
        region := pool.regions[i]
        if region.is_free && region.size >= size {
            mark_region_used(pool, region.base_addr, size, device_id)
            pool.allocated_size = pool.allocated_size + size
            return region.base_addr
        }
        i = i + 1
    }
    
    new_addr := pool.base_addr + pool.allocated_size
    if pool.allocated_size + size <= pool.total_size {
        mark_region_used(pool, new_addr, size, device_id)
        pool.allocated_size = pool.allocated_size + size
        return new_addr
    }
    
    -1
}

func free_tensor(&mut tensor_pool pool, int addr) bool {
    i := 0
    for i < pool.regions.len() {
        region := pool.regions[i]
        if region.base_addr == addr {
            pool.allocated_size = pool.allocated_size - region.size
            return true
        }
        i = i + 1
    }
    false
}

func find_free_region(&mut tensor_pool pool, int size) int {
    i := 0
    for i < pool.regions.len() {
        region := pool.regions[i]
        if region.is_free && region.size >= size {
            return region.base_addr
        }
        i = i + 1
    }
    -1
}

func mark_region_used(&mut tensor_pool pool, int addr, int size, int device_id) {
    new_region := memory_region {
        base_addr: addr,
        size: size,
        is_free: false,
        device_id: device_id
    }
    pool.regions.push(new_region)
}

func get_pool_stats(&tensor_pool pool) pool_stats {
    stats := pool_stats {
        allocated: pool.allocated_size,
        free: pool.total_size - pool.allocated_size,
        total: pool.total_size
    }
    stats
}

func defragment_pool(&mut tensor_pool pool) {
    compacted := vec[memory_region]()
    i := 0
    for i < pool.regions.len() {
        region := pool.regions[i]
        if !region.is_free {
            compacted.push(region)
        }
        i = i + 1
    }
    pool.regions = compacted
}

func coalesce_free_blocks(&mut tensor_pool pool) {
}
