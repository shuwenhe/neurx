package neurx.tests.test_vllm_distributed

use neurx.distributed.parallel_state.{model_parallel_config, vllm_parallel_state, group_coordinator, init_distributed_environment, model_parallel_is_initialized, group_first_rank, group_last_rank, group_next_rank, group_previous_rank, destroy_distributed_environment}
use neurx.distributed.communication_op.{distributed_tensor, collective_result, make_distributed_tensor, tensor_model_parallel_all_reduce, tensor_model_parallel_all_gather, tensor_model_parallel_reduce_scatter, tensor_model_parallel_gather, all_to_all_single}
use neurx.distributed.kv_transfer.{kv_transfer_config, kv_transfer_state, kv_transfer_begin_result, ensure_kv_transfer_initialized, has_kv_transfer_group, begin_kv_transfer, finish_kv_transfer, ensure_kv_transfer_shutdown}
use neurx.distributed.weight_transfer.{weight_transfer_config, weight_transfer_state, weight_parameter_metadata, weight_apply_result, init_weight_transfer_engine, start_weight_update, apply_weight_parameter, finish_weight_update, weight_update_complete}

func expect(bool condition, string name) int {
    if condition {
        println("PASS " + name)
        return 0
    }
    println("FAIL " + name)
    1
}

func expect_ranks([]int actual, []int expected, string name) int {
    bool equal = len(actual) == len(expected)
    int i = 0
    while equal && i < len(expected) {
        if actual[i] != expected[i] {
            equal = false
        }
        i = i + 1
    }
    expect(equal, name)
}

func expect_floats([]float actual, []float expected, string name) int {
    bool equal = len(actual) == len(expected)
    int i = 0
    while equal && i < len(expected) {
        if actual[i] != expected[i] {
            equal = false
        }
        i = i + 1
    }
    expect(equal, name)
}

func test_model_parallel_config() model_parallel_config {
    model_parallel_config {
        world_size: 8,
        rank: 5,
        local_rank: 1,
        tensor_parallel_size: 2,
        pipeline_parallel_size: 2,
        data_parallel_size: 2,
        prefill_context_parallel_size: 1,
        decode_context_parallel_size: 2,
        backend: "cpu",
    }
}

func test_parallel_state() int {
    int failures = 0
    model_parallel_config config = test_model_parallel_config()
    vllm_parallel_state state = init_distributed_environment(config)
    failures = failures + expect(model_parallel_is_initialized(state), "model parallel initialization")
    failures = failures + expect(state.coordinates.data_parallel_rank == 1, "data parallel coordinate")
    failures = failures + expect(state.coordinates.pipeline_parallel_rank == 0, "pipeline parallel coordinate")
    failures = failures + expect(state.coordinates.tensor_parallel_rank == 1, "tensor parallel coordinate")
    failures = failures + expect_ranks(state.tensor_parallel_group.ranks, []int{4, 5}, "tensor parallel ranks")
    failures = failures + expect_ranks(state.pipeline_parallel_group.ranks, []int{5, 7}, "pipeline parallel ranks")
    failures = failures + expect_ranks(state.data_parallel_group.ranks, []int{1, 5}, "data parallel ranks")
    failures = failures + expect_ranks(state.expert_parallel_group.ranks, []int{0, 1, 4, 5}, "expert parallel ranks")
    failures = failures + expect_ranks(state.decode_context_parallel_group.ranks, []int{4, 5}, "decode context parallel ranks")
    failures = failures + expect(group_first_rank(state.pipeline_parallel_group) == 5, "pipeline first rank")
    failures = failures + expect(group_last_rank(state.pipeline_parallel_group) == 7, "pipeline last rank")
    failures = failures + expect(group_next_rank(state.pipeline_parallel_group) == 7, "pipeline next rank")
    failures = failures + expect(group_previous_rank(state.pipeline_parallel_group) == 7, "pipeline previous rank wraps")
    state = destroy_distributed_environment(state)
    failures = failures + expect(!state.distributed_initialized && !state.model_parallel_initialized, "distributed environment shutdown")
    failures
}

