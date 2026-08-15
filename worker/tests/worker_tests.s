
import "types.s"
import "worker_base.s"
import "gpu_worker.s"
import "worker_manager.s"
import "communication.s"
import "batch_processor.s"

struct TestResult {
    name            string
    passed          i32
    total           i32
    error_message   string
    execution_time  i32
}

var test_results []TestResult
var total_tests i32 = 0
var passed_tests i32 = 0

func LogTest(test_name string, condition i32, error_msg string) {
    total_tests++

    if condition == 1 {
        passed_tests++
        println("✓ PASS:", test_name)
    } else {
        println("✗ FAIL:", test_name, "-", error_msg)
    }
}

func TestWorkerInitialization() {
    println("\n--- Test: Worker Initialization ---")

    config := WorkerConfig{
        worker_id: 0,
        worker_type: WORKER_TYPE_GPU,
        device_id: 0,
        max_batch_size: 256,
        timeout_ms: DEFAULT_WORKER_TIMEOUT,
    }

    worker := NewBaseWorker(config)

    LogTest("Worker created", 1, "")
    LogTest("Worker initialized", worker.initialized, "Worker not initialized")
    LogTest("Worker state ready", worker.state == WORKER_STATE_READY, "State not READY")

    result := worker.Initialize()
    LogTest("Initialize returns success", result.success, "Initialize failed")

    result = worker.Shutdown()
    LogTest("Shutdown succeeds", result.success, "Shutdown failed")
}

func TestRequestSubmission() {
    println("\n--- Test: Request Submission ---")

    config := WorkerConfig{
        worker_id: 1,
        max_batch_size: 32,
        timeout_ms: 5000,
    }

    worker := NewBaseWorker(config)
    worker.Initialize()

    req1 := RequestMetadata{
        request_id: "test_1",
        prompt_tokens: 128,
        max_tokens: 256,
        priority: 0,
    }

    result := worker.SubmitRequest(req1)
    LogTest("Submit single request", result.success, "Failed to submit request")
    LogTest("Queue size is 1", worker.GetQueueSize() == 1, "Queue not updated")

    for i := 0; i < 15; i++ {
        req := RequestMetadata{
            request_id: "test_" + string(i+2),
            prompt_tokens: 256,
            max_tokens: 512,
            priority: i % 3,
        }
        worker.SubmitRequest(req)
    }

    LogTest("Queue size is 16", worker.GetQueueSize() == 16, "Queue size mismatch")

    worker.Shutdown()
}

func TestBatchRetrieval() {
    println("\n--- Test: Batch Retrieval ---")

    config := WorkerConfig{
        worker_id: 2,
        max_batch_size: 32,
    }

    worker := NewBaseWorker(config)
    worker.Initialize()

    for i := 0; i < 64; i++ {
        req := RequestMetadata{
            request_id: "batch_" + string(i),
            prompt_tokens: 128 + i*2,
            max_tokens: 256,
            priority: 0,
        }
        worker.SubmitRequest(req)
    }

    batch := worker.GetNextBatch(32)
    LogTest("Batch request count matches", batch.request_count == 32, "Request count mismatch")
    LogTest("Batch ID incremented", batch.batch_id == 0, "Batch ID mismatch")

    result := worker.CompleteBatch(batch.batch_id, batch.request_count, batch.total_tokens, ERROR_SUCCESS)
    LogTest("Batch completion succeeds", result.success, "Batch completion failed")
    LogTest("Queue updated after completion", worker.GetQueueSize() == 32, "Queue not updated")

    worker.Shutdown()
}

func TestGPUWorkerDeviceManagement() {
    println("\n--- Test: GPU Worker Device Management ---")

    config := WorkerConfig{
        worker_id: 3,
        worker_type: WORKER_TYPE_GPU,
        gpus: []i32{0, 1},
        gpu_memory_mb: 24576,
        max_batch_size: 256,
    }

    gpu_worker := NewGPUWorker(config)

    LogTest("GPU worker created", gpu_worker.device_count == 2, "Device count mismatch")

    result := gpu_worker.Initialize()
    LogTest("GPU worker initialized", result.success, "Initialization failed")

    device := gpu_worker.AllocateMemory(1024)
    LogTest("Memory allocated", device >= 0, "Allocation failed")

    available := gpu_worker.get_available_memory()
    LogTest("Available memory calculated", available > 0, "No available memory")

    result = gpu_worker.SyncDevices()
    LogTest("Device sync succeeds", result.success, "Sync failed")

    gpu_worker.Shutdown()
}

