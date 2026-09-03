package neurx.device.cuda_stream_manager

use neurx.device.cuda_runtime_binding
use std.vec.vec

struct stream_pool {
    vec[int64] available_streams
    vec[int64] busy_streams
    int max_streams
    int current_size
}

func new_stream_pool(int max_count) stream_pool {
    return stream_pool{
        available_streams: vec[int64](),
        busy_streams: vec[int64](),
        max_streams: max_count,
        current_size: 0,
    }
}

func stream_pool_init(stream_pool* pool) (bool, string) {
    for i := 0; i < pool.max_streams; i = i + 1 {
        stream, ok, err := cuda_stream_create()
        if !ok {
            return false, err
        }
        pool.available_streams.push(stream)
        pool.current_size = pool.current_size + 1
    }
    return true, ""
}

func stream_pool_acquire(stream_pool* pool) (int64, bool, string) {
    if pool.available_streams.len() == 0 {
        return 0, false, "no available streams"
    }
    
    stream := pool.available_streams[pool.available_streams.len() - 1]
    pool.available_streams.pop()
    pool.busy_streams.push(stream)
    
    return stream, true, ""
}

func stream_pool_release(stream_pool* pool, int64 stream) (bool, string) {
    for i := 0; i < pool.busy_streams.len(); i = i + 1 {
        if pool.busy_streams[i] == stream {

            pool.busy_streams[i] = pool.busy_streams[pool.busy_streams.len() - 1]
            pool.busy_streams.pop()
            pool.available_streams.push(stream)
            return true, ""
        }
    }
    
    return false, "stream not found in pool"
}

func stream_pool_wait(stream_pool* pool, int64 stream) (bool, string) {
    return cuda_stream_synchronize(stream)
}

func stream_pool_wait_all(stream_pool* pool) (bool, string) {
    for i := 0; i < pool.busy_streams.len(); i = i + 1 {
        ok, err := cuda_stream_synchronize(pool.busy_streams[i])
        if !ok {
            return false, err
        }
    }
    return true, ""
}

func stream_pool_finalize(stream_pool* pool) (bool, string) {
    ok, err := stream_pool_wait_all(pool)
    if !ok {
        return false, err
    }
    
    for i := 0; i < pool.available_streams.len(); i = i + 1 {
        ok, err := cuda_stream_destroy(pool.available_streams[i])
        if !ok {
            return false, err
        }
    }
    
    for i := 0; i < pool.busy_streams.len(); i = i + 1 {
        ok, err := cuda_stream_destroy(pool.busy_streams[i])
        if !ok {
            return false, err
        }
    }
    
    pool.current_size = 0
    return true, ""
}

func stream_pool_size(stream_pool* pool) int {
    return pool.current_size
}

func stream_pool_available_count(stream_pool* pool) int {
    return pool.available_streams.len()
}

func stream_pool_busy_count(stream_pool* pool) int {
    return pool.busy_streams.len()
}
