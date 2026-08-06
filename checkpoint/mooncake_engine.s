import "tensor/tensor.s"
import "distributed/nccl_collectives.s"
import "checkpoint/checkpoint.s"

struct mooncake_config {
    world_size: i32
    rank: i32
    use_nccl: bool
    use_p2p: bool
    ring_topology: bool
    chunk_size: i64
    num_streams: i32
    enable_compression: bool
    compression_method: string
}

struct mooncake_engine {
    config: mooncake_config
    prev_rank: i32
    next_rank: i32
    send_streams: []cuda_stream
    recv_streams: []cuda_stream
    send_buffers: []tensor
    recv_buffers: []tensor
    bytes_transferred: i64
    transfer_count: i64
    total_transfer_time: f64
}

func new_mooncake_engine(config: mooncake_config) -> mooncake_engine {
    let prev_rank = (config.rank - 1 + config.world_size) % config.world_size
    let next_rank = (config.rank + 1) % config.world_size
    let send_streams: []cuda_stream = []
    let recv_streams: []cuda_stream = []
    for i in 0..config.num_streams {
        send_streams.push(cuda_stream_create())
        recv_streams.push(cuda_stream_create())
    }
    return mooncake_engine{
        config: config,
        prev_rank: prev_rank,
        next_rank: next_rank,
        send_streams: send_streams,
        recv_streams: recv_streams,
        send_buffers: [],
        recv_buffers: [],
        bytes_transferred: 0,
        transfer_count: 0,
        total_transfer_time: 0.0,
    }
}

func (engine: *mooncake_engine) sync_weights(
    model_state: map[string]tensor,
    source_ranks: []i32,
    target_ranks: []i32
) {
    let start_time = get_time()
    if engine.config.rank in source_ranks {
        engine.send_weights(model_state, target_ranks)
    } else if engine.config.rank in target_ranks {
        engine.receive_weights(model_state, source_ranks)
    }
    let elapsed = get_time() - start_time
    engine.total_transfer_time += elapsed
    engine.transfer_count += 1
}

func (engine: *mooncake_engine) send_weights(
    model_state: map[string]tensor,
    target_ranks: []i32
) {
    let flat_params = engine.flatten_state(model_state)
    if engine.config.enable_compression {
        flat_params = engine.compress(flat_params)
    }
    let total_size = flat_params.numel() * flat_params.element_size()
    engine.bytes_transferred += total_size
    if engine.config.use_nccl && engine.is_same_node(target_ranks) {
        nccl_broadcast(flat_params, root: engine.config.rank)
    } else if engine.config.ring_topology {
        engine.ring_send(flat_params, target_ranks)
    } else {
        for target in target_ranks {
            engine.p2p_send(flat_params, target)
        }
    }
}

func (engine: *mooncake_engine) receive_weights(
    model_state: map[string]tensor,
    source_ranks: []i32
) {
    let total_size = engine.compute_state_size(model_state)
    let flat_params = tensor_zeros([total_size])
    if engine.config.use_nccl && engine.is_same_node(source_ranks) {
        let root = source_ranks[0]
        nccl_broadcast(flat_params, root: root)
    } else if engine.config.ring_topology {
        engine.ring_recv(flat_params, source_ranks)
    } else {
        let source = source_ranks[0]
        engine.p2p_recv(flat_params, source)
    }
    if engine.config.enable_compression {
        flat_params = engine.decompress(flat_params)
    }
    engine.unflatten_state(flat_params, model_state)
}

func (engine: *mooncake_engine) ring_send(params: tensor, target_ranks: []i32) {
    let num_chunks = (params.numel() * params.element_size() + engine.config.chunk_size - 1) /
                     engine.config.chunk_size
    let chunk_elems = engine.config.chunk_size / params.element_size()
    let offset: i64 = 0
    for chunk_id in 0..num_chunks {
        let stream_id = chunk_id % engine.config.num_streams
        let stream = engine.send_streams[stream_id]
        let chunk_size = min(chunk_elems, params.numel() - offset)
        let chunk = params.slice(offset, offset + chunk_size)
        cuda_memcpy_async(
            chunk,
            dest_rank: engine.next_rank,
            stream: stream
        )
        offset += chunk_size
    }
    for stream in engine.send_streams {
        cuda_stream_synchronize(stream)
    }
}

