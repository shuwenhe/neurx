package v1

type pipeline_stage string

const (
    stage_idle          pipeline_stage = "idle"
    stage_prefill       pipeline_stage = "prefill"
    stage_decode        pipeline_stage = "decode"
    stage_streaming     pipeline_stage = "streaming"
    stage_completed     pipeline_stage = "completed"
)

struct pipeline_config {
    bool separate_prefill_decode
    int32 prefill_batch_size
    int32 decode_batch_size
    int32 max_batch_tokens
    int32 max_seq_length
}

struct prefill_batch {
    vec[active_request*] requests
    int32 batch_id
    int32 total_tokens
    int64 created_at
}

struct decode_batch {
    vec[active_request*] requests
    int32 batch_id
    int32 num_decode_steps
    int64 created_at
}

struct prefill_decode_pipeline {
    pipeline_config config
    pipeline_stage current_stage

    prefill_batch* current_prefill_batch
    decode_batch* current_decode_batch

    int32 total_prefill_batches_executed
    int32 total_decode_batches_executed
    int32 total_tokens_processed

    vec[active_request*] pending_prefill
    vec[active_request*] in_flight_decode
    vec[active_request*] completed_requests
}

func create_pipeline(pipeline_config cfg) prefill_decode_pipeline* {
    return &prefill_decode_pipeline{
        config: cfg,
        current_stage: stage_idle,
        current_prefill_batch: nil,
        current_decode_batch: nil,
        total_prefill_batches_executed: 0,
        total_decode_batches_executed: 0,
        total_tokens_processed: 0,
        pending_prefill: make(vec[active_request*]),
        in_flight_decode: make(vec[active_request*]),
        completed_requests: make(vec[active_request*]),
    }
}

func (prefill_decode_pipeline* pd) submit_request(active_request* req) bool {
    req.state = req_state_submitted
    pd.pending_prefill = append(pd.pending_prefill, req)
    return true
}

func (prefill_decode_pipeline* pd) prepare_prefill_batch() prefill_batch* {
    if len(pd.pending_prefill) == 0 {
        return nil
    }

    batch_size := pd.config.prefill_batch_size
    if batch_size > len(pd.pending_prefill) {
        batch_size = len(pd.pending_prefill)
    }

    total_tokens := 0
    batch := make(vec[active_request*])

    for i := 0; i < batch_size; i = i + 1 {
        req := pd.pending_prefill[i]
        total_tokens = total_tokens + len(req.prompt_tokens)
        batch = append(batch, req)
    }

    if total_tokens > pd.config.max_batch_tokens {
        batch = make(vec[active_request*])
        total_tokens = 0

        for i := 0; i < len(pd.pending_prefill); i = i + 1 {
            req := pd.pending_prefill[i]
            token_count := len(req.prompt_tokens)

            if total_tokens + token_count > pd.config.max_batch_tokens {
                break
            }

            batch = append(batch, req)
            total_tokens = total_tokens + token_count
        }
    }

    prefill_batch := &prefill_batch{
        requests: batch,
        batch_id: pd.total_prefill_batches_executed,
        total_tokens: total_tokens,
        created_at: current_time_ns(),
    }

    pd.current_prefill_batch = prefill_batch
    return prefill_batch
}

func (prefill_decode_pipeline* pd) execute_prefill() bool {
    if pd.current_prefill_batch == nil {
        return false
    }

    batch := pd.current_prefill_batch

    for i := 0; i < len(batch.requests); i = i + 1 {
        req := batch.requests[i]
        req.state = req_state_prefilling
        req.num_prefill_tokens = len(req.prompt_tokens)
        req.started_at = current_time_ns()
    }

    for i := 0; i < len(batch.requests); i = i + 1 {
        req := batch.requests[i]
        req.state = req_state_decoding
        pd.in_flight_decode = append(pd.in_flight_decode, req)
    }

    pd.pending_prefill = pd.pending_prefill[len(batch.requests):]
    pd.total_prefill_batches_executed = pd.total_prefill_batches_executed + 1
    pd.total_tokens_processed = pd.total_tokens_processed + batch.total_tokens
    pd.current_prefill_batch = nil

    return true
}

