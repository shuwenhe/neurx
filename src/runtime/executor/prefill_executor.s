import "types.s"
import "executor_base.s"

struct PrefillExecutor {
    base                BaseExecutor
    prefill_config      PrefillConfig
    input_sequences     []string
    batch_size          i32
    max_tokens          i32
    current_batch       []string
    batch_count         i32
}

func NewPrefillExecutor(config ExecutorConfig, prefill_config PrefillConfig) *PrefillExecutor {
    executor := &PrefillExecutor{
        base: *NewBaseExecutor(config),
        prefill_config: prefill_config,
        batch_size: 0,
        max_tokens: prefill_config.max_tokens,
        batch_count: 0,
    }
    return executor
}

func (PrefillExecutor* pe) Initialize() ExecutionResult {
    return pe.base.Initialize()
}

func (PrefillExecutor* pe) ProcessPrefill(sequences []string, prompt_tokens []i32) ExecutionResult {
    if pe.base.state != EXECUTOR_STATE_RUNNING {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_EXECUTION_FAILED,
            error_message: "Executor not running",
        }
    }

    start_time := get_time_ms()

    if len(sequences) > int(pe.prefill_config.max_batch_size) {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_SCHEDULING_FAILED,
            error_message: "Batch exceeds max size",
        }
    }

    total_tokens := i32(0)
    for i := 0; i < len(prompt_tokens); i++ {
        total_tokens += prompt_tokens[i]
    }

    if total_tokens > pe.prefill_config.max_tokens {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_INVALID_SEQUENCE,
            error_message: "Total tokens exceed limit",
        }
    }

    for i := 0; i < len(sequences); i++ {
        seq_id := sequences[i]
        tokens := prompt_tokens[i]

        result := pe.allocate_kv_cache(seq_id, tokens)
        if result.success == 0 {
            return result
        }
    }

    result := pe.compute_attention(sequences, prompt_tokens)

    result = pe.compute_logits(sequences)

    end_time := get_time_ms()
    latency := end_time - start_time

    pe.batch_count++

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
        iteration_id: pe.base.current_iteration,
        tokens_processed: total_tokens,
        latency_ms: i32(latency),
        throughput: f64(total_tokens) / (f64(latency) / 1000.0),
    }
}

func (PrefillExecutor* pe) allocate_kv_cache(sequence_id string, num_tokens i32) ExecutionResult {

    memory_needed := num_tokens * 100

    cache_block := KVCacheBlock{
        block_id: pe.base.cache_manager.block_count,
        sequence_id: sequence_id,
        token_start: 0,
        token_end: num_tokens,
        size_bytes: memory_needed,
        is_allocated: 1,
        last_access: get_time_ms(),
        access_count: 1,
    }

    pe.base.cache_manager.blocks = append(pe.base.cache_manager.blocks, cache_block)
    pe.base.cache_manager.block_count++
    pe.base.cache_manager.allocated_mb += memory_needed / (1024 * 1024)

    if pe.base.cache_manager.allocated_mb > i32(pe.base.cache_manager.total_size_gb * 1024) {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_INSUFFICIENT_CACHE,
            error_message: "Insufficient cache memory",
        }
    }

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (PrefillExecutor* pe) compute_attention(sequences []string, token_counts []i32) ExecutionResult {

    total_ops := i32(0)
    for i := 0; i < len(token_counts); i++ {

        total_ops += token_counts[i] * token_counts[i]
    }

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
    }
}

func (PrefillExecutor* pe) compute_logits(sequences []string) ExecutionResult {

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
    }
}

func (PrefillExecutor* pe) CreateBatch(num_sequences i32) []string {
    batch := make([]string, 0)

    for seq_id, _ := range pe.base.sequences {
        if i32(len(batch)) < num_sequences {
            batch = append(batch, seq_id)
        }
    }

    return batch
}

func (PrefillExecutor* pe) EstimatePrefillTime(total_tokens i32) i32 {

    return (total_tokens * 10) / 1000
}

func (PrefillExecutor* pe) Shutdown() ExecutionResult {
    return pe.base.Shutdown()
}

func get_time_ms() i64 {
    return 0
}
