// NeurX Executor Basic Examples
// Demonstrates fundamental executor operations

import "types.s"
import "executor_base.s"
import "prefill_executor.s"
import "decode_executor.s"
import "executor_scheduler.s"
import "cache_manager.s"
import "distributed_executor.s"

// Example 1: Basic executor lifecycle
func BasicExecutorExample() {
    println("=== Basic Executor Example ===")

    // Create executor configuration
    config := ExecutorConfig{
        executor_id: 0,
        model_name: "llama-7b",
        device_id: 0,
        max_batch_size: 256,
        max_seq_length: 8192,
        cache_size_gb: 20,
        eviction_policy: EVICTION_LRU,
        scheduling_policy: SCHEDULE_DYNAMIC,
        timeout_ms: DEFAULT_ITERATION_TIMEOUT,
    }

    // Create and initialize executor
    executor := NewBaseExecutor(config)
    result := executor.Initialize()
    
    if result.success == 1 {
        println("Executor initialized successfully")
    }

    // Add sequences
    for i := 0; i < 10; i++ {
        sequence_id := "seq_" + string(i)
        executor.AddSequence(sequence_id, i % 3)
    }

    println("Active sequences:", executor.sequence_count)

    // Execute iterations
    for iter := 0; iter < 3; iter++ {
        result := executor.ExecuteIteration()
        if result.success == 1 {
            println("Iteration", iter, "completed - tokens:", result.tokens_processed)
        }
    }

    // Get statistics
    stats := executor.GetStatistics()
    println("Total iterations:", stats.completed_iterations)
    println("Total tokens:", stats.total_tokens)
    println("Avg latency:", stats.avg_latency, "ms")

    // Shutdown
    executor.Shutdown()
    println("Executor shutdown\n")
}

// Example 2: Prefill executor
func PrefillExecutorExample() {
    println("=== Prefill Executor Example ===")

    config := ExecutorConfig{
        executor_id: 1,
        model_name: "bert-base",
        max_batch_size: 256,
        cache_size_gb: 16,
    }

    prefill_config := PrefillConfig{
        max_batch_size: 256,
        max_tokens: 1024,
        enable_paging: 1,
    }

    prefill := NewPrefillExecutor(config, prefill_config)
    prefill.Initialize()

    // Prepare sequences
    sequences := make([]string, 8)
    prompt_tokens := make([]i32, 8)
    
    for i := 0; i < 8; i++ {
        sequences[i] = "prompt_" + string(i)
        prompt_tokens[i] = 128 + i*16  // 128, 144, 160, ...
    }

    // Process prefill
    result := prefill.ProcessPrefill(sequences, prompt_tokens)
    
    if result.success == 1 {
        println("Prefill phase completed")
        println("Tokens processed:", result.tokens_processed)
        println("Throughput:", result.throughput, "tokens/sec")
    }

    prefill.Shutdown()
    println("Prefill executor shutdown\n")
}

// Example 3: Decode executor
func DecodeExecutorExample() {
    println("=== Decode Executor Example ===")

    config := ExecutorConfig{
        executor_id: 2,
        model_name: "gpt2",
        max_batch_size: 512,
        cache_size_gb: 24,
    }

    decode_config := DecodeConfig{
        max_batch_size: 512,
        beam_width: 1,
        enable_batching: 1,
    }

    decoder := NewDecodeExecutor(config, decode_config)
    decoder.Initialize()

    // Prepare sequences
    sequences := make([]string, 32)
    for i := 0; i < 32; i++ {
        sequences[i] = "generation_" + string(i)
        decoder.base.AddSequence(sequences[i], 0)
    }

    // Execute decode steps
    for step := 0; step < 5; step++ {
        result := decoder.ProcessDecodeStep(sequences)
        
        if result.success == 1 {
            println("Decode step", step, "completed")
            println("Latency:", result.latency_ms, "ms")
        }
    }

    decoder.Shutdown()
    println("Decode executor shutdown\n")
}

// Example 4: Execution scheduler
func ExecutionSchedulerExample() {
    println("=== Execution Scheduler Example ===")

    scheduler := NewExecutionScheduler(SCHEDULE_DYNAMIC)

    // Add sequences
    for i := 0; i < 16; i++ {
        if i % 2 == 0 {
            scheduler.AddPrefillSequence("prefill_" + string(i))
        } else {
            scheduler.AddDecodeSequence("decode_" + string(i))
        }
    }

    println("Pending sequences:", scheduler.GetPendingSequenceCount())

    // Plan iterations
    for iter := 0; iter < 3; iter++ {
        schedule := scheduler.PlanIteration(128, 256)
        
        println("Iteration", iter)
        println("  Prefill batch:", schedule.prefill_count)
        println("  Decode batch:", schedule.decode_count)
        println("  Estimated latency:", scheduler.EstimateLatency(schedule), "ms")
    }

    stats := scheduler.GetScheduleStatistics()
    println("Total schedules:", stats["schedules_created"])
    println("Total scheduled sequences:", stats["total_scheduled_seqs"])
    println()
}