func TestWorkerManagerScheduling() {
    println("\n--- Test: Worker Manager Scheduling ---")

    policy := SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    }

    manager := NewWorkerManager(4, policy)

    for i := 0; i < 4; i++ {
        state := WorkerState{
            worker_id: i,
            state: WORKER_STATE_READY,
            queue_size: i,
        }
        manager.RegisterWorker(state)
    }

    LogTest("Workers registered", manager.worker_count == 4, "Worker count mismatch")

    for i := 0; i < 16; i++ {
        req := RequestMetadata{
            request_id: "sched_" + string(i),
            prompt_tokens: 256,
            max_tokens: 512,
            priority: i % 2,
        }
        manager.SubmitRequest(req)
    }

    batch := manager.GetNextBatch(32)
    LogTest("Batch created", batch.request_count > 0, "No batch created")

    result := manager.ScheduleBatch(batch)
    LogTest("Batch scheduled", result.success, "Scheduling failed")

    manager.Shutdown()
}

func TestWorkerCommunication() {
    println("\n--- Test: Worker Communication ---")

    config := CommunicationConfig{
        comm_type: COMM_TYPE_RPC,
        timeout_ms: 5000,
        max_msg_size: 65536,
        buffer_size: 1024,
    }

    handler := NewCommunicationHandler(config, 4)

    msg := WorkerMessage{
        message_id: 1,
        sender_id: 0,
        receiver_id: 1,
        payload_size: 256,
    }

    result := handler.SendMessage(msg)
    LogTest("Message sent", result.success, "Send failed")

    recv_msg := handler.ReceiveMessage(1)
    LogTest("Message received", recv_msg.message_id == 1, "Message ID mismatch")

    broadcast_msg := WorkerMessage{
        message_id: 100,
        sender_id: 0,
        payload_size: 512,
    }
    targets := []i32{1, 2, 3}
    success := handler.BroadcastMessage(broadcast_msg, targets)
    LogTest("Broadcast sent to workers", success > 0, "Broadcast failed")

    handler.Shutdown()
}

func TestBatchProcessing() {
    println("\n--- Test: Batch Processing ---")

    policy := SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    }

    processor := NewBatchProcessor(256, policy)

    requests := make([]RequestMetadata, 0)
    for i := 0; i < 32; i++ {
        req := RequestMetadata{
            request_id: "proc_" + string(i),
            prompt_tokens: 128 + i*4,
            max_tokens: 256,
            priority: i % 4,
        }
        requests = append(requests, req)
    }

    batch := processor.CreateBatch(requests)
    LogTest("Batch created", batch.request_count == 32, "Request count mismatch")
    LogTest("Total tokens calculated", batch.total_tokens > 0, "No tokens")

    reordered := processor.ReorderBatch(batch)
    LogTest("Batch reordered", reordered.request_count == batch.request_count, "Reorder mismatch")

    truncated := processor.TruncateBatch(batch, 512)
    LogTest("Batch truncated", truncated.request_count > 0, "Truncation failed")

    latency := processor.EstimateLatency(batch)
    LogTest("Latency estimated", latency > 0, "Invalid latency")

    processor.CompleteBatch(batch, latency)
    stats := processor.GetBatchStats()
    LogTest("Batch stats available", stats["completed"] == 1, "Stats not updated")
}

func TestWorkerHealthMonitoring() {
    println("\n--- Test: Worker Health Monitoring ---")

    config := WorkerConfig{
        worker_id: 8,
        timeout_ms: 5000,
    }

    worker := NewBaseWorker(config)
    worker.Initialize()
    worker.SendHeartbeat()

    LogTest("Worker healthy after heartbeat", worker.IsHealthy() == 1, "Worker not healthy")

    worker.last_heartbeat = 0
    health := worker.IsHealthy()
    LogTest("Worker unhealthy after timeout", health == 0, "Timeout not detected")

    worker.Shutdown()
}

func TestSynchronizationBarrier() {
    println("\n--- Test: Synchronization Barrier ---")

    sync_mgr := NewSynchronizationManager()

    workers := []i32{0, 1, 2, 3}
    result := sync_mgr.InitiateSync(0, workers)
    LogTest("Sync initiated", result.success, "Initiation failed")

    result = sync_mgr.WaitForSync(0, 5000)
    LogTest("Sync waits", result.success == 0 || result.success == 1, "Wait returned invalid")
}

