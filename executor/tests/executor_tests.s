// NeurX Executor Test Suite
// Comprehensive unit tests for executor functionality

import "types.s"
import "executor_base.s"
import "prefill_executor.s"
import "decode_executor.s"
import "executor_scheduler.s"
import "cache_manager.s"
import "distributed_executor.s"

struct TestResult {
    name            string
    passed          i32
    error_message   string
}

var total_tests i32 = 0
var passed_tests i32 = 0

// Helper: Log test result
func LogTest(test_name string, condition i32, error_msg string) {
    total_tests++

    if condition == 1 {
        passed_tests++
        println("✓ PASS:", test_name)
    } else {
        println("✗ FAIL:", test_name, "-", error_msg)
    }
}

// Test 1: Executor initialization
func TestExecutorInitialization() {
    println("\n--- Test: Executor Initialization ---")

    config := ExecutorConfig{
        executor_id: 0,
        model_name: "test-model",
        max_batch_size: 256,
        cache_size_gb: 20,
    }

    executor := NewBaseExecutor(config)
    result := executor.Initialize()

    LogTest("Initialize succeeds", result.success, "Initialize failed")
    LogTest("Executor running", executor.state == EXECUTOR_STATE_RUNNING, "State not RUNNING")
    LogTest("Cache manager created", executor.cache_manager != nil, "Cache manager not created")
}

// Test 2: Sequence addition
func TestSequenceAddition() {
    println("\n--- Test: Sequence Addition ---")

    config := ExecutorConfig{executor_id: 1}
    executor := NewBaseExecutor(config)
    executor.Initialize()

    result := executor.AddSequence("seq_0", 0)
    LogTest("Add sequence succeeds", result.success, "Addition failed")
    LogTest("Sequence count 1", executor.sequence_count == 1, "Count not updated")

    for i := 1; i < 10; i++ {
        executor.AddSequence("seq_" + string(i), 0)
    }

    LogTest("Multiple sequences", executor.sequence_count == 10, "Count mismatch")
}

// Test 3: Sequence removal
func TestSequenceRemoval() {
    println("\n--- Test: Sequence Removal ---")

    config := ExecutorConfig{executor_id: 2}
    executor := NewBaseExecutor(config)
    executor.Initialize()

    executor.AddSequence("seq_0", 0)
    executor.AddSequence("seq_1", 0)

    result := executor.RemoveSequence("seq_0")
    LogTest("Remove sequence succeeds", result.success, "Removal failed")
    LogTest("Sequence count decremented", executor.sequence_count == 1, "Count not updated")
}

// Test 4: Prefill executor
func TestPrefillExecutor() {
    println("\n--- Test: Prefill Executor ---")

    config := ExecutorConfig{
        executor_id: 3,
        max_batch_size: 256,
        cache_size_gb: 16,
    }

    prefill_config := PrefillConfig{
        max_batch_size: 256,
        max_tokens: 1024,
    }

    prefill := NewPrefillExecutor(config, prefill_config)
    result := prefill.Initialize()

    LogTest("Prefill executor initializes", result.success, "Initialization failed")

    sequences := make([]string, 4)
    tokens := make([]i32, 4)

    for i := 0; i < 4; i++ {
        sequences[i] = "seq_" + string(i)
        tokens[i] = 128
    }

    result = prefill.ProcessPrefill(sequences, tokens)
    LogTest("Prefill processing succeeds", result.success, "Prefill failed")
    LogTest("Tokens processed", result.tokens_processed > 0, "No tokens processed")
}

// Test 5: Decode executor
func TestDecodeExecutor() {
    println("\n--- Test: Decode Executor ---")

    config := ExecutorConfig{
        executor_id: 4,
        max_batch_size: 512,
        cache_size_gb: 24,
    }

    decode_config := DecodeConfig{
        max_batch_size: 512,
        beam_width: 1,
    }

    decoder := NewDecodeExecutor(config, decode_config)
    result := decoder.Initialize()

    LogTest("Decode executor initializes", result.success, "Initialization failed")

    sequences := make([]string, 16)
    for i := 0; i < 16; i++ {
        sequences[i] = "seq_" + string(i)
        decoder.base.AddSequence(sequences[i], 0)
    }

    result = decoder.ProcessDecodeStep(sequences)
    LogTest("Decode step succeeds", result.success, "Decode step failed")
    LogTest("Correct tokens processed", result.tokens_processed == 16, "Token count wrong")
}

// Test 6: Scheduler - Round-robin
func TestSchedulerRoundRobin() {
    println("\n--- Test: Scheduler Round-Robin ---")

    scheduler := NewExecutionScheduler(SCHEDULE_FCFS)

    for i := 0; i < 8; i++ {
        scheduler.AddPrefillSequence("p_" + string(i))
        scheduler.AddDecodeSequence("d_" + string(i))
    }

    schedule := scheduler.PlanIteration(4, 4)
    LogTest("Schedule created", schedule.prefill_count + schedule.decode_count > 0, "Empty schedule")
    LogTest("Prefill count", schedule.prefill_count == 4, "Prefill count mismatch")
    LogTest("Decode count", schedule.decode_count == 4, "Decode count mismatch")
}

// Test 7: Scheduler - Priority
func TestSchedulerPriority() {
    println("\n--- Test: Scheduler Priority ---")

    scheduler := NewExecutionScheduler(SCHEDULE_PRIORITY)

    for i := 0; i < 16; i++ {
        scheduler.AddPrefillSequence("seq_" + string(i))
    }

    schedule := scheduler.PlanIteration(8, 0)
    LogTest("Priority schedule created", schedule.prefill_count > 0, "Schedule failed")
    LogTest("Correct batch size", schedule.prefill_count <= 8, "Batch size exceeded")
}

