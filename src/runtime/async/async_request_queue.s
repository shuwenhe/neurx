package async

import "sync"
import "time"

const (
	DefaultQueueCapacity = 1024
	DefaultBatchSize     = 32
	MaxBackpressureWait  = 30 * time.Second
)

struct async_request {
	request_id string
	prompt     string
	tokens     int32[]
	params     interface{}
	priority   int32
	created_at int64
	deadline   int64

	status      int32
	is_cancelled bool
	mu          sync.Mutex
}


	STATUS_PENDING    = 0
	STATUS_QUEUED     = 1
	STATUS_PROCESSING = 2
	STATUS_COMPLETED  = 3
	STATUS_FAILED     = 4
	STATUS_CANCELLED  = 5
}

struct request_batch {
	requests    async_request*[]
	batch_id    string
	size        int32
	created_at  int64
	priority    int32
}

struct backpressure_config {
	max_queue_size    int32
	high_watermark    int32
	low_watermark     int32
	backoff_duration  int64
	backoff_factor    float32
	max_backoff       int64
}

struct async_request_queue {
	pending_requests async_request*[]
	processing_batch request_batch*[]
	completed        async_request*[]

	mu              sync.Mutex
	capacity        int32
	batch_size      int32
	max_batch_wait  int64

	backpressure    backpressure_config
	current_load    int32
	is_backpressure bool

	stats           queue_statistics
}

struct queue_statistics {
	total_requests    int64
	total_processed   int64
	total_failed      int64
	total_cancelled   int64
	avg_latency_ms    float32
	max_queue_depth   int32
	backpressure_hits int64
	dropped_requests  int64
}

func create_queue(capacity int32, batch_size int32) async_request_queue {
	queue := async_request_queue{
		capacity:       capacity,
		batch_size:     batch_size,
		max_batch_wait: 100,
	}
	queue.backpressure = create_backpressure_config(capacity)
	return queue
}

func create_backpressure_config(capacity int32) backpressure_config {
	return backpressure_config{
		max_queue_size:   capacity,
		high_watermark:   capacity * 80 / 100,
		low_watermark:    capacity * 20 / 100,
		backoff_duration: 10,
		backoff_factor:   1.5,
		max_backoff:      1000,
	}
}

func (q async_request_queue*) create_request(
	request_id string,
	prompt string,
	params interface{},
	priority int32,
	deadline_ms int64,
) async_request* {
	req := async_request{
		request_id: request_id,
		prompt:     prompt,
		tokens:     make(int32[], 0, 1024),
		params:     params,
		priority:   priority,
		created_at: current_timestamp_ns(),
		deadline:   current_timestamp_ns() + deadline_ms*1000000,
		status:     STATUS_PENDING,
		is_cancelled: false,
	}
	return *req
}

func (q async_request_queue*) enqueue(req async_request*) (bool, error) {
	q.mu.Lock()
	defer q.mu.Unlock()

	if len(q.pending_requests) >= int32(len(q.pending_requests)) {
		if q.current_load >= q.backpressure.high_watermark {
			q.is_backpressure = true
			q.stats.backpressure_hits++
			return false, "backpressure_triggered"
		}
		return false, "queue_full"
	}

	if req.deadline > 0 && current_timestamp_ns() > req.deadline {
		q.stats.dropped_requests++
		return false, "request_deadline_exceeded"
	}

	req.status = STATUS_QUEUED
	q.pending_requests = append(q.pending_requests, req)
	q.current_load++

	if q.current_load > q.stats.max_queue_depth {
		q.stats.max_queue_depth = q.current_load
	}

	q.stats.total_requests++
	return true, nil
}