func (engine: *mooncake_engine) ring_recv(params: tensor, source_ranks: []i32) {
    let num_chunks = (params.numel() * params.element_size() + engine.config.chunk_size - 1) /
                     engine.config.chunk_size
    let chunk_elems = engine.config.chunk_size / params.element_size()
    let offset: i64 = 0
    for chunk_id in 0..num_chunks {
        let stream_id = chunk_id % engine.config.num_streams
        let stream = engine.recv_streams[stream_id]
        let chunk_size = min(chunk_elems, params.numel() - offset)
        let chunk = params.slice(offset, offset + chunk_size)
        cuda_memcpy_async(
            chunk,
            source_rank: engine.prev_rank,
            stream: stream
        )
        offset += chunk_size
    }
    for stream in engine.recv_streams {
        cuda_stream_synchronize(stream)
    }
}

func (engine: *mooncake_engine) p2p_send(params: tensor, target_rank: i32) {
    let stream = engine.send_streams[0]
    cuda_memcpy_async(
        params,
        dest_rank: target_rank,
        stream: stream
    )
    cuda_stream_synchronize(stream)
}

func (engine: *mooncake_engine) p2p_recv(params: tensor, source_rank: i32) {
    let stream = engine.recv_streams[0]
    cuda_memcpy_async(
        params,
        source_rank: source_rank,
        stream: stream
    )
    cuda_stream_synchronize(stream)
}

func (engine: *mooncake_engine) flatten_state(state: map[string]tensor) -> tensor {
    let total_size: i64 = 0
    let param_list: []tensor = []
    for name, param in state {
        total_size += param.numel()
        param_list.push(param.flatten())
    }
    return tensor_cat(param_list)
}

func (engine: *mooncake_engine) unflatten_state(flat: tensor, state: map[string]tensor) {
    let offset: i64 = 0
    for name, param in state {
        let size = param.numel()
        let chunk = flat.slice(offset, offset + size)
        param.copy_(chunk.reshape(param.shape))
        offset += size
    }
}

func (engine: *mooncake_engine) compute_state_size(state: map[string]tensor) -> i64 {
    let total: i64 = 0
    for name, param in state {
        total += param.numel()
    }
    return total
}

func (engine: *mooncake_engine) is_same_node(ranks: []i32) -> bool {
    for rank in ranks {
        if abs(rank - engine.config.rank) > 8 {
            return false
        }
    }
    return true
}

func (engine: *mooncake_engine) compress(data: tensor) -> tensor {
    match engine.config.compression_method {
        "lz4" => return lz4_compress(data),
        "zstd" => return zstd_compress(data),
        _ => return data,
    }
}

func (engine: *mooncake_engine) decompress(data: tensor) -> tensor {
    match engine.config.compression_method {
        "lz4" => return lz4_decompress(data),
        "zstd" => return zstd_decompress(data),
        _ => return data,
    }
}

func (engine: *mooncake_engine) get_statistics() -> (i64, f64, f64) {
    let avg_bandwidth: f64 = 0.0
    if engine.total_transfer_time > 0.0 {
        avg_bandwidth = f64(engine.bytes_transferred) / engine.total_transfer_time / 1e9
    }
    return (
        engine.bytes_transferred,
        engine.total_transfer_time,
        avg_bandwidth
    )
}

func (engine: *mooncake_engine) print_statistics() {
    let bytes, time, bandwidth = engine.get_statistics()
    println(f"Mooncake Transfer Statistics:")
    println(f"  Total bytes transferred: {bytes / 1e9:.2f} GB")
    println(f"  Total transfer time: {time:.2f} s")
    println(f"  Average bandwidth: {bandwidth:.2f} GB/s")
    println(f"  Number of transfers: {engine.transfer_count}")
}

func (engine: *mooncake_engine) destroy() {
    for stream in engine.send_streams {
        cuda_stream_destroy(stream)
    }
    for stream in engine.recv_streams {
        cuda_stream_destroy(stream)
    }
}

func lz4_compress(data: tensor) -> tensor {
    return data
}

func lz4_decompress(data: tensor) -> tensor {
    return data
}

func zstd_compress(data: tensor) -> tensor {
    return data
}

func zstd_decompress(data: tensor) -> tensor {
    return data
}
