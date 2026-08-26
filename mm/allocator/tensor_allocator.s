package neurx.kernel.mm.allocator

use std.vec.vec

struct memory_region {
    int base_addr
    int size
    bool is_free
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

func get_allocated_size(tensor_pool pool) int {
    pool.allocated_size
}

func get_total_size(tensor_pool pool) int {
    pool.total_size
}

func get_free_size(tensor_pool pool) int {
    pool.total_size - pool.allocated_size
}

func get_pool_stats(tensor_pool pool) pool_stats {
    stats := pool_stats {
        allocated: pool.allocated_size,
        free: pool.total_size - pool.allocated_size,
        total: pool.total_size
    }
    stats
}