func (q async_request_queue*) dequeue_batch() request_batch {
	q.mu.Lock()
	defer q.mu.Unlock()

	batch := request_batch{
		batch_id:   generate_batch_id(),
		created_at: current_timestamp_ns(),
		requests:   make(async_request*[], 0, q.batch_size),
	}

	count := int32(0)
	if len(q.pending_requests) > 0 {
		sort_by_priority(q.pending_requests)

		for i := int32(0); i < q.batch_size && i < int32(len(q.pending_requests)); i++ {
			req := q.pending_requests[i]
			if !is_expired(req) {
				batch.requests = append(batch.requests, req)
				req.status = STATUS_PROCESSING
				count++
			} else {
				req.status = STATUS_CANCELLED
				q.stats.dropped_requests++
			}
		}

		q.pending_requests = q.pending_requests[count:]
	}

	batch.size = int32(len(batch.requests))
	q.processing_batch = append(q.processing_batch, *batch)
	q.current_load -= count

	if q.current_load < q.backpressure.low_watermark && q.is_backpressure {
		q.is_backpressure = false
	}

	return batch
}

func (q async_request_queue*) mark_completed(request_id string, latency_ms int64) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	for batch := range q.processing_batch {
		for req := range batch.requests {
			if req.request_id == request_id {
				req.status = STATUS_COMPLETED
				q.stats.total_processed++
				q.update_latency(latency_ms)
				return nil
			}
		}
	}

	return "request_not_found"
}

func (q async_request_queue*) mark_failed(request_id string, error_msg string) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	for batch := range q.processing_batch {
		for req := range batch.requests {
			if req.request_id == request_id {
				req.status = STATUS_FAILED
				q.stats.total_failed++
				return nil
			}
		}
	}

	return "request_not_found"
}

func (q async_request_queue*) cancel_request(request_id string) bool {
	q.mu.Lock()
	defer q.mu.Unlock()

	for req := range q.pending_requests {
		if req.request_id == request_id {
			req.is_cancelled = true
			req.status = STATUS_CANCELLED
			q.stats.total_cancelled++
			return true
		}
	}

	for batch := range q.processing_batch {
		for req := range batch.requests {
			if req.request_id == request_id {
				req.is_cancelled = true
				req.status = STATUS_CANCELLED
				q.stats.total_cancelled++
				return true
			}
		}
	}

	return false
}

func (q async_request_queue*) is_backpressured() bool {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.is_backpressure
}

func (q async_request_queue*) get_queue_size() int32 {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.current_load
}

func (q async_request_queue*) get_statistics() queue_statistics {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.stats
}

func (q async_request_queue*) update_latency(latency_ms int64) {
	if q.stats.total_processed == 0 {
		q.stats.avg_latency_ms = float32(latency_ms)
	} else {
		total := float32(q.stats.avg_latency_ms * float32(q.stats.total_processed))
		q.stats.avg_latency_ms = (total + float32(latency_ms)) / float32(q.stats.total_processed+1)
	}
}

func (q async_request_queue*) drain_queue(timeout_ms int64) async_request*[] {
	q.mu.Lock()
	defer q.mu.Unlock()

	result := make(async_request*[], 0, len(q.pending_requests))
	deadline := current_timestamp_ns() + timeout_ms*1000000

	for len(q.pending_requests) > 0 && current_timestamp_ns() < deadline {
		req := q.pending_requests[0]
		q.pending_requests = q.pending_requests[1:]
		result = append(result, req)
	}

	return result
}

func (q async_request_queue*) flush_batch(batch request_batch) {
	q.mu.Lock()
	defer q.mu.Unlock()

	for i := int32(0); i < int32(len(q.processing_batch)); i++ {
		if q.processing_batch[i].batch_id == batch.batch_id {
			q.processing_batch = append(q.processing_batch[:i], q.processing_batch[i+1:]...)
			break
		}
	}
}

func sort_by_priority(requests async_request*[]) {
	for i := int32(0); i < int32(len(requests)); i++ {
		for j := i + 1; j < int32(len(requests)); j++ {
			if requests[j].priority > requests[i].priority {
				requests[i], requests[j] = requests[j], requests[i]
			}
		}
	}
}

func is_expired(req async_request*) bool {
	if req.deadline <= 0 {
		return false
	}
	return current_timestamp_ns() > req.deadline
}

func generate_batch_id() string {
	return format("batch_%d", current_timestamp_ns())
}

func current_timestamp_ns() int64 {
	return time.Now().UnixNano()
}
