package neurx.distributed

use neurx.distributed.nccl_comm
use neurx.distributed.tensor_parallel
use neurx.distributed.pipeline_parallel
use neurx.device.abi

func test_nccl_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := nccl_comm.nccl_init(0, 4, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    rank, rank_success, rank_err := nccl_comm.nccl_get_rank()
    if !rank_success {
        failed = failed + 1
        return passed, failed, "Failed to get rank: " + rank_err
    }

    if rank != 0 {
        failed = failed + 1
        return passed, failed, "Rank mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_nccl_init passed"
}

func test_nccl_collective_ops() (int, int, string) {
    passed := 0
    failed := 0

    success, err := nccl_comm.nccl_init(0, 4, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    all_reduce_success, all_reduce_err := nccl_comm.nccl_all_reduce(0, 1024, 0)
    if !all_reduce_success {
        failed = failed + 1
        return passed, failed, "All-reduce failed: " + all_reduce_err
    }

    broadcast_success, broadcast_err := nccl_comm.nccl_broadcast(0, 1024, 0, 0)
    if !broadcast_success {
        failed = failed + 1
        return passed, failed, "Broadcast failed: " + broadcast_err
    }

    all_gather_success, all_gather_err := nccl_comm.nccl_all_gather(0, 0, 1024, 0)
    if !all_gather_success {
        failed = failed + 1
        return passed, failed, "All-gather failed: " + all_gather_err
    }

    passed = passed + 1
    return passed, failed, "test_nccl_collective_ops passed"
}

func test_nccl_point_to_point() (int, int, string) {
    passed := 0
    failed := 0

    success, err := nccl_comm.nccl_init(0, 4, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    send_success, send_err := nccl_comm.nccl_send(0, 1024, 1, 0)
    if !send_success {
        failed = failed + 1
        return passed, failed, "Send failed: " + send_err
    }

    passed = passed + 1
    return passed, failed, "test_nccl_point_to_point passed"
}

func test_nccl_barrier() (int, int, string) {
    passed := 0
    failed := 0

    success, err := nccl_comm.nccl_init(0, 4, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    barrier_success, barrier_err := nccl_comm.barrier()
    if !barrier_success {
        failed = failed + 1
        return passed, failed, "Barrier failed: " + barrier_err
    }

    passed = passed + 1
    return passed, failed, "test_nccl_barrier passed"
}

func test_tensor_parallel_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := tensor_parallel.tensor_parallel_init(4, 0, 4096)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    config, config_success, config_err := tensor_parallel.get_tensor_parallel_config()
    if !config_success {
        failed = failed + 1
        return passed, failed, "Failed to get config: " + config_err
    }

    if config.tp_size != 4 {
        failed = failed + 1
        return passed, failed, "Config mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_tensor_parallel_init passed"
}

func test_weight_sharding() (int, int, string) {
    passed := 0
    failed := 0

    success, err := tensor_parallel.tensor_parallel_init(4, 0, 4096)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    weight := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(8192 * 4096),
        ref_count: 1,
        is_view: false,
    }

    weight.shape.push(8192)
    weight.shape.push(4096)

    sharded, shard_success, shard_err := tensor_parallel.shard_weight_along_output(weight, 4, 0)
    if !shard_success {
        failed = failed + 1
        return passed, failed, "Failed: " + shard_err
    }

    if sharded.local_tensor.element_count != int64(2048 * 4096) {
        failed = failed + 1
        return passed, failed, "Sharded size mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_weight_sharding passed"
}

func test_all_reduce_output() (int, int, string) {
    passed := 0
    failed := 0

    output := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    combined, success, err := tensor_parallel.all_reduce_output(output, 4)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if combined.element_count != 4096 * 4 {
        failed = failed + 1
        return passed, failed, "Output size mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_all_reduce_output passed"
}

func test_pipeline_parallel_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := pipeline_parallel.pipeline_parallel_init(0, 4, 24)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    config, config_success, config_err := pipeline_parallel.get_pipeline_config()
    if !config_success {
        failed = failed + 1
        return passed, failed, "Failed to get config: " + config_err
    }

    if config.num_stages != 4 {
        failed = failed + 1
        return passed, failed, "Config mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_pipeline_parallel_init passed"
}

func test_activation_caching() (int, int, string) {
    passed := 0
    failed := 0

    success, err := pipeline_parallel.pipeline_parallel_init(0, 4, 24)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    activation := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    cache_success, cache_err := pipeline_parallel.cache_activation(activation, 0)
    if !cache_success {
        failed = failed + 1
        return passed, failed, "Failed to cache: " + cache_err
    }

    cached, cached_success, cached_err := pipeline_parallel.get_cached_activation(0)
    if !cached_success {
        failed = failed + 1
        return passed, failed, "Failed to get cached: " + cached_err
    }

    if cached.element_count != activation.element_count {
        failed = failed + 1
        return passed, failed, "Cached activation mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_activation_caching passed"
}

func test_microbatch_pipeline() (int, int, string) {
    passed := 0
    failed := 0

    input_ids := vec[int]()
    input_ids.push(1)
    input_ids.push(2)
    input_ids.push(3)

    output, success, err := pipeline_parallel.microbatch_pipeline_forward(input_ids, 4, 4)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output.element_count <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid output"
    }

    passed = passed + 1
    return passed, failed, "test_microbatch_pipeline passed"
}

func run_all_tests() (int, int, string) {
    total_passed := 0
    total_failed := 0
    results := ""

    p1, f1, r1 := test_nccl_init()
    total_passed = total_passed + p1
    total_failed = total_failed + f1
    results = results + r1 + " | "

    p2, f2, r2 := test_nccl_collective_ops()
    total_passed = total_passed + p2
    total_failed = total_failed + f2
    results = results + r2 + " | "

    p3, f3, r3 := test_nccl_point_to_point()
    total_passed = total_passed + p3
    total_failed = total_failed + f3
    results = results + r3 + " | "

    p4, f4, r4 := test_nccl_barrier()
    total_passed = total_passed + p4
    total_failed = total_failed + f4
    results = results + r4 + " | "

    p5, f5, r5 := test_tensor_parallel_init()
    total_passed = total_passed + p5
    total_failed = total_failed + f5
    results = results + r5 + " | "

    p6, f6, r6 := test_weight_sharding()
    total_passed = total_passed + p6
    total_failed = total_failed + f6
    results = results + r6 + " | "

    p7, f7, r7 := test_all_reduce_output()
    total_passed = total_passed + p7
    total_failed = total_failed + f7
    results = results + r7 + " | "

    p8, f8, r8 := test_pipeline_parallel_init()
    total_passed = total_passed + p8
    total_failed = total_failed + f8
    results = results + r8 + " | "

    p9, f9, r9 := test_activation_caching()
    total_passed = total_passed + p9
    total_failed = total_failed + f9
    results = results + r9 + " | "

    p10, f10, r10 := test_microbatch_pipeline()
    total_passed = total_passed + p10
    total_failed = total_failed + f10
    results = results + r10

    return total_passed, total_failed, results
}
