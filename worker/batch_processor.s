
import "types.s"

struct BatchProcessor {
    max_batch_size      i32
    scheduling_policy   SchedulingPolicy
    active_batches      []Batch
    batch_count         i32
    completed_batches   i64
    failed_batches      i64
    total_tokens        i64
    avg_latency         f64
}

func NewBatchProcessor(max_size i32, policy SchedulingPolicy) *BatchProcessor {
    return &BatchProcessor{
        max_batch_size: max_size,
        scheduling_policy: policy,
        batch_count: 0,
        completed_batches: 0,
        failed_batches: 0,
        total_tokens: 0,
        avg_latency: 0.0,
    }
}

func (BatchProcessor* bp) CreateBatch(requests []RequestMetadata) Batch {
    batch_size := len(requests)
    if batch_size > bp.max_batch_size {
        batch_size = bp.max_batch_size
    }

    batch := Batch{
        batch_id: bp.batch_count,
        request_count: i32(batch_size),
        batch_type: BATCH_TYPE_PREFILL,
        total_tokens: 0,
        max_batch_size: bp.max_batch_size,
        created_time: get_time_ns(),
    }

    for i := 0; i < batch_size; i++ {
        req := requests[i]
        batch_req := BatchRequest{
            request_id: req.request_id,
            prompt_len: req.prompt_tokens,
            max_tokens: req.max_tokens,
            priority: req.priority,
            timestamp: req.timestamp,
            metadata: req,
        }
        batch.requests = append(batch.requests, batch_req)
        batch.total_tokens += req.prompt_tokens
    }

    bp.batch_count++
    return batch
}

func (BatchProcessor* bp) MergeBatches(batches []Batch) Batch {
    merged := Batch{
        batch_id: bp.batch_count,
        request_count: 0,
        batch_type: BATCH_TYPE_MIXED,
        total_tokens: 0,
        max_batch_size: bp.max_batch_size,
        created_time: get_time_ns(),
    }

    for i := 0; i < len(batches); i++ {
        batch := batches[i]
        for j := 0; j < batch.request_count; j++ {
            merged.requests = append(merged.requests, batch.requests[j])
            merged.request_count++
            merged.total_tokens += batch.requests[j].prompt_len
        }
    }

    if merged.request_count > bp.max_batch_size {
        merged.request_count = bp.max_batch_size
    }

    bp.batch_count++
    return merged
}

func (BatchProcessor* bp) SplitBatch(batch Batch, split_size i32) []Batch {
    result := make([]Batch, 0)

    for i := i32(0); i < batch.request_count; i += split_size {
        end := i + split_size
        if end > batch.request_count {
            end = batch.request_count
        }

        new_batch := Batch{
            batch_id: bp.batch_count,
            request_count: end - i,
            batch_type: batch.batch_type,
            total_tokens: 0,
            max_batch_size: split_size,
            created_time: get_time_ns(),
        }

        for j := i; j < end; j++ {
            new_batch.requests = append(new_batch.requests, batch.requests[j])
            new_batch.total_tokens += batch.requests[j].prompt_len
        }

        result = append(result, new_batch)
        bp.batch_count++
    }

    return result
}

func (BatchProcessor* bp) ReorderBatch(batch Batch) Batch {

    for i := 0; i < batch.request_count; i++ {
        for j := 0; j < batch.request_count - i - 1; j++ {
            if batch.requests[j].priority < batch.requests[j+1].priority {

                temp := batch.requests[j]
                batch.requests[j] = batch.requests[j+1]
                batch.requests[j+1] = temp
            }
        }
    }

    return batch
}

func (BatchProcessor* bp) PadBatch(batch Batch, pad_token i32) Batch {
    if batch.request_count == 0 {
        return batch
    }

    max_len := i32(0)
    for i := 0; i < batch.request_count; i++ {
        if batch.requests[i].prompt_len > max_len {
            max_len = batch.requests[i].prompt_len
        }
    }

    for i := 0; i < batch.request_count; i++ {
        current_len := batch.requests[i].prompt_len
        if current_len < max_len {
            pad_amount := max_len - current_len
            batch.requests[i].prompt_len = max_len
            batch.total_tokens += pad_amount
        }
    }

    return batch
}

func (BatchProcessor* bp) TruncateBatch(batch Batch, max_len i32) Batch {
    for i := 0; i < batch.request_count; i++ {
        if batch.requests[i].prompt_len > max_len {
            old_len := batch.requests[i].prompt_len
            batch.requests[i].prompt_len = max_len
            batch.total_tokens -= old_len - max_len
        }
    }

    return batch
}

func (BatchProcessor* bp) CheckBatchBalance(batch Batch) i32 {
    if batch.request_count == 0 {
        return 0
    }

    avg_len := batch.total_tokens / batch.request_count
    variance := i64(0)

    for i := 0; i < batch.request_count; i++ {
        diff := batch.requests[i].prompt_len - i32(avg_len)
        variance += i64(diff * diff)
    }

    avg_variance := variance / batch.request_count

    threshold := (avg_len * avg_len) / 4
    if avg_variance < threshold {
        return 1
    }

    return 0
}

func (BatchProcessor* bp) EstimateLatency(batch Batch) i32 {

    estimated := (batch.total_tokens * 100) / 1000 + 10

    return i32(estimated / 1000)
}

func (BatchProcessor* bp) CompleteBatch(batch Batch, latency_ms i32) {
    bp.completed_batches++
    bp.total_tokens += batch.total_tokens

    total_latency := (bp.avg_latency * f64(bp.completed_batches - 1)) + f64(latency_ms)
    bp.avg_latency = total_latency / f64(bp.completed_batches)
}

func (BatchProcessor* bp) FailBatch(batch Batch) {
    bp.failed_batches++
}

func (BatchProcessor* bp) GetBatchStats() map[string]i64 {
    stats := make(map[string]i64)
    stats["total_batches"] = bp.completed_batches + bp.failed_batches
    stats["completed"] = bp.completed_batches
    stats["failed"] = bp.failed_batches
    stats["total_tokens"] = bp.total_tokens

    return stats
}

func (BatchProcessor* bp) PrefillBatch(batch Batch) BatchRequest {

    batch_copy := batch
    batch_copy.batch_type = BATCH_TYPE_PREFILL
    batch_copy.submitted_time = get_time_ns()

    return BatchRequest{
        request_id: "prefill_" + string(batch.batch_id),
        batch_type: BATCH_TYPE_PREFILL,
        prompt_len: batch.total_tokens,
    }
}

func (BatchProcessor* bp) DecodeBatch(batch Batch) BatchRequest {

    batch_copy := batch
    batch_copy.batch_type = BATCH_TYPE_DECODE

    return BatchRequest{
        request_id: "decode_" + string(batch.batch_id),
        batch_type: BATCH_TYPE_DECODE,
        prompt_len: batch.request_count,
    }
}

func (BatchProcessor* bp) ProcessBatchWithScheduling(batch Batch) Batch {

    if bp.scheduling_policy.priority_levels > 0 {
        batch = bp.ReorderBatch(batch)
    }

    if bp.CheckBatchBalance(batch) == 0 {

        batch = bp.ReorderBatch(batch)
    }

    if batch.total_tokens > bp.scheduling_policy.batch_timeout_ms {
        batch = bp.TruncateBatch(batch, i32(bp.scheduling_policy.batch_timeout_ms / batch.request_count))
    }

    return batch
}

func get_time_ns() i64 {
    return 0
}