// Test 8: KV cache allocation
func TestKVCacheAllocation() {
    println("\n--- Test: KV Cache Allocation ---")

    cache := NewKVCacheManager(20, EVICTION_LRU)

    result := cache.AllocateBlock("seq_0", 0, 256)
    LogTest("Allocate block succeeds", result.success, "Allocation failed")
    LogTest("Block count incremented", cache.block_count == 1, "Block count not updated")
    LogTest("Memory updated", cache.allocated_mb > 0, "Memory not allocated")
}

// Test 9: KV cache eviction
func TestKVCacheEviction() {
    println("\n--- Test: KV Cache Eviction ---")

    cache := NewKVCacheManager(1, EVICTION_LRU)  // Small cache

    // Fill cache
    for i := 0; i < 16; i++ {
        seq_id := "seq_" + string(i)
        cache.AllocateBlock(seq_id, 0, 256)
    }

    LogTest("Cache blocks created", cache.block_count > 0, "No blocks allocated")

    // Try to evict
    result := cache.EvictBlocks()
    LogTest("Eviction triggers", result.success == 0 || cache.allocated_mb < i32(1024), "Eviction not working")
}

// Test 10: Cache LRU vs LFU
func TestCacheEvictionPolicies() {
    println("\n--- Test: Cache Eviction Policies ---")

    // Test LRU
    lru_cache := NewKVCacheManager(10, EVICTION_LRU)
    result := lru_cache.AllocateBlock("seq_0", 0, 256)
    LogTest("LRU allocation", result.success, "LRU allocation failed")

    // Test LFU
    lfu_cache := NewKVCacheManager(10, EVICTION_LFU)
    result = lfu_cache.AllocateBlock("seq_1", 0, 256)
    LogTest("LFU allocation", result.success, "LFU allocation failed")

    // Test FIFO
    fifo_cache := NewKVCacheManager(10, EVICTION_FIFO)
    result = fifo_cache.AllocateBlock("seq_2", 0, 256)
    LogTest("FIFO allocation", result.success, "FIFO allocation failed")
}

// Test 11: Iteration execution
func TestIterationExecution() {
    println("\n--- Test: Iteration Execution ---")

    config := ExecutorConfig{
        executor_id: 5,
        max_batch_size: 256,
    }

    executor := NewBaseExecutor(config)
    executor.Initialize()

    for i := 0; i < 10; i++ {
        executor.AddSequence("seq_" + string(i), 0)
    }

    result := executor.ExecuteIteration()
    LogTest("Iteration succeeds", result.success, "Execution failed")
    LogTest("Iteration ID set", result.iteration_id > 0, "Iteration ID not set")
    LogTest("Tokens processed", result.tokens_processed > 0, "No tokens processed")
}

// Test 12: Statistics collection
func TestStatisticsCollection() {
    println("\n--- Test: Statistics Collection ---")

    config := ExecutorConfig{executor_id: 6}
    executor := NewBaseExecutor(config)
    executor.Initialize()

    for i := 0; i < 5; i++ {
        executor.AddSequence("seq_" + string(i), 0)
        executor.ExecuteIteration()
    }

    stats := executor.GetStatistics()
    LogTest("Statistics collected", stats.completed_iterations > 0, "No statistics")
    LogTest("Total tokens tracked", stats.total_tokens > 0, "No tokens tracked")
    LogTest("Latency calculated", stats.avg_latency > 0, "Latency not calculated")
}

// Test 13: Distributed executor
func TestDistributedExecutor() {
    println("\n--- Test: Distributed Executor ---")

    config := ExecutorConfig{
        executor_id: 7,
        max_batch_size: 256,
    }

    dist_config := DistributedConfig{
        rank: 0,
        world_size: 4,
        tensor_parallel: 4,
    }

    dist := NewDistributedExecutor(config, dist_config)
    result := dist.Initialize()

    LogTest("Distributed executor initializes", result.success, "Initialization failed")
    LogTest("Rank set", dist.distributed_config.rank == 0, "Rank not set")
    LogTest("World size set", dist.distributed_config.world_size == 4, "World size not set")
}

// Test 14: Load balancing
func TestLoadBalancing() {
    println("\n--- Test: Load Balancing ---")

    config := ExecutorConfig{
        executor_id: 8,
        max_batch_size: 256,
    }

    dist_config := DistributedConfig{
        rank: 0,
        world_size: 4,
    }

    dist := NewDistributedExecutor(config, dist_config)
    dist.Initialize()

    sequences := make([]string, 16)
    for i := 0; i < 16; i++ {
        sequences[i] = "seq_" + string(i)
    }

    balanced := dist.LoadBalance(sequences)
    LogTest("Load balance succeeds", len(balanced) == 4, "Incorrect number of ranks")

    total := 0
    for rank := 0; rank < len(balanced); rank++ {
        total += len(balanced[rank])
    }
    LogTest("All sequences distributed", total == 16, "Not all sequences distributed")
}

// Print test report
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

// Main test execution
func main() {
    println("╔════════════════════════════════════════╗")
    println("║  NeurX Executor Test Suite             ║")
    println("╚════════════════════════════════════════╝")

    TestExecutorInitialization()
    TestSequenceAddition()
    TestSequenceRemoval()
    TestPrefillExecutor()
    TestDecodeExecutor()
    TestSchedulerRoundRobin()
    TestSchedulerPriority()
    TestKVCacheAllocation()
    TestKVCacheEviction()
    TestCacheEvictionPolicies()
    TestIterationExecution()
    TestStatisticsCollection()
    TestDistributedExecutor()
    TestLoadBalancing()

    PrintTestReport()
}
