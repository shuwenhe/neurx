package main

use neurx.inference.runtime.production_engine
use neurx.inference.runtime.worker_cluster
use neurx.inference.scheduler.vllm_scheduler

func test_parallel_topology() bool {
    parallel_topology topology
    topology.tensor_parallel_size = 2
    topology.pipeline_parallel_size = 2
    topology.data_parallel_size = 2
    topology.expert_parallel_size = 4
    topology.world_size = 0
    worker_cluster_state cluster = neurx.inference.runtime.worker_cluster.new_worker_cluster(topology, 1000, 2)
    if !cluster.initialized || cluster.topology.world_size != 8 { return false }
    int rank = 0
    while rank < cluster.topology.world_size {
        worker_cluster_result registered = neurx.inference.runtime.worker_cluster.worker_register(cluster, "worker-" + int_to_str(rank), "node-0", rank, rank, rank, 100)
        if !registered.success { return false }
        cluster = registered.state
        worker_cluster_result ready = neurx.inference.runtime.worker_cluster.worker_mark_ready(cluster, registered.worker.worker_id, registered.worker.generation, 100)
        if !ready.success { return false }
        cluster = ready.state
        rank = rank + 1
    }
    neurx.inference.runtime.worker_cluster.worker_cluster_ready(cluster) && neurx.inference.runtime.worker_cluster.worker_replica_ready(cluster, 0) && neurx.inference.runtime.worker_cluster.worker_replica_ready(cluster, 1)
}


func test_production_engine_contract() bool {
    production_engine_config config
    config.model_directory = "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct"
    config.backend_name = "cuda"
    config.served_model_name = "qwen2.5-0.5b"
    config.scheduler = neurx.inference.scheduler.vllm_scheduler.default_vllm_scheduler_config()
    config.topology.tensor_parallel_size = 1
    config.topology.pipeline_parallel_size = 1
    config.topology.data_parallel_size = 1
    config.topology.expert_parallel_size = 1
    config.total_kv_blocks = 1024
    config.kv_block_size = 16
    config.kv_watermark_blocks = 16
    config.heartbeat_timeout_ms = 30000
    config.max_worker_restarts = 3
    config.max_request_retries = 2
    config.gpu_device_count = 1
    config.backend_abi_ready = true
    production_engine_state state = neurx.inference.runtime.production_engine.new_production_engine(config)
    if !state.initialized { return false }
    production_engine_result registered = neurx.inference.runtime.production_engine.engine_register_worker(state, "worker-0", "node-0", 0, 0, 0, 100)
    if !registered.success { return false }
    production_engine_result submitted = neurx.inference.runtime.production_engine.engine_submit(registered.state, "request-1", "qwen2.5-0.5b", 8, 2, 0, [], true, 110)
    if !submitted.success { return false }
    production_engine_result scheduled = neurx.inference.runtime.production_engine.engine_schedule(submitted.state, 120)
    scheduled.success && scheduled.batch.ready && len(scheduled.batch.commands) == 1 && scheduled.batch.scheduled_tokens > 0
}


func main() {
    bool passed = test_parallel_topology()
    passed = passed && test_production_engine_contract()
    if passed {
        println("PASS production engine contract")
        return 0
    }
    println("FAIL production engine contract")
    1
}

