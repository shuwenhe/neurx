
import "types.s"
import "worker_base.s"
import "gpu_worker.s"
import "worker_manager.s"
import "communication.s"
import "batch_processor.s"

func LoadBalancingExample() {
    println("=== Load Balancing Example ===")

    policy := SchedulingPolicy{
        policy_type: 1,
        enable_preemption: 1,
        enable_backfill: 1,
    }

    manager := NewWorkerManager(8, policy)

    for i := 0; i < 8; i++ {
        state := WorkerState{
            worker_id: i,
            state: WORKER_STATE_READY,
            load_percentage: i * 12,
            queue_size: i,
        }
        manager.RegisterWorker(state)
    }

    for i := 0; i < 32; i++ {
        request := RequestMetadata{
            request_id: "urgent_" + string(i),
            prompt_tokens: 512,
            max_tokens: 1024,
            priority: 3,
            timestamp: 0,
        }
        manager.SubmitRequest(request)
    }

    batch_count := 0
    for manager.pending_count > 0 {
        batch := manager.GetNextBatch(256)
        if batch.request_count > 0 {
            result := manager.ScheduleBatch(batch)
            if result.success == 1 {
                scheduled_worker := batch.scheduled_worker
                println("Batch", batch_count, "scheduled to worker", scheduled_worker)
                batch_count++
            }
        }
    }

    manager.Shutdown()
    println("Load balancing complete\n")
}

func FailureRecoveryExample() {
    println("=== Failure Recovery Example ===")

    manager := NewWorkerManager(4, SchedulingPolicy{policy_type: 1})

    for i := 0; i < 4; i++ {
        state := WorkerState{
            worker_id: i,
            state: WORKER_STATE_READY,
        }
        manager.RegisterWorker(state)
    }

    for i := 0; i < 16; i++ {
        request := RequestMetadata{
            request_id: "req_" + string(i),
            prompt_tokens: 256,
            max_tokens: 512,
            priority: 0,
            timestamp: 0,
        }
        manager.SubmitRequest(request)
    }

    println("Submitted 16 requests")

    println("Simulating worker 1 failure...")
    manager.UpdateWorkerState(1, WORKER_STATE_ERROR)

    manager.MonitorHealth()

    pool := manager.GetPoolState()
    println("After failure - Error workers:", pool.error_workers)
    println("Active workers:", pool.active_workers)

    manager.Shutdown()
    println("Failure recovery complete\n")
}

func DynamicBatchSizingExample() {
    println("=== Dynamic Batch Sizing Example ===")

    processor := NewBatchProcessor(512, SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    })

    requests := make([]RequestMetadata, 0)
    for i := 0; i < 128; i++ {
        size := i32(64 + (i % 4) * 256)
        req := RequestMetadata{
            request_id: "req_" + string(i),
            prompt_tokens: size,
            max_tokens: 256,
            priority: 0,
            timestamp: 0,
        }
        requests = append(requests, req)
    }

    batch_sizes := []i32{64, 128, 256, 512}

    for idx := 0; idx < len(batch_sizes); idx++ {
        size := batch_sizes[idx]
        if len(requests) == 0 {
            break
        }

        batch_reqs := requests[:size]
        if size > len(requests) {
            batch_reqs = requests
        }

        batch := processor.CreateBatch(batch_reqs)
        println("Batch with max size", size, "- actual requests:", batch.request_count)
        println("Total tokens:", batch.total_tokens)
        println("Avg tokens per request:", batch.total_tokens / batch.request_count)

        processor.CompleteBatch(batch, processor.EstimateLatency(batch))

        if size <= len(requests) {
            requests = requests[size:]
        } else {
            break
        }
    }

    stats := processor.GetBatchStats()
    println("Total batches processed:", stats["total_batches"])
    println()
}

func DistributedCommPatternsExample() {
    println("=== Distributed Communication Patterns Example ===")

    comm_config := CommunicationConfig{
        comm_type: COMM_TYPE_NCCL,
        timeout_ms: 10000,
        buffer_size: 2048,
    }

    handler := NewCommunicationHandler(comm_config, 4)

    println("Ring AllReduce pattern:")
    ring_data := make([]f32, 1024)
    for i := 0; i < 1024; i++ {
        ring_data[i] = f32(i)
    }

    worker_ids := []i32{0, 1, 2, 3}
    result := handler.AllReduce(ring_data, worker_ids)
    if result.success == 1 {
        println("AllReduce completed")
    }

    println("Tree AllGather pattern:")
    local_data := make([]f32, 256)
    gathered := handler.AllGather(local_data, worker_ids)
    println("Gathered", len(gathered), "elements from all workers")

    println("Broadcast pattern:")
    bcast_msg := WorkerMessage{
        message_id: 1000,
        sender_id: 0,
        message_type: 4,
        payload_size: 512,
    }
    success := handler.BroadcastMessage(bcast_msg, worker_ids)
    println("Broadcast sent to", success, "workers")

    println("Point-to-point with ACK pattern:")
    for i := 0; i < 4; i++ {
        p2p_msg := WorkerMessage{
            message_id: i64(2000 + i),
            sender_id: 0,
            receiver_id: i32(i + 1),
            message_type: 5,
            requires_ack: 1,
        }
        handler.SendMessage(p2p_msg)
    }

    handler.Shutdown()
    println("Communication patterns complete\n")
}

