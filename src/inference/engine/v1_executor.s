package v1

type execution_mode string

const (
    mode_single         execution_mode = "single"
    mode_batch          execution_mode = "batch"
    mode_continuous     execution_mode = "continuous"
)

struct executor_config {
    execution_mode mode
    int32 batch_size
    int32 max_batch_size
    int32 prefill_batch_size
    int32 decode_batch_size
    bool separate_prefill_decode
}

struct v1_executor {
    executor_config config
    v1_core* core

    int32 total_executed
    int32 total_batches

    vec[v1_request*] current_batch
}

func create_v1_executor(v1_core* core_instance) v1_executor* {
    return *v1_executor{
        config: executor_config{
            mode: mode_batch,
            batch_size: 32,
            max_batch_size: 128,
            prefill_batch_size: 64,
            decode_batch_size: 64,
            separate_prefill_decode: true,
        },
        core: core_instance,
        total_executed: 0,
        total_batches: 0,
        current_batch: make(vec[v1_request*]),
    }
}

func (v1_executor* exec) prepare_batch(vec[v1_request*] requests) bool {
    if len(requests) == 0 {
        return false
    }

    exec.current_batch = make(vec[v1_request*])

    batch_size := exec.config.batch_size
    if len(requests) < batch_size {
        batch_size = len(requests)
    }

    for i := 0; i < batch_size; i = i + 1 {
        exec.current_batch = append(exec.current_batch, requests[i])
    }

    return true
}

func (v1_executor* exec) execute_prefill() bool {
    if len(exec.current_batch) == 0 {
        return false
    }

    batch_input_ids := make(vec[vec[int32]])
    batch_logits := make(vec[vec[float32]])

    for i := 0; i < len(exec.current_batch); i = i + 1 {
        req := exec.current_batch[i]
        batch_input_ids = append(batch_input_ids, req.prompt_token_ids)

        logits := make(vec[float32])
        for j := 0; j < 100; j = j + 1 {
            logits = append(logits, 0.5)
        }
        batch_logits = append(batch_logits, logits)
    }

    success := exec.core.batch_prefill(batch_input_ids, batch_logits)
    return success
}

func (v1_executor* exec) execute_decode() bool {
    if len(exec.current_batch) == 0 {
        return false
    }

    batch_logits := make(vec[vec[float32]])

    for i := 0; i < len(exec.current_batch); i = i + 1 {
        logits := make(vec[float32])
        for j := 0; j < 100; j = j + 1 {
            logits = append(logits, 0.5)
        }
        batch_logits = append(batch_logits, logits)
    }

    tokens := exec.core.batch_decode(batch_logits, nil)

    for i := 0; i < len(exec.current_batch) && i < len(tokens); i = i + 1 {
        req := exec.current_batch[i]
        req.add_output_token(tokens[i])
    }

    return true
}

func (v1_executor* exec) execute() bool {
    if len(exec.current_batch) == 0 {
        return false
    }

    success := exec.execute_prefill()
    if !success {
        return false
    }

    success = exec.execute_decode()
    if !success {
        return false
    }

    exec.total_executed = exec.total_executed + len(exec.current_batch)
    exec.total_batches = exec.total_batches + 1

    return true
}

func (v1_executor* exec) get_executor_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["mode"] = exec.config.mode
    stats["batch_size"] = exec.config.batch_size
    stats["total_executed"] = exec.total_executed
    stats["total_batches"] = exec.total_batches
    stats["current_batch_size"] = len(exec.current_batch)
    return stats
}

func (v1_executor* exec) set_batch_size(int32 batch_size) {
    if batch_size > 0 && batch_size <= exec.config.max_batch_size {
        exec.config.batch_size = batch_size
    }
}
