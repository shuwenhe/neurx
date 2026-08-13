package inference

import "core"
import "tensor"

type RequestState int

const (
    REQUEST_QUEUED       RequestState = 0
    REQUEST_PREFILLING   RequestState = 1
    REQUEST_DECODING     RequestState = 2
    REQUEST_FINISHED     RequestState = 3
    REQUEST_ERROR        RequestState = 4
)

type SequenceRequest struct {
    request_id           int64
    prompt_tokens        []int32
    max_tokens           int32
    state                RequestState
    prefill_complete     bool
    num_generated_tokens int32
    output_tokens        []int32
    kv_slot_id           int
    priority             int
    created_at           int64
}

type BatchInfo struct {
    batch_id          int64
    requests          []*SequenceRequest
    batch_size        int
    num_prefill       int
    num_decode        int
    max_seq_len       int32
    total_prefill_len int32
}

type SchedulerConfig struct {
    max_batch_size        int32
    max_prefill_tokens    int32
    max_decode_tokens     int32
    prefill_budget        float32
    priority_scheduling   bool
    enable_disaggregated  bool
    min_decode_batch_size int32
}

type ContinuousBatchingScheduler struct {
    config               SchedulerConfig
    queue                []*SequenceRequest
    active_prefill       []*SequenceRequest
    active_decode        []*SequenceRequest
    finished_requests    []*SequenceRequest

    next_request_id      int64
    next_batch_id        int64
    total_scheduled      int64
    total_completed      int64

    scheduler_step       int64
}

func NewContinuousBatchingScheduler(config SchedulerConfig) *ContinuousBatchingScheduler {
    if config.max_batch_size <= 0 {
        config.max_batch_size = 32
    }
    if config.max_prefill_tokens <= 0 {
        config.max_prefill_tokens = 4096
    }
    if config.max_decode_tokens <= 0 {
        config.max_decode_tokens = 2048
    }
    if config.prefill_budget <= 0 || config.prefill_budget > 1.0 {
        config.prefill_budget = 0.6
    }

    return &ContinuousBatchingScheduler{
        config:              config,
        queue:               []*SequenceRequest{},
        active_prefill:      []*SequenceRequest{},
        active_decode:       []*SequenceRequest{},
        finished_requests:   []*SequenceRequest{},
        next_request_id:     1,
        next_batch_id:       1,
    }
}

func (s *ContinuousBatchingScheduler) SubmitRequest(prompt_tokens []int32, max_tokens int32, priority int) int64 {
    req := &SequenceRequest{
        request_id:      s.next_request_id,
        prompt_tokens:   prompt_tokens,
        max_tokens:      max_tokens,
        state:           REQUEST_QUEUED,
        output_tokens:   []int32{},
        priority:        priority,
        created_at:      s.scheduler_step,
    }

    s.queue = append(s.queue, req)
    s.next_request_id = s.next_request_id + 1

    return req.request_id
}

func (s *ContinuousBatchingScheduler) Schedule() *BatchInfo {
    batch := &BatchInfo{
        batch_id:      s.next_batch_id,
        requests:      []*SequenceRequest{},
        batch_size:    0,
        num_prefill:   0,
        num_decode:    0,
        max_seq_len:   0,
    }

    s.next_batch_id = s.next_batch_id + 1
    s.scheduler_step = s.scheduler_step + 1

    if len(s.queue) > 0 {
        s.sortByPriority(s.queue)
    }

    if s.config.enable_disaggregated {
        s.schedulePrefillPhase(batch)
    } else {
        s.scheduleContinuousPhase(batch)
    }

    s.scheduleDecodePhase(batch)

    if len(batch.requests) > 0 {
        batch.batch_size = len(batch.requests)
        s.total_scheduled = s.total_scheduled + int64(batch.batch_size)
    }

    return batch
}

func (s *ContinuousBatchingScheduler) schedulePrefillPhase(batch *BatchInfo) {
    prefill_budget := int32(float32(s.config.max_prefill_tokens) * s.config.prefill_budget)
    current_prefill_tokens := int32(0)
    batch_size := int32(0)

    for len(s.queue) > 0 && batch_size < s.config.max_batch_size {
        req := s.queue[0]
        prompt_len := int32(len(req.prompt_tokens))

        if current_prefill_tokens+prompt_len <= prefill_budget {
            s.queue = s.queue[1:]
            req.state = REQUEST_PREFILLING
            s.active_prefill = append(s.active_prefill, req)
            batch.requests = append(batch.requests, req)
            batch.num_prefill = batch.num_prefill + 1

            current_prefill_tokens = current_prefill_tokens + prompt_len
            batch_size = batch_size + 1

            if prompt_len > batch.max_seq_len {
                batch.max_seq_len = prompt_len
            }
        } else {
            break
        }
    }

    batch.total_prefill_len = current_prefill_tokens
}