// Example 5: KV cache management
func KVCacheExample() {
    println("=== KV Cache Management Example ===")

    cache_manager := NewKVCacheManager(20, EVICTION_LRU)

    println("Total cache:", cache_manager.total_size_gb, "GB")

    // Allocate cache blocks
    for i := 0; i < 4; i++ {
        seq_id := "seq_" + string(i)
        result := cache_manager.AllocateBlock(seq_id, 0, 256)
        
        if result.success == 1 {
            println("Allocated cache block for", seq_id)
        }
    }

    println("Allocated:", cache_manager.allocated_mb, "MB")
    println("Free:", cache_manager.free_mb, "MB")
    println("Utilization:", cache_manager.GetCacheUtilization(), "%")

    // Free sequence
    cache_manager.FreeSequenceBlocks("seq_0")
    println("After freeing seq_0:")
    println("Allocated:", cache_manager.allocated_mb, "MB")

    stats := cache_manager.GetBlockStats()
    println("Total blocks:", stats["total_blocks"])
    println("Allocated blocks:", stats["allocated_blocks"])
    println()
}

// Example 6: Prefill + Decode iteration
func PrefillDecodeIterationExample() {
    println("=== Prefill + Decode Iteration Example ===")

    config := ExecutorConfig{
        executor_id: 3,
        model_name: "llama-13b",
        max_batch_size: 256,
        cache_size_gb: 30,
        scheduling_policy: SCHEDULE_DYNAMIC,
    }

    executor := NewBaseExecutor(config)
    executor.Initialize()

    scheduler := NewExecutionScheduler(SCHEDULE_DYNAMIC)

    // Iteration 1: Mostly prefill
    for i := 0; i < 16; i++ {
        scheduler.AddPrefillSequence("prompt_" + string(i))
        executor.AddSequence("prompt_" + string(i), 0)
    }

    schedule1 := scheduler.PlanIteration(256, 128)
    result1 := executor.ExecuteIteration()

    println("Iteration 1: Prefill focus")
    println("  Prefill sequences:", schedule1.prefill_count)
    println("  Tokens processed:", result1.tokens_processed)

    // Iteration 2: Mixed
    for i := 16; i < 24; i++ {
        scheduler.AddPrefillSequence("prompt_" + string(i))
    }

    schedule2 := scheduler.PlanIteration(128, 128)
    result2 := executor.ExecuteIteration()

    println("Iteration 2: Mixed")
    println("  Prefill sequences:", schedule2.prefill_count)
    println("  Decode sequences:", schedule2.decode_count)

    executor.Shutdown()
    println("Prefill-Decode iteration example complete\n")
}

// Example 7: Distributed executor (multi-GPU)
func DistributedExecutorExample() {
    println("=== Distributed Executor Example ===")

    config := ExecutorConfig{
        executor_id: 0,
        model_name: "llama-65b",
        max_batch_size: 256,
        cache_size_gb: 24,
    }

    dist_config := DistributedConfig{
        rank: 0,
        world_size: 4,
        tensor_parallel: 4,
        pipeline_parallel: 1,
        sync_timeout_ms: 10000,
    }

    dist_executor := NewDistributedExecutor(config, dist_config)
    result := dist_executor.Initialize()

    if result.success == 1 {
        println("Distributed executor initialized")
        println("Rank:", dist_executor.distributed_config.rank)
        println("World size:", dist_executor.distributed_config.world_size)
        println("Tensor parallel:", dist_executor.tensor_parallel_size)
    }

    // Add sequences
    for i := 0; i < 16; i++ {
        dist_executor.base.AddSequence("seq_" + string(i), 0)
    }

    // Load balance across ranks
    sequences := make([]string, 16)
    for i := 0; i < 16; i++ {
        sequences[i] = "seq_" + string(i)
    }

    balanced := dist_executor.LoadBalance(sequences)
    println("Load balanced across ranks:")
    for rank := 0; rank < len(balanced); rank++ {
        println("  Rank", rank, ":", len(balanced[rank]), "sequences")
    }

    // Execute distributed iteration
    result = dist_executor.ExecuteDistributedIteration()
    if result.success == 1 {
        println("Distributed iteration completed")
        println("Latency:", result.latency_ms, "ms")
    }

    dist_executor.Shutdown()
    println("Distributed executor shutdown\n")
}

// Main execution
func main() {
    println("╔════════════════════════════════════════╗")
    println("║  NeurX Executor Basic Examples         ║")
    println("╚════════════════════════════════════════╝\n")

    BasicExecutorExample()
    PrefillExecutorExample()
    DecodeExecutorExample()
    ExecutionSchedulerExample()
    KVCacheExample()
    PrefillDecodeIterationExample()
    DistributedExecutorExample()

    println("╔════════════════════════════════════════╗")
    println("║  All examples completed                ║")
    println("╚════════════════════════════════════════╝")
}
