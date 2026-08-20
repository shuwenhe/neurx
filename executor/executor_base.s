import "types.s"

struct BaseExecutor {
    config              ExecutorConfig
    state               i32
    statistics          ExecutorStatistics
    sequences           map[string]SequenceStatus
    sequence_count      i32
    current_iteration   i64
    cache_manager       *KVCacheManager
    initialized         i32
    last_iteration      ExecutionIteration
}

func NewBaseExecutor(config ExecutorConfig) *BaseExecutor {
    executor := &BaseExecutor{
        config: config,
        state: EXECUTOR_STATE_IDLE,
        sequence_count: 0,
        current_iteration: 0,
        initialized: 0,
    }
    return executor
}

func (BaseExecutor* e) Initialize() ExecutionResult {
    if e.initialized == 1 {
        return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
    }

    e.state = EXECUTOR_STATE_INITIALIZING

    e.statistics.total_iterations = 0
    e.statistics.completed_iterations = 0
    e.statistics.failed_iterations = 0
    e.statistics.total_tokens = 0
    e.statistics.avg_latency = 0.0
    e.statistics.cache_hit_rate = 0.0

    e.cache_manager = &KVCacheManager{
        total_size_gb: e.config.cache_size_gb,
        allocated_mb: 0,
        eviction_policy: e.config.eviction_policy,
    }

    e.initialized = 1
    e.state = EXECUTOR_STATE_RUNNING

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (BaseExecutor* e) AddSequence(sequence_id string, priority i32) ExecutionResult {
    if e.state != EXECUTOR_STATE_RUNNING {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_EXECUTION_FAILED,
            error_message: "Executor not running",
        }
    }

    status := SequenceStatus{
        sequence_id: sequence_id,
        phase: PHASE_PREFILL,
        token_pos: 0,
        priority: priority,
        arrival_time: get_current_time(),
    }

    e.sequences[sequence_id] = status
    e.sequence_count++

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (BaseExecutor* e) RemoveSequence(sequence_id string) ExecutionResult {
    if _, exists := e.sequences[sequence_id]; !exists {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_INVALID_SEQUENCE,
            error_message: "Sequence not found",
        }
    }

    e.cache_manager.free_blocks_for_sequence(sequence_id)

    delete(e.sequences, sequence_id)
    e.sequence_count--

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (BaseExecutor* e) ExecuteIteration() ExecutionResult {
    if e.state != EXECUTOR_STATE_RUNNING {
        return ExecutionResult{
            success: 0,
            error_code: ERROR_EXECUTION_FAILED,
            error_message: "Executor not running",
        }
    }

    start_time := get_current_time_ms()
    e.current_iteration++

    prefill_sequences := e.select_prefill_sequences()
    decode_sequences := e.select_decode_sequences()

    prefill_result := e.execute_prefill_phase(prefill_sequences)

    decode_result := e.execute_decode_phase(decode_sequences)

    end_time := get_current_time_ms()
    duration := end_time - start_time

    e.statistics.completed_iterations++
    e.statistics.total_tokens += i64(prefill_result.tokens_processed + decode_result.tokens_processed)
    e.statistics.total_latency += i64(duration)
    e.statistics.avg_latency = f64(e.statistics.total_latency) / f64(e.statistics.completed_iterations)

    e.last_iteration = ExecutionIteration{
        iteration_id: e.current_iteration,
        phase: PHASE_MIXED,
        duration_ms: i32(duration),
        sequence_count: i32(len(prefill_sequences) + len(decode_sequences)),
        total_tokens: prefill_result.tokens_processed + decode_result.tokens_processed,
    }

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
        iteration_id: e.current_iteration,
        tokens_processed: prefill_result.tokens_processed + decode_result.tokens_processed,
        latency_ms: i32(duration),
    }
}

