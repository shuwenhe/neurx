package neurx.kernel.mm.allocator

use std.vec.vec

struct memory_region {
    base_addr: int64
    size: int64
    is_free: bool
    device_id: int
}

struct tensor_metadata {
    addr: int64
    size: int64
    dtype: int
    shape_rank: int
    device_id: int
}

struct tensor_pool {
    base_addr: int64
    total_size: int64
    allocated_size: int64
    regions: vec[memory_region]
}

struct tensor_pool {
    base_addr: int64
    total_size: int64
    allocated_size: int64
    regions: vec[memory_region]
}

func create_tensor_pool(base_addr: int64, total_size: int64) tensor_pool {
    pool := tensor_pool {
        base_addr: base_addr,
        total_size: total_size,
        allocated_size: 0,
        regions: vec[memory_region]()
    }
    pool
}

func allocate_tensor(pool: &mut tensor_pool, size: int64, device_id: int) int64 {
    addr := find_free_region(pool, size)
    if addr == 0 {
        return 0
    }
    
    mark_region_used(pool, addr, size, device_id)
    pool.allocated_size = pool.allocated_size + size
    addr
}

func free_tensor(pool: &mut tensor_pool, addr: int64) bool {
    i := 0
    for i < pool.regions.len() {
        if pool.regions.data[i].base_addr == addr {
            pool.regions.data[i].is_free = true
            pool.allocated_size = pool.allocated_size - pool.regions.data[i].size
            return true
        }
        i = i + 1
    }
    false
}

func find_free_region(pool: &mut tensor_pool, size: int64) int64 {
    i := 0
    for i < pool.regions.len() {
        region := pool.regions.data[i]
        if region.is_free && region.size >= size {
            return region.base_addr
        }
        i = i + 1
    }
    
    if pool.allocated_size + size <= pool.total_size {
        new_addr := pool.base_addr + pool.allocated_size
        return new_addr
    }
    
    0
}

func mark_region_used(pool: &mut tensor_pool, addr: int64, size: int64, device_id: int) {
    region := memory_region {
        base_addr: addr,
        size: size,
        is_free: false,
        device_id: device_id
    }
    pool.regions.push(region)
}

func get_pool_stats(pool: &tensor_pool) (int64, int64, int64) {
    free_size := pool.total_size - pool.allocated_size
    (pool.allocated_size, free_size, pool.total_size)
}

func defragment_pool(pool: &mut tensor_pool) {
    new_regions := vec[memory_region]()
    i := 0
    for i < pool.regions.len() {
        if !pool.regions.data[i].is_free {
            new_regions.push(pool.regions.data[i])
        }
        i = i + 1
    }
    pool.regions = new_regions
}

func coalesce_free_blocks(pool: &mut tensor_pool) {
    i := 0
    while i < pool.regions.len() - 1 {
        curr := pool.regions.data[i]
        next := pool.regions.data[i + 1]
        
        if curr.is_free && next.is_free && curr.base_addr + curr.size == next.base_addr {
            pool.regions.data[i].size = curr.size + next.size
            j := i + 1
            for j < pool.regions.len() - 1 {
                pool.regions.data[j] = pool.regions.data[j + 1]
                j = j + 1
            }
        } else {
            i = i + 1
        }
    }
}