func test_collectives() int {
    int failures = 0
    vllm_parallel_state state = init_distributed_environment(test_model_parallel_config())
    group_coordinator group = state.tensor_parallel_group
    distributed_tensor input = make_distributed_tensor([]float{1.0, 2.0, 3.0, 4.0}, []int{2, 2}, "float32")
    collective_result reduced = tensor_model_parallel_all_reduce(group, input)
    failures = failures + expect(reduced.success, "all-reduce succeeds")
    failures = failures + expect_floats(reduced.tensor.data, []float{2.0, 4.0, 6.0, 8.0}, "all-reduce values")
    collective_result gathered = tensor_model_parallel_all_gather(group, input, 1)
    failures = failures + expect(gathered.success, "all-gather succeeds")
    failures = failures + expect_ranks(gathered.tensor.shape, []int{2, 4}, "all-gather shape")
    failures = failures + expect_floats(gathered.tensor.data, []float{1.0, 2.0, 1.0, 2.0, 3.0, 4.0, 3.0, 4.0}, "all-gather values")
    distributed_tensor scatter_input = make_distributed_tensor([]float{1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0}, []int{2, 4}, "float32")
    collective_result scattered = tensor_model_parallel_reduce_scatter(group, scatter_input, 1)
    failures = failures + expect(scattered.success, "reduce-scatter succeeds")
    failures = failures + expect_ranks(scattered.tensor.shape, []int{2, 2}, "reduce-scatter shape")
    failures = failures + expect_floats(scattered.tensor.data, []float{6.0, 8.0, 14.0, 16.0}, "reduce-scatter rank slice")
    collective_result destination_only = tensor_model_parallel_gather(group, input, 0, 1)
    failures = failures + expect(destination_only.success && !destination_only.present, "gather returns only on destination")
    collective_result exchanged = all_to_all_single(group, input)
    failures = failures + expect_floats(exchanged.tensor.data, []float{3.0, 4.0, 3.0, 4.0}, "all-to-all destination chunks")
    failures
}

func test_kv_transfer() int {
    int failures = 0
    kv_transfer_config config = kv_transfer_config {
        connector: "nccl",
        engine_id: "engine-0",
        role: "producer",
        rank: 0,
        world_size: 2,
        enabled: true,
    }
    kv_transfer_state state = ensure_kv_transfer_initialized(config)
    failures = failures + expect(has_kv_transfer_group(state), "KV transfer initialization")
    kv_transfer_begin_result started = begin_kv_transfer(state, []int{10, 11}, 1, 32, 128)
    failures = failures + expect(started.success && started.request.source_rank == 0 && started.request.destination_rank == 1, "KV transfer request routing")
    state = finish_kv_transfer(started.state, started.request, true, "")
    failures = failures + expect(state.completed_transfers == 1 && state.bytes_sent == 128 && state.active_transfers == 0, "KV transfer accounting")
    state = ensure_kv_transfer_shutdown(state)
    failures = failures + expect(!has_kv_transfer_group(state), "KV transfer shutdown")
    failures
}

func test_weight_transfer() int {
    int failures = 0
    weight_transfer_config config = weight_transfer_config {
        backend: "nccl",
        rank: 0,
        world_size: 2,
        supports_draft_model: true,
    }
    weight_transfer_state state = init_weight_transfer_engine(config)
    weight_apply_result update = start_weight_update(state, 7, 2, false)
    failures = failures + expect(update.success, "weight update start")
    weight_parameter_metadata first = weight_parameter_metadata {
        name: "model.layers.0.weight",
        dtype: "float32",
        shape: []int{2, 2},
        byte_count: 16,
    }
    update = apply_weight_parameter(update.state, first)
    if !update.success { println("weight update error: " + update.error_message) }
    failures = failures + expect(update.success, "first weight parameter")
    weight_parameter_metadata second = weight_parameter_metadata {
        name: "model.layers.1.weight",
        dtype: "float32",
        shape: []int{2, 2},
        byte_count: 16,
    }
    update = apply_weight_parameter(update.state, second)
    if !update.success { println("weight update error: " + update.error_message) }
    failures = failures + expect(update.success, "second weight parameter")
    update = finish_weight_update(update.state)
    failures = failures + expect(update.success && update.state.phase == weight_update_complete(), "weight update commit")
    failures = failures + expect(update.state.received_parameters == 2 && update.state.bytes_received == 32, "weight update accounting")
    failures
}

func main() {
    int failures = 0
    failures = failures + test_parallel_state()
    failures = failures + test_collectives()
    failures = failures + test_kv_transfer()
    failures = failures + test_weight_transfer()
    if failures == 0 {
        println("vLLM distributed contract: PASS")
    } else {
        println("vLLM distributed contract: FAIL")
    }
}