func (s *ContinuousBatchingScheduler) scheduleContinuousPhase(batch *BatchInfo) {
    current_tokens := int32(0)
    batch_size := int32(0)

    for i := 0; i < len(s.active_decode); i++ {
        if batch_size >= s.config.max_batch_size {
            break
        }

        req := s.active_decode[i]
        if current_tokens+1 <= s.config.max_decode_tokens {
            batch.requests = append(batch.requests, req)
            batch.num_decode = batch.num_decode + 1
            batch_size = batch_size + 1
            current_tokens = current_tokens + 1
        }
    }

    prefill_budget := s.config.max_prefill_tokens - current_tokens
    if prefill_budget < 1 {
        prefill_budget = 256
    }

    used_prefill := int32(0)
    for len(s.queue) > 0 && batch_size < s.config.max_batch_size {
        req := s.queue[0]
        prompt_len := int32(len(req.prompt_tokens))

        if used_prefill+prompt_len <= prefill_budget {
            s.queue = s.queue[1:]
            req.state = REQUEST_PREFILLING
            s.active_prefill = append(s.active_prefill, req)
            batch.requests = append(batch.requests, req)
            batch.num_prefill = batch.num_prefill + 1

            used_prefill = used_prefill + prompt_len
            batch_size = batch_size + 1

            if prompt_len > batch.max_seq_len {
                batch.max_seq_len = prompt_len
            }
        } else {
            break
        }
    }
}

func (s *ContinuousBatchingScheduler) scheduleDecodePhase(batch *BatchInfo) {

    if s.config.enable_disaggregated {

        return
    }
}

func (s *ContinuousBatchingScheduler) CompletePrefill(request_id int64) {
    for i := 0; i < len(s.active_prefill); i++ {
        if s.active_prefill[i].request_id == request_id {
            req := s.active_prefill[i]
            req.state = REQUEST_DECODING
            req.prefill_complete = true

            s.active_prefill = append(s.active_prefill[:i], s.active_prefill[i+1:]...)
            s.active_decode = append(s.active_decode, req)
            return
        }
    }
}

func (s *ContinuousBatchingScheduler) AddGeneratedToken(request_id int64, token_id int32) {
    for i := 0; i < len(s.active_decode); i++ {
        if s.active_decode[i].request_id == request_id {
            s.active_decode[i].output_tokens = append(s.active_decode[i].output_tokens, token_id)
            s.active_decode[i].num_generated_tokens = s.active_decode[i].num_generated_tokens + 1
            return
        }
    }
}

func (s *ContinuousBatchingScheduler) CompleteRequest(request_id int64) {
    for i := 0; i < len(s.active_decode); i++ {
        if s.active_decode[i].request_id == request_id {
            req := s.active_decode[i]
            req.state = REQUEST_FINISHED
            s.active_decode = append(s.active_decode[:i], s.active_decode[i+1:]...)
            s.finished_requests = append(s.finished_requests, req)
            s.total_completed = s.total_completed + 1
            return
        }
    }
}

func (s *ContinuousBatchingScheduler) GetQueueSize() int {
    return len(s.queue)
}

func (s *ContinuousBatchingScheduler) GetActiveCount() int {
    return len(s.active_prefill) + len(s.active_decode)
}

func (s *ContinuousBatchingScheduler) GetStats() map[string]int64 {
    stats := make(map[string]int64)
    stats["queued"] = int64(len(s.queue))
    stats["prefilling"] = int64(len(s.active_prefill))
    stats["decoding"] = int64(len(s.active_decode))
    stats["finished"] = int64(len(s.finished_requests))
    stats["total_scheduled"] = s.total_scheduled
    stats["total_completed"] = s.total_completed
    return stats
}

func (s *ContinuousBatchingScheduler) sortByPriority(requests []*SequenceRequest) {

    for i := 0; i < len(requests); i++ {
        for j := i + 1; j < len(requests); j++ {
            if requests[j].priority > requests[i].priority {

                temp := requests[i]
                requests[i] = requests[j]
                requests[j] = temp
            } else if requests[j].priority == requests[i].priority {

                if requests[j].request_id < requests[i].request_id {
                    temp := requests[i]
                    requests[i] = requests[j]
                    requests[j] = temp
                }
            }
        }
    }
}

func main() {

    config := SchedulerConfig{
        max_batch_size:     16,
        max_prefill_tokens:  2048,
        max_decode_tokens:   512,
        enable_disaggregated: true,
    }

    scheduler := NewContinuousBatchingScheduler(config)

    prompt := []int32{1, 2, 3, 4}
    request_id := scheduler.SubmitRequest(prompt, 100, 0)

    batch := scheduler.Schedule()

    core.Println("Scheduler initialized")
    core.Println("Request ID:", request_id)
    core.Println("Batch size:", batch.batch_size)
    core.Println("Queue size:", scheduler.GetQueueSize())
}
