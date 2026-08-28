import "types.s"
import "worker_base.s"
import "gpu_worker.s"
import "worker_manager.s"
import "communication.s"
import "batch_processor.s"
func BasicWorkerExample() {
    println("=== Basic Worker Example ===")
    config := WorkerConfig{
        worker_id: 0,
        worker_type: WORKER_TYPE_GPU,
        device_id: 0,
        max_batch_size: 256,
        max_model_len: 4096,
        gpu_memory_mb: 24576,
        timeout_ms: DEFAULT_WORKER_TIMEOUT,
        enable_cache: 1,
    }
    worker := NewBaseWorker(config)
    result := worker.Initialize()
    if result.success == 1 {
        println("Worker initialized successfully")
    }
    for i := 0; i < 10; i++ {
        request := RequestMetadata{
            request_id: "req_" + string(i),
            prompt_tokens: 128,
            max_tokens: 256,
            priority: 0,
            timestamp: 0,
        }
        worker.SubmitRequest(request)
    }
    println("Queue size:", worker.GetQueueSize())
    batch := worker.GetNextBatch(32)
    println("Batch ID:", batch.batch_id)
    println("Batch size:", batch.request_count)
    println("Total tokens:", batch.total_tokens)
    worker.Shutdown()
    println("Worker shutdown complete\n")
}
func GPUWorkerExample() {
    println("=== GPU Worker Example ===")
    config := WorkerConfig{
        worker_id: 1,
        worker_type: WORKER_TYPE_GPU,
        device_id: 0,
        gpus: []i32{0, 1, 2},
        max_batch_size: 512,
        max_model_len: 8192,
        gpu_memory_mb: 24576,
        enable_cache: 1,
    }
    gpu_worker := NewGPUWorker(config)
    result := gpu_worker.Initialize()
    if result.success == 1 {
        println("GPU Worker initialized with", gpu_worker.device_count, "devices")
    }
    stats := gpu_worker.GetDeviceStats()
    for i := 0; i < len(stats); i++ {
        println("Device", i, "utilization:", stats[i], "%")
    }
    device := gpu_worker.AllocateMemory(1024)
    println("Allocated 1GB on device", device)
    batch := Batch{
        batch_id: 0,
        request_count: 32,
        batch_type: BATCH_TYPE_PREFILL,
        total_tokens: 4096,
        max_batch_size: 512,
    }
    result_exec := gpu_worker.ProcessBatch(batch)
    println("Batch execution latency:", result_exec.latency_ms, "ms")
    println("Total tokens processed:", result_exec.total_tokens)
    gpu_worker.Shutdown()
    println("GPU Worker shutdown complete\n")
}
func WorkerManagerExample() {
    println("=== Worker Manager Example ===")
    policy := SchedulingPolicy{
        policy_type: 1,
        enable_preemption: 1,
        enable_backfill: 1,
        batch_timeout_ms: 5000,
        max_queue_size: 1024,
        priority_levels: 4,
    }
    manager := NewWorkerManager(8, policy)
    println("Created worker manager for", 8, "workers")
    for i := 0; i < 4; i++ {
        state := WorkerState{
            worker_id: i,
            state: WORKER_STATE_READY,
            worker_type: WORKER_TYPE_GPU,
            status: "READY",
            queue_size: 0,
            device_id: i % 2,
        }
        manager.RegisterWorker(state)
    }
    for i := 0; i < 32; i++ {
        request := RequestMetadata{
            request_id: "req_" + string(i),
            prompt_tokens: 256 + i*16,
            max_tokens: 512,
            priority: i % 4,
            timestamp: 0,
        }
        manager.SubmitRequest(request)
    }
    println("Submitted 32 requests")
    println("Pending requests:", manager.pending_count)
    for i := 0; i < 4; i++ {
        batch := manager.GetNextBatch(32)
        if batch.request_count > 0 {
            result := manager.ScheduleBatch(batch)
            if result.success == 1 {
                println("Scheduled batch", batch.batch_id, "to", batch.request_count, "requests")
            }
        }
    }
    pool_state := manager.GetPoolState()
    println("Pool state - Active:", pool_state.active_workers, "Busy:", pool_state.busy_workers)
    stats := manager.GetPoolStatistics()
    println("Pool stats - Total requests:", stats.total_requests)
    println("Completed:", stats.completed_requests)
    manager.Shutdown()
    println("Worker Manager shutdown complete\n")
}
func WorkerCommunicationExample() {
    println("=== Worker Communication Example ===")
    comm_config := CommunicationConfig{
        comm_type: COMM_TYPE_RPC,
        timeout_ms: 5000,
        max_msg_size: 65536,
        retry_count: 3,
        use_compression: 1,
        buffer_size: 1024,
    }
    handler := NewCommunicationHandler(comm_config, 4)
    println("Created communication handler for 4 workers")
    for i := 0; i < 8; i++ {
        msg := WorkerMessage{
            message_id: i64(i),
            sender_id: 0,
            receiver_id: i32((i % 4) + 1),
            message_type: 0,
            payload_size: 256,
            requires_ack: 1,
        }
        result := handler.SendMessage(msg)
        if result.success == 1 {
            println("Sent message", i, "to worker", msg.receiver_id)
        }
    }
    for i := 1; i <= 3; i++ {
        msg := handler.ReceiveMessage(i)
        if msg.message_id > 0 {
            println("Worker", i, "received message", msg.message_id)
        }
    }
    broadcast_msg := WorkerMessage{
        message_id: 100,
        sender_id: 0,
        message_type: 2,
        payload_size: 512,
    }
    target_workers := []i32{1, 2, 3, 4}
    success := handler.BroadcastMessage(broadcast_msg, target_workers)
    println("Broadcast sent to", success, "workers")
    handler.Shutdown()
    println("Communication handler shutdown complete\n")
}
func BatchProcessingExample() {
    println("=== Batch Processing Example ===")
    policy := SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 10000,
    }
    processor := NewBatchProcessor(256, policy)
    println("Created batch processor with max size 256")
    requests := make([]RequestMetadata, 0)
    for i := 0; i < 64; i++ {
        req := RequestMetadata{
            request_id: "req_" + string(i),
            prompt_tokens: i32(128 + i*2),
            max_tokens: 512,
            priority: i % 4,
            timestamp: 0,
        }
        requests = append(requests, req)
    }
    batch := processor.CreateBatch(requests)
    println("Created batch with", batch.request_count, "requests")
    println("Batch total tokens:", batch.total_tokens)
    batch = processor.ReorderBatch(batch)
    println("Batch reordered by priority")
    balance := processor.CheckBatchBalance(batch)
    println("Batch balance check:", balance)
    latency := processor.EstimateLatency(batch)
    println("Estimated latency:", latency, "ms")
    processor.CompleteBatch(batch, latency)
    println("Batch completed")
    stats := processor.GetBatchStats()
    println("Batch stats - Total:", stats["total_batches"])
    println("Completed:", stats["completed"])
    println("Total tokens:", stats["total_tokens"])
    println()
}
func DistributedSyncExample() {
    println("=== Distributed Synchronization Example ===")
    sync_mgr := NewSynchronizationManager()
    println("Created synchronization manager")
    source := i32(0)
    targets := []i32{1, 2, 3}
    result := sync_mgr.InitiateSync(source, targets)
    if result.success == 1 {
        println("Initiated distributed sync from worker", source)
    }
    result = sync_mgr.WaitForSync(0, 5000)
    if result.success == 1 {
        println("Sync completed successfully")
    }
    println("Completed syncs:", sync_mgr.completed_syncs)
    println("Failed syncs:", sync_mgr.failed_syncs)
    println()
}
func main() {
    println("╔════════════════════════════════════════╗")
    println("║  NeurX Worker Basic Examples           ║")
    println("╚════════════════════════════════════════╝\n")
    BasicWorkerExample()
    GPUWorkerExample()
    WorkerManagerExample()
    WorkerCommunicationExample()
    BatchProcessingExample()
    DistributedSyncExample()
    println("╔════════════════════════════════════════╗")
    println("║  All examples completed                ║")
    println("╚════════════════════════════════════════╝")
}