func (prefill_decode_pipeline* pd) prepare_decode_batch() decode_batch* {
    if len(pd.in_flight_decode) == 0 {
        return nil
    }

    batch_size := pd.config.decode_batch_size
    if batch_size > len(pd.in_flight_decode) {
        batch_size = len(pd.in_flight_decode)
    }

    batch := make(vec[active_request*])
    for i := 0; i < batch_size; i = i + 1 {
        req := pd.in_flight_decode[i]
        if !req.is_decode_complete() {
            batch = append(batch, req)
        }
    }

    if len(batch) == 0 {
        return nil
    }

    decode_batch := &decode_batch{
        requests: batch,
        batch_id: pd.total_decode_batches_executed,
        num_decode_steps: 1,
        created_at: current_time_ns(),
    }

    pd.current_decode_batch = decode_batch
    return decode_batch
}

func (prefill_decode_pipeline* pd) execute_decode() bool {
    if pd.current_decode_batch == nil {
        return false
    }

    batch := pd.current_decode_batch

    for i := 0; i < len(batch.requests); i = i + 1 {
        req := batch.requests[i]
        req.state = req_state_decoding

        if req.num_decode_steps == 0 {
            req.state = req_state_streaming
        }

        if req.is_decode_complete() {
            req.state = req_state_finished
            req.finished_at = current_time_ns()

            if req.stream != nil {
                req.stream.mark_completed()
            }

            pd.completed_requests = append(pd.completed_requests, req)
        }
    }

    pd.total_decode_batches_executed = pd.total_decode_batches_executed + 1
    pd.current_decode_batch = nil

    pd.cleanup_completed_from_in_flight()

    return true
}

func (prefill_decode_pipeline* pd) cleanup_completed_from_in_flight() {
    new_in_flight := make(vec[active_request*])

    for i := 0; i < len(pd.in_flight_decode); i = i + 1 {
        req := pd.in_flight_decode[i]
        if !req.is_finished() {
            new_in_flight = append(new_in_flight, req)
        }
    }

    pd.in_flight_decode = new_in_flight
}

func (prefill_decode_pipeline* pd) step() bool {
    if pd.current_stage == stage_idle {
        if len(pd.pending_prefill) > 0 {
            pd.current_stage = stage_prefill
            pd.prepare_prefill_batch()
        } else if len(pd.in_flight_decode) > 0 {
            pd.current_stage = stage_decode
            pd.prepare_decode_batch()
        } else {
            return false
        }
    }

    if pd.current_stage == stage_prefill {
        success := pd.execute_prefill()
        if len(pd.in_flight_decode) > 0 {
            pd.current_stage = stage_decode
        } else {
            pd.current_stage = stage_idle
        }
        return success
    }

    if pd.current_stage == stage_decode {
        success := pd.execute_decode()

        if len(pd.in_flight_decode) > 0 {
            pd.current_stage = stage_decode
        } else if len(pd.pending_prefill) > 0 {
            pd.current_stage = stage_prefill
        } else {
            pd.current_stage = stage_idle
        }

        return success
    }

    return false
}

func (prefill_decode_pipeline* pd) get_pending_count() int32 {
    return int32(len(pd.pending_prefill))
}

func (prefill_decode_pipeline* pd) get_in_flight_count() int32 {
    return int32(len(pd.in_flight_decode))
}

func (prefill_decode_pipeline* pd) get_completed_count() int32 {
    return int32(len(pd.completed_requests))
}

func (prefill_decode_pipeline* pd) get_current_stage() pipeline_stage {
    return pd.current_stage
}

func (prefill_decode_pipeline* pd) get_stats() string {
    result := "Pipeline Stats:\n"
    result = result + "Pending: " + int32_to_string(pd.get_pending_count()) + "\n"
    result = result + "In-Flight: " + int32_to_string(pd.get_in_flight_count()) + "\n"
    result = result + "Completed: " + int32_to_string(pd.get_completed_count()) + "\n"
    result = result + "Total Tokens: " + int32_to_string(pd.total_tokens_processed) + "\n"
    return result
}
