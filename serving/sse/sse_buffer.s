package sse

import "sync"
import "time"

enum buffer_status {
	BUFFER_EMPTY = 0
	BUFFER_PARTIAL = 1
	BUFFER_FULL = 2
	BUFFER_OVERFLOW = 3
}

struct sse_buffer {
	vec[sse_event]          events
	int32                   write_index
	int32                   read_index
	int32                   capacity
	
	buffer_status           status
	
	int32                   total_added
	int32                   total_removed
	int32                   max_size_bytes
	int32                   current_size_bytes
	
	int64                   created_at
	int64                   last_flush_time
	
	sync.Mutex              mu
}

struct buffer_config {
	int32                   capacity
	int32                   max_size_bytes
}

struct buffer_stats {
	int32                   current_events
	int32                   total_added
	int32                   total_removed
	
	int32                   buffer_usage_percent
	buffer_status           current_status
	
	int32                   current_size_bytes
	int64                   uptime_ms
}

struct sse_queue {
	vec[sse_buffer]         buffers
	int32                   buffer_count
	int32                   active_buffer_index
	
	int32                   total_enqueued
	int32                   total_dequeued
	
	int32                   max_buffers
	int32                   buffer_capacity
	
	sync.Mutex              mu
}

func create_sse_buffer(config buffer_config) sse_buffer {
	return sse_buffer{
		events:               make(vec[sse_event], 0, config.capacity),
		write_index:          0,
		read_index:           0,
		capacity:             config.capacity,
		status:               BUFFER_EMPTY,
		total_added:          0,
		total_removed:        0,
		max_size_bytes:       config.max_size_bytes,
		current_size_bytes:   0,
		created_at:           time.Now().UnixNano(),
		last_flush_time:      time.Now().UnixNano(),
		mu:                   sync.Mutex{},
	}
}

func create_sse_queue(max_buffers int32, buffer_capacity int32) sse_queue {
	return sse_queue{
		buffers:              make(vec[sse_buffer], 0, max_buffers),
		buffer_count:         0,
		active_buffer_index:  -1,
		total_enqueued:       0,
		total_dequeued:       0,
		max_buffers:          max_buffers,
		buffer_capacity:      buffer_capacity,
		mu:                   sync.Mutex{},
	}
}

func (sse_buffer* b) add_event(event sse_event) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	if b.current_size_bytes+event.data_size_bytes > b.max_size_bytes {
		b.status = BUFFER_OVERFLOW
		return false
	}
	
	if int32(len(b.events)) >= b.capacity {
		b.status = BUFFER_FULL
		return false
	}
	
	b.events = append(b.events, event)
	b.current_size_bytes = b.current_size_bytes + event.data_size_bytes
	b.total_added++
	b.write_index++
	
	if b.write_index > b.capacity/2 {
		b.status = BUFFER_PARTIAL
	}
	
	if b.write_index >= b.capacity {
		b.status = BUFFER_FULL
	}
	
	return true
}

func (sse_buffer* b) get_event() (sse_event, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	if b.read_index >= int32(len(b.events)) {
		b.status = BUFFER_EMPTY
		return sse_event{}, false
	}
	
	event := b.events[b.read_index]
	b.total_removed++
	b.read_index++
	b.current_size_bytes = b.current_size_bytes - event.data_size_bytes
	
	if b.read_index >= int32(len(b.events)) {
		b.status = BUFFER_EMPTY
	}
	
	return event, true
}

func (sse_buffer* b) peek_event() (sse_event, bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	if b.read_index >= int32(len(b.events)) {
		return sse_event{}, false
	}
	
	event := b.events[b.read_index]
	return event, true
}

func (sse_buffer* b) get_pending_events() vec[sse_event] {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	result := make(vec[sse_event], 0)
	
	for i := b.read_index; i < int32(len(b.events)); i++ {
		result = append(result, b.events[i])
	}
	
	return result
}

func (sse_buffer* b) flush() {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	b.events = make(vec[sse_event], 0, b.capacity)
	b.write_index = 0
	b.read_index = 0
	b.current_size_bytes = 0
	b.total_added = 0
	b.total_removed = 0
	b.status = BUFFER_EMPTY
	b.last_flush_time = time.Now().UnixNano()
}

func (sse_buffer* b) get_buffer_status() buffer_status {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.status
}

func (sse_buffer* b) get_buffer_stats() buffer_stats {
	b.mu.Lock()
	defer b.mu.Unlock()
	
	stats := buffer_stats{
		current_events:       b.write_index - b.read_index,
		total_added:          b.total_added,
		total_removed:        b.total_removed,
		buffer_usage_percent: 0,
		current_status:       b.status,
		current_size_bytes:   b.current_size_bytes,
		uptime_ms:            0,
	}
	
	if b.capacity > 0 {
		stats.buffer_usage_percent = ((b.write_index - b.read_index) * 100) / b.capacity
	}
	
	uptime := (time.Now().UnixNano() - b.created_at) / 1000000
	stats.uptime_ms = uptime
	
	return stats
}

func (sse_queue* q) create_new_buffer() sse_buffer {
	config := buffer_config{
		capacity:       q.buffer_capacity,
		max_size_bytes: 1024 * 1024,
	}
	return create_sse_buffer(config)
}

func (sse_queue* q) enqueue_event(event sse_event) bool {
	q.mu.Lock()
	defer q.mu.Unlock()
	
	if q.buffer_count == 0 {
		new_buffer := q.create_new_buffer()
		q.buffers = append(q.buffers, new_buffer)
		q.buffer_count++
		q.active_buffer_index = 0
	}
	
	active_idx := q.active_buffer_index
	
	added := q.buffers[active_idx].add_event(event)
	
	if !added && q.buffer_count < q.max_buffers {
		new_buffer := q.create_new_buffer()
		q.buffers = append(q.buffers, new_buffer)
		q.buffer_count++
		q.active_buffer_index = q.buffer_count - 1
		
		added = q.buffers[q.active_buffer_index].add_event(event)
	}
	
	if added {
		q.total_enqueued++
	}
	
	return added
}

func (sse_queue* q) dequeue_event() (sse_event, bool) {
	q.mu.Lock()
	defer q.mu.Unlock()
	
	for i := int32(0); i < q.buffer_count; i++ {
		event, exists := q.buffers[i].get_event()
		if exists {
			q.total_dequeued++
			return event, true
		}
	}
	
	return sse_event{}, false
}

func (sse_queue* q) get_pending_events() vec[sse_event] {
	q.mu.Lock()
	defer q.mu.Unlock()
	
	result := make(vec[sse_event], 0)
	
	for i := int32(0); i < q.buffer_count; i++ {
		pending := q.buffers[i].get_pending_events()
		for event := range pending {
			result = append(result, event)
		}
	}
	
	return result
}

func (sse_queue* q) flush_all() {
	q.mu.Lock()
	defer q.mu.Unlock()
	
	for i := int32(0); i < q.buffer_count; i++ {
		q.buffers[i].flush()
	}
	
	q.buffers = make(vec[sse_buffer], 0, q.max_buffers)
	q.buffer_count = 0
	q.active_buffer_index = -1
}

func (sse_queue* q) get_queue_stats() map[string]interface{} {
	q.mu.Lock()
	defer q.mu.Unlock()
	
	stats := make(map[string]interface{})
	stats["total_buffers"] = q.buffer_count
	stats["active_buffer_index"] = q.active_buffer_index
	stats["total_enqueued"] = q.total_enqueued
	stats["total_dequeued"] = q.total_dequeued
	stats["pending_events"] = q.total_enqueued - q.total_dequeued
	
	return stats
}