func (BaseExecutor* e) execute_prefill_phase(sequences []string) ExecutionResult {
    if len(sequences) == 0 {
        return ExecutionResult{
            success: 1,
            error_code: ERROR_SUCCESS,
            tokens_processed: 0,
        }
    }

    total_tokens := i32(0)
    for i := 0; i < len(sequences); i++ {
        seq_id := sequences[i]
        status := e.sequences[seq_id]

        tokens_to_process := status.kv_cache_size
        if tokens_to_process > 0 {
            total_tokens += tokens_to_process
        }

        status.phase = PHASE_DECODE
        e.sequences[seq_id] = status
    }

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
        tokens_processed: total_tokens,
        phase: PHASE_PREFILL,
    }
}

func (BaseExecutor* e) execute_decode_phase(sequences []string) ExecutionResult {
    if len(sequences) == 0 {
        return ExecutionResult{
            success: 1,
            error_code: ERROR_SUCCESS,
            tokens_processed: 0,
        }
    }

    tokens_processed := i32(len(sequences))

    for i := 0; i < len(sequences); i++ {
        seq_id := sequences[i]
        status := e.sequences[seq_id]
        status.token_pos++
        e.sequences[seq_id] = status
    }

    return ExecutionResult{
        success: 1,
        error_code: ERROR_SUCCESS,
        tokens_processed: tokens_processed,
        phase: PHASE_DECODE,
    }
}

func (BaseExecutor* e) select_prefill_sequences() []string {
    result := make([]string, 0)
    count := i32(0)

    for seq_id, status := range e.sequences {
        if status.phase == PHASE_PREFILL && count < e.config.max_batch_size {
            result = append(result, seq_id)
            count++
        }
    }

    return result
}

func (BaseExecutor* e) select_decode_sequences() []string {
    result := make([]string, 0)
    count := i32(0)

    for seq_id, status := range e.sequences {
        if status.phase == PHASE_DECODE && count < e.config.max_batch_size {
            result = append(result, seq_id)
            count++
        }
    }

    return result
}

func (BaseExecutor* e) GetSequenceStatus(sequence_id string) SequenceStatus {
    if status, exists := e.sequences[sequence_id]; exists {
        return status
    }
    return SequenceStatus{sequence_id: sequence_id, error_code: ERROR_INVALID_SEQUENCE}
}

func (BaseExecutor* e) GetStatistics() ExecutorStatistics {
    return e.statistics
}

func (BaseExecutor* e) ResetStatistics() {
    e.statistics.total_iterations = 0
    e.statistics.completed_iterations = 0
    e.statistics.failed_iterations = 0
    e.statistics.total_tokens = 0
    e.statistics.avg_latency = 0.0
}

func (BaseExecutor* e) GetMetrics() ExecutorMetrics {
    cache_usage := i32(e.cache_manager.allocated_mb)

    return ExecutorMetrics{
        current_state: e.state,
        active_sequences: e.sequence_count,
        cache_usage_mb: cache_usage,
        throughput_rps: f64(e.statistics.total_tokens) / (f64(e.statistics.total_latency) / 1000.0),
        latency_p50: i32(e.statistics.avg_latency),
    }
}

func (BaseExecutor* e) Drain() ExecutionResult {
    if e.state == EXECUTOR_STATE_SHUTDOWN {
        return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
    }

    e.state = EXECUTOR_STATE_DRAINING

    for e.sequence_count > 0 && e.current_iteration < DEFAULT_MAX_ITERATIONS {
        e.ExecuteIteration()
    }

    e.state = EXECUTOR_STATE_READY

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (BaseExecutor* e) Shutdown() ExecutionResult {
    e.Drain()

    e.state = EXECUTOR_STATE_SHUTDOWN
    e.initialized = 0
    e.sequence_count = 0

    return ExecutionResult{success: 1, error_code: ERROR_SUCCESS}
}

func (KVCacheManager* km) free_blocks_for_sequence(seq_id string) {
    for i := 0; i < km.block_count; i++ {
        if km.blocks[i].sequence_id == seq_id {
            km.blocks[i].is_allocated = 0
            km.allocated_mb -= km.blocks[i].size_bytes / (1024 * 1024)
            km.free_mb += km.blocks[i].size_bytes / (1024 * 1024)
        }
    }
}

func get_current_time() i64 {
    return 0
}

func get_current_time_ms() i64 {
    return 0
}