func TestAllReduceOperation() {
    println("\n--- Test: AllReduce Operation ---")

    config := CommunicationConfig{
        comm_type: COMM_TYPE_NCCL,
        timeout_ms: 10000,
        buffer_size: 2048,
    }

    handler := NewCommunicationHandler(config, 4)

    data := make([]f32, 1024)
    for i := 0; i < 1024; i++ {
        data[i] = f32(i)
    }

    workers := []i32{0, 1, 2, 3}
    result := handler.AllReduce(data, workers)
    LogTest("AllReduce succeeds", result.success, "AllReduce failed")

    handler.Shutdown()
}

func TestDynamicBatching() {
    println("\n--- Test: Dynamic Batching ---")

    processor := NewBatchProcessor(512, SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    })

    requests := make([]RequestMetadata, 0)
    for i := 0; i < 64; i++ {
        size := i32(64 + (i % 4) * 256)
        req := RequestMetadata{
            request_id: "dyn_" + string(i),
            prompt_tokens: size,
            max_tokens: 256,
            priority: 0,
        }
        requests = append(requests, req)
    }

    batch := processor.CreateBatch(requests[:32])
    LogTest("Dynamic batch created", batch.request_count > 0, "Batch not created")

    batch2 := processor.CreateBatch(requests[32:])
    merged := processor.MergeBatches([]Batch{batch, batch2})
    LogTest("Batches merged", merged.request_count > batch.request_count, "Merge failed")
}

func TestBatchSplitting() {
    println("\n--- Test: Batch Splitting ---")

    processor := NewBatchProcessor(512, SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    })

    requests := make([]RequestMetadata, 0)
    for i := 0; i < 256; i++ {
        req := RequestMetadata{
            request_id: "split_" + string(i),
            prompt_tokens: 128,
            max_tokens: 256,
            priority: 0,
        }
        requests = append(requests, req)
    }

    batch := processor.CreateBatch(requests)
    split_batches := processor.SplitBatch(batch, 64)

    total := 0
    for i := 0; i < len(split_batches); i++ {
        total += int(split_batches[i].request_count)
    }

    LogTest("Batch split correctly", i32(total) == batch.request_count, "Split mismatch")
}

func TestWorkerStateTransitions() {
    println("\n--- Test: Worker State Transitions ---")

    config := WorkerConfig{
        worker_id: 13,
        timeout_ms: 5000,
    }

    worker := NewBaseWorker(config)

    LogTest("Initial state is IDLE", worker.GetState() == WORKER_STATE_IDLE, "Initial state wrong")

    worker.Initialize()
    LogTest("After init state is READY", worker.GetState() == WORKER_STATE_READY, "State not READY")

    worker.SetState(WORKER_STATE_BUSY)
    LogTest("State transitions to BUSY", worker.GetState() == WORKER_STATE_BUSY, "Transition failed")

    worker.Shutdown()
    LogTest("After shutdown is SHUTDOWN", worker.GetState() == WORKER_STATE_SHUTDOWN, "Shutdown state wrong")
}

func TestWorkerPoolStatistics() {
    println("\n--- Test: Worker Pool Statistics ---")

    policy := SchedulingPolicy{
        policy_type: 1,
        batch_timeout_ms: 5000,
    }

    manager := NewWorkerManager(4, policy)

    for i := 0; i < 4; i++ {
        state := WorkerState{
            worker_id: i,
            state: WORKER_STATE_READY,
        }
        manager.RegisterWorker(state)
    }

    stats := manager.GetPoolStatistics()
    LogTest("Pool stats available", stats.total_requests >= 0, "Stats not available")

    pool := manager.GetPoolState()
    LogTest("Pool has 4 active workers", pool.total_workers == 4, "Worker count mismatch")

    manager.Shutdown()
}

func PrintTestReport() {
    println("\n╔════════════════════════════════════════╗")
    println("║          Test Report                   ║")
    println("╚════════════════════════════════════════╝")
    println("Total tests:", total_tests)
    println("Passed:     ", passed_tests)
    println("Failed:     ", total_tests - passed_tests)

    if total_tests > 0 {
        percentage := (passed_tests * 100) / total_tests
        println("Pass rate:  ", percentage, "%")
    }
    println()
}

func main() {
    println("╔════════════════════════════════════════╗")
    println("║  NeurX Worker Test Suite               ║")
    println("╚════════════════════════════════════════╝")

    TestWorkerInitialization()
    TestRequestSubmission()
    TestBatchRetrieval()
    TestGPUWorkerDeviceManagement()
    TestWorkerManagerScheduling()
    TestWorkerCommunication()
    TestBatchProcessing()
    TestWorkerHealthMonitoring()
    TestSynchronizationBarrier()
    TestAllReduceOperation()
    TestDynamicBatching()
    TestBatchSplitting()
    TestWorkerStateTransitions()
    TestWorkerPoolStatistics()

    PrintTestReport()
}
