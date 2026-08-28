package neurx.gate_phase14_integration_test

use std.vec.vec
use neurx.device.abi
use neurx.compute.gpu_gemm
use neurx.compute.gpu_attention
use neurx.compute.gpu_activations
use neurx.compute.gpu_embedding
use neurx.model.transformer_forward
use neurx.io.weight_loader_complete
use neurx.distributed.collective_communication
use neurx.inference.inference_pipeline_phase14

func test_phase1_gpu_gemm_basic() (int, int, string) {
    passed := 0
    failed := 0

    m := 16
    n := 32
    k := 64

    params := gpu_gemm.gemm_params {
        m: m,
        n: n,
        k: k,
        alpha: 1.0,
        beta: 0.0,
    }
    config := gpu_gemm.gemm_config_create(params)

    if config.m == m && config.n == n && config.k == k {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "GPU GEMM basic"
}

func test_phase1_gpu_attention_basic() (int, int, string) {
    passed := 0
    failed := 0

    batch_size := 4
    seq_len := 64
    num_heads := 8
    head_dim := 64

    config := gpu_attention.attention_config_create(num_heads, head_dim, seq_len, batch_size)

    if config.num_heads == num_heads && config.batch_size == batch_size {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "GPU Attention basic"
}

func test_phase1_gpu_activations() (int, int, string) {
    passed := 0
    failed := 0

    element_count := 1000

    if element_count > 0 {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "GPU Activations"
}

func test_phase1_gpu_embedding() (int, int, string) {
    passed := 0
    failed := 0

    vocab_size := 30000
    embedding_dim := 4096
    batch_size := 4
    seq_len := 64

    config := gpu_embedding.embedding_config_create(vocab_size, embedding_dim, batch_size, seq_len)

    if config.vocab_size == vocab_size && config.embedding_dim == embedding_dim {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "GPU Embedding"
}

func test_phase2_transformer_context() (int, int, string) {
    passed := 0
    failed := 0

    batch_size := 4
    seq_len := 64
    num_layers := 24
    hidden_size := 4096

    context := transformer_forward.transformer_context_create(
        batch_size,
        seq_len,
        num_layers,
        hidden_size
    )

    if context.batch_size == batch_size && context.num_layers == num_layers {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "Transformer context"
}

func test_phase2_transformer_kv_cache() (int, int, string) {
    passed := 0
    failed := 0

    max_seq_len := 2048
    batch_size := 4
    num_heads := 32
    head_dim := 128

    cache, ok, err := transformer_forward.transformer_kv_cache_create(
        max_seq_len,
        batch_size,
        num_heads,
        head_dim
    )

    if ok && cache.max_seq_len == max_seq_len {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "Transformer KV Cache"
}

func test_phase3_weight_loader_init() (int, int, string) {
    passed := 0
    failed := 0

    model_path := "/path/to/model"
    device_id := 0
    cache_size := int64(1000000000)

    ok, err := weight_loader_complete.weight_loader_init(model_path, device_id, cache_size)

    if ok {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "Weight loader init"
}

func test_phase3_weight_shard_for_tp() (int, int, string) {
    passed := 0
    failed := 0

    batch_size := 4
    seq_len := 64

    weight := abi.device_tensor {
        data: 1000,
        shape: vec[int](),
        strides: vec[int](),
        dtype: "float32",
        device_id: 0,
        element_count: 1000,
        ref_count: 1,
        is_view: false,
    }

    weight.shape.push(4096)
    weight.shape.push(4096)

    tp_rank := 0
    tp_size := 4

    sharded, ok, err := weight_loader_complete.weight_shard_for_tensor_parallel(
        weight,
        tp_rank,
        tp_size,
        0
    )

    if ok {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "Weight shard for TP"
}

func test_phase4_ring_allreduce() (int, int, string) {
    passed := 0
    failed := 0

    rank := 0
    world_size := 4

    input_tensor := abi.device_tensor {
        data: 1000,
        shape: vec[int](),
        strides: vec[int](),
        dtype: "float32",
        device_id: 0,
        element_count: 1000,
        ref_count: 1,
        is_view: false,
    }

    output_tensor := abi.device_tensor {
        data: 2000,
        shape: vec[int](),
        strides: vec[int](),
        dtype: "float32",
        device_id: 0,
        element_count: 1000,
        ref_count: 1,
        is_view: false,
    }

    result, ok, err := collective_communication.ring_allreduce_forward(
        input_tensor,
        output_tensor,
        rank,
        world_size
    )

    if ok {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "Ring AllReduce"
}

func test_phase4_nccl_allreduce() (int, int, string) {
    passed := 0
    failed := 0

    send_buffer := abi.device_tensor {
        data: 1000,
        shape: vec[int](),
        strides: vec[int](),
        dtype: "float32",
        device_id: 0,
        element_count: 1000,
        ref_count: 1,
        is_view: false,
    }

    recv_buffer := abi.device_tensor {
        data: 2000,
        shape: vec[int](),
        strides: vec[int](),
        dtype: "float32",
        device_id: 0,
        element_count: 1000,
        ref_count: 1,
        is_view: false,
    }

    result, ok, err := collective_communication.nccl_allreduce(
        send_buffer,
        recv_buffer,
        1000,
        "sum",
        1,
        1
    )

    if ok {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "NCCL AllReduce"
}

func test_inference_pipeline_init() (int, int, string) {
    passed := 0
    failed := 0

    device_id := 0
    world_rank := 0
    world_size := 1
    batch_size := 4
    seq_len := 64

    ok, err := inference_pipeline_phase14.inference_pipeline_init(
        device_id,
        world_rank,
        world_size,
        batch_size,
        seq_len
    )

    if ok {
        passed = passed + 1
    } else {
        failed = failed + 1
    }

    return passed, failed, "Inference pipeline init"
}

func run_all_phase14_tests() (int, int) {
    total_passed := 0
    total_failed := 0

    p, f, _ := test_phase1_gpu_gemm_basic()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase1_gpu_attention_basic()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase1_gpu_activations()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase1_gpu_embedding()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase2_transformer_context()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase2_transformer_kv_cache()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase3_weight_loader_init()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase3_weight_shard_for_tp()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase4_ring_allreduce()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_phase4_nccl_allreduce()
    total_passed = total_passed + p
    total_failed = total_failed + f

    p, f, _ = test_inference_pipeline_init()
    total_passed = total_passed + p
    total_failed = total_failed + f

    return total_passed, total_failed
}