func PipelineParallelismExample() {
    println("=== Pipeline Parallelism Example ===")

    policy := SchedulingPolicy{
        policy_type: 1,
        enable_preemption: 1,
        enable_backfill: 1,
    }

    processor := NewBatchProcessor(256, policy)
    manager := NewWorkerManager(6, policy)

    for i := 0; i < 6; i++ {
        var stage string
        match i / 2 {
        case 0:
            stage = "prefill"
        case 1:
            stage = "decode"
        case 2:
            stage = "output"
        }

        state := WorkerState{
            worker_id: i,
            state: WORKER_STATE_READY,
            status: stage,
        }
        manager.RegisterWorker(state)
    }

    requests := make([]RequestMetadata, 0)
    for i := 0; i < 64; i++ {
        req := RequestMetadata{
            request_id: "req_" + string(i),
            prompt_tokens: 256,
            max_tokens: 512,
            priority: 0,
        }
        requests = append(requests, req)
    }

    println("Stage 1: Prefill")
    batch1 := processor.CreateBatch(requests)
    batch1.batch_type = BATCH_TYPE_PREFILL
    manager.ScheduleBatch(batch1)
    println("Scheduled prefill batch to workers 0-1")

    println("Stage 2: Decode")
    if len(requests) > 32 {
        batch2 := processor.CreateBatch(requests[32:])
        batch2.batch_type = BATCH_TYPE_DECODE
        manager.ScheduleBatch(batch2)
        println("Scheduled decode batch to workers 2-3")
    }

    println("Stage 3: Output")
    if len(requests) > 48 {
        batch3 := processor.CreateBatch(requests[48:])
        manager.ScheduleBatch(batch3)
        println("Scheduled output batch to workers 4-5")
    }

    pool := manager.GetPoolState()
    println("Active workers in pipeline:", pool.active_workers)
    println("Busy workers:", pool.busy_workers)

    manager.Shutdown()
    println("Pipeline parallelism example complete\n")
}

func AdaptiveBatchingExample() {
    println("=== Adaptive Batching Example ===")

    processor := NewBatchProcessor(256, SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    })

    target_latency := i32(100)
    current_batch_size := i32(128)

    println("Target latency: 100ms")
    println("Starting batch size: 128")

    for iteration := 0; iteration < 5; iteration++ {
        requests := make([]RequestMetadata, 0)
        for i := 0; i < current_batch_size; i++ {
            req := RequestMetadata{
                request_id: "req_" + string(i),
                prompt_tokens: 256,
                max_tokens: 512,
                priority: 0,
            }
            requests = append(requests, req)
        }

        batch := processor.CreateBatch(requests)
        estimated_latency := processor.EstimateLatency(batch)

        println("\nIteration", iteration+1)
        println("Batch size:", batch.request_count)
        println("Estimated latency:", estimated_latency, "ms")

        if estimated_latency > target_latency {
            current_batch_size = (current_batch_size * 7) / 8
            println("Latency exceeded - reducing batch size to", current_batch_size)
        } else if estimated_latency < target_latency / 2 {
            current_batch_size = (current_batch_size * 9) / 8
            println("Latency low - increasing batch size to", current_batch_size)
        } else {
            println("Latency optimal - maintaining batch size")
        }

        processor.CompleteBatch(batch, estimated_latency)
    }

    stats := processor.GetBatchStats()
    println("\nFinal statistics:")
    println("Total batches:", stats["total_batches"])
    println("Total tokens:", stats["total_tokens"])
    println()
}

func main() {
    println("╔════════════════════════════════════════════╗")
    println("║  NeurX Worker Advanced Examples            ║")
    println("╚════════════════════════════════════════════╝\n")

    LoadBalancingExample()
    FailureRecoveryExample()
    DynamicBatchSizingExample()
    DistributedCommPatternsExample()
    PipelineParallelismExample()
    AdaptiveBatchingExample()

    println("╔════════════════════════════════════════════╗")
    println("║  All advanced examples completed           ║")
    println("╚════════════════════════════════════════════╝")
}
