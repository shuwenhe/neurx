import "types.s"
import "executor_base.s"
import "prefill_executor.s"
import "decode_executor.s"
import "executor_scheduler.s"
import "cache_manager.s"
import "distributed_executor.s"
func AdaptiveBatchingExample() {
    println("=== Adaptive Batching Example ===")
    config := ExecutorConfig{
        executor_id: 0,
        model_name: "llama-7b",
        max_batch_size: 256,
        cache_size_gb: 20,
        scheduling_policy: SCHEDULE_DYNAMIC,
    }
    executor := NewBaseExecutor(config)
    executor.Initialize()
    scheduler := NewExecutionScheduler(SCHEDULE_DYNAMIC)
    target_latency := i32(50)
    current_batch_size := i32(128)
    for iteration := 0; iteration < 5; iteration++ {
        println("\nIteration", iteration)
        println("Target batch size:", current_batch_size)
        for i := 0; i < int(current_batch_size); i++ {
            scheduler.AddDecodeSequence("seq_" + string(i))
        }
        schedule := scheduler.PlanIteration(current_batch_size/2, current_batch_size)
        estimated_latency := scheduler.EstimateLatency(schedule)
        println("Estimated latency:", estimated_latency, "ms")
        if estimated_latency > target_latency {
            current_batch_size = (current_batch_size * 7) / 8
            println("Reducing batch size to", current_batch_size)
        } else if estimated_latency < target_latency/2 {
            current_batch_size = (current_batch_size * 9) / 8
            println("Increasing batch size to", current_batch_size)
        }
    }
    executor.Shutdown()
    println("\nAdaptive batching complete\n")
}
func CacheEvictionPoliciesExample() {
    println("=== Cache Eviction Policies Example ===")
    policies := []i32{EVICTION_LRU, EVICTION_LFU, EVICTION_FIFO, EVICTION_ADAPTIVE}
    policy_names := string[]{"LRU", "LFU", "FIFO", "ADAPTIVE"}
    for idx := 0; idx < len(policies); idx++ {
        println("\n--- Policy:", policy_names[idx], "---")
        cache := NewKVCacheManager(10, policies[idx])
        for i := 0; i < 16; i++ {
            seq_id := "seq_" + string(i)
            result := cache.AllocateBlock(seq_id, 0, 256)
            if result.success == 0 {
                println("Eviction triggered for block", i)
            }
        }
        println("Final utilization:", cache.GetCacheUtilization(), "%")
        stats := cache.GetBlockStats()
        println("Allocated blocks:", stats["allocated_blocks"])
        println("Free blocks:", stats["free_blocks"])
        cache.Shutdown()
    }
    println()
}
func PrefillDecodeOptimizationExample() {
    println("=== Prefill-Decode Optimization Example ===")
    config := ExecutorConfig{
        executor_id: 0,
        max_batch_size: 256,
        cache_size_gb: 24,
    }
    executor := NewBaseExecutor(config)
    executor.Initialize()
    scheduler := NewExecutionScheduler(SCHEDULE_DYNAMIC)
    println("Phase 1: Prefill intensive")
    for i := 0; i < 256; i++ {
        scheduler.AddPrefillSequence("prompt_" + string(i))
    }
    for iter := 0; iter < 3; iter++ {
        schedule := scheduler.PlanIteration(256, 64)
        println("Iteration", iter, "- Prefill:", schedule.prefill_count, "Decode:", schedule.decode_count)
    }
    println("\nPhase 2: Decode intensive")
    for i := 256; i < 512; i++ {
        scheduler.AddDecodeSequence("gen_" + string(i))
    }
    for iter := 0; iter < 3; iter++ {
        schedule := scheduler.PlanIteration(64, 256)
        println("Iteration", iter, "- Prefill:", schedule.prefill_count, "Decode:", schedule.decode_count)
    }
    executor.Shutdown()
    println("\nOptimization example complete\n")
}
func PromptCachingExample() {
    println("=== Prompt Caching Example ===")
    cache_manager := NewKVCacheManager(16, EVICTION_LRU)
    prompts := string[]{
        "You are a helpful assistant.",
        "Translate to Spanish:",
        "Summarize the following:",
    }
    println("Caching common prompts:")
    for i := 0; i < len(prompts); i++ {
        prefix_hash := "hash_" + string(i)
        result := cache_manager.PrefixCache(prefix_hash, 32)
        if result.success == 1 {
            println("Cached:", prompts[i])
        }
    }
    println("\nReusing cached prefixes:")
    for i := 0; i < 5; i++ {
        prefix_idx := i % len(prompts)
        prefix_hash := "hash_" + string(prefix_idx)
        result := cache_manager.GetPrefixCache(prefix_hash)
        if result.success == 1 {
            println("Reused prefix for prompt", prefix_idx)
        }
    }
    cache_manager.Shutdown()
    println("\nPrompt caching example complete\n")
}
func TensorParallelismExample() {
    println("=== Tensor Parallelism Example ===")
    config := ExecutorConfig{
        executor_id: 0,
        model_name: "llama-70b",
        max_batch_size: 256,
        cache_size_gb: 24,
    }
    dist_config := DistributedConfig{
        rank: 0,
        world_size: 8,
        tensor_parallel: 8,
        pipeline_parallel: 1,
    }
    dist_exec := NewDistributedExecutor(config, dist_config)
    dist_exec.Initialize()
    println("Setting up tensor parallelism:")
    println("Total GPUs:", dist_config.world_size)
    println("Tensor parallel degree:", dist_config.tensor_parallel)
    input_data := make([]f32, 4096)
    result := dist_exec.TensorParallelForward(input_data)
    if result.success == 1 {
        println("Tensor parallel forward completed")
    }
    println("Each GPU processes 1/8 of hidden dimension")
    println("All-reduce combines results across ranks")
    dist_exec.Shutdown()
    println("\nTensor parallelism example complete\n")
}
func PipelineParallelismExample() {
    println("=== Pipeline Parallelism Example ===")
    config := ExecutorConfig{
        executor_id: 0,
        model_name: "llama-70b",
        max_batch_size: 128,
        cache_size_gb: 12,
    }
    dist_config := DistributedConfig{
        rank: 0,
        world_size: 4,
        tensor_parallel: 1,
        pipeline_parallel: 4,
    }
    dist_exec := NewDistributedExecutor(config, dist_config)
    dist_exec.Initialize()
    println("Pipeline parallelism setup:")
    println("Number of stages:", dist_config.pipeline_parallel)
    println("Each stage processes 24 layers")
    layers := make(string[], 96)
    for i := 0; i < 96; i++ {
        layers[i] = "layer_" + string(i)
    }
    result := dist_exec.PipelineParallelForward(layers)
    if result.success == 1 {
        println("Pipeline parallel forward completed")
    }
    println("Micro-batching enabled for better utilization")
    dist_exec.Shutdown()
    println("\nPipeline parallelism example complete\n")
}
func MultiLevelSchedulingExample() {
    println("=== Multi-Level Scheduling Example ===")
    scheduler := NewExecutionScheduler(SCHEDULE_PRIORITY)
    for i := 0; i < 8; i++ {
        scheduler.AddPrefillSequence("high_priority_" + string(i))
    }
    for i := 0; i < 16; i++ {
        scheduler.AddPrefillSequence("normal_" + string(i))
    }
    for i := 0; i < 32; i++ {
        scheduler.AddDecodeSequence("low_priority_" + string(i))
    }
    println("Total sequences:", scheduler.GetPendingSequenceCount())
    for iteration := 0; iteration < 3; iteration++ {
        schedule := scheduler.PlanIteration(128, 128)
        println("\nIteration", iteration)
        println("Scheduled prefill:", schedule.prefill_count)
        println("Scheduled decode:", schedule.decode_count)
    }
    println("\nMulti-level scheduling example complete\n")
}
func CacheSwappingExample() {
    println("=== Cache Swapping Example ===")
    cache_manager := NewKVCacheManager(8, EVICTION_LRU)
    println("Initial cache: 8GB GPU memory")
    for i := 0; i < 32; i++ {
        seq_id := "seq_" + string(i)
        cache_manager.AllocateBlock(seq_id, 0, 256)
    }
    println("Cache utilization:", cache_manager.GetCacheUtilization(), "%")
    println("\nSwapping sequences to host:")
    for i := 0; i < 8; i++ {
        seq_id := "seq_" + string(i)
        result := cache_manager.SwapToHost(seq_id, 256)
        if result.success == 1 {
            println("Swapped", seq_id, "to host memory")
        }
    }
    println("New utilization:", cache_manager.GetCacheUtilization(), "%")
    println("\nSwapping sequences back to GPU:")
    result := cache_manager.SwapToDevice("seq_0", 256)
    if result.success == 1 {
        println("Swapped seq_0 back to GPU")
    }
    cache_manager.Shutdown()
    println("\nCache swapping example complete\n")
}
func main() {
    println("╔════════════════════════════════════════════╗")
    println("║  NeurX Executor Advanced Examples          ║")
    println("╚════════════════════════════════════════════╝\n")
    AdaptiveBatchingExample()
    CacheEvictionPoliciesExample()
    PrefillDecodeOptimizationExample()
    PromptCachingExample()
    TensorParallelismExample()
    PipelineParallelismExample()
    MultiLevelSchedulingExample()
    CacheSwappingExample()
    println("╔════════════════════════════════════════════╗")
    println("║  All advanced examples completed           ║")
    println("╚════════════════════════════════════════════╝")
}
