# Async Inference Engine - Implementation Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│           AsyncInferenceEngine (Main Orchestrator)          │
├─────────────────────────────────────────────────────────────┤
│  • Coordinates all subsystems                               │
│  • Manages lifecycle (start/stop/process_cycle)            │
│  • Aggregates statistics                                    │
│  • Handles request submission & routing                     │
└─────────────┬────────┬─────────────┬──────────┬─────────────┘
              │        │             │          │
              ▼        ▼             ▼          ▼
        ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐
        │  Task    │ │ Request  │ │ Batch  │ │Streaming │
        │ Manager  │ │  Queue   │ │Executor│ │ Response │
        └──────────┘ └──────────┘ └────────┘ └──────────┘
              │        │             │          │
              └────────┴─────────────┴──────────┘
                       │
                       ▼
              ┌──────────────────┐
              │  Event Loop      │
              │  (pub/sub hub)   │
              └──────────────────┘
```

---

## 1. AsyncTaskManager - Task Lifecycle

### Purpose
Manages individual inference tasks from submission through completion.

### Data Structure

```s
struct AsyncTask {
    task_id           // Unique identifier
    status            // PENDING → QUEUED → RUNNING → COMPLETED/FAILED
    input_ids         // Input tokens
    output_ids        // Generated tokens
    created_at        // Submission time
    duration_ms       // Total execution time
    error_message     // Error if failed
}
```

### State Transitions

```
PENDING
  ↓
  └→ [get_next_task()] → QUEUED
                          ↓
                    [update_task_status(RUNNING)] → RUNNING
                                                      ↓
                    [set_task_output()] ────────→ COMPLETED
                    or
                    [set_task_error()] ────────→ FAILED
```

### Key Functions

```s
submit_task()           // Create new task (returns task_id)
get_task_status()       // Get current status
update_task_status()    // Move to next state
set_task_output()       // Store results
set_task_error()        // Mark as failed
get_next_task()         // Get highest priority pending task
clear_completed_tasks() // Cleanup
```

### Thread Safety

- Uses `sync.Mutex` to protect `tasks` map
- Lock held only during map operations
- Safe for concurrent access

---

## 2. AsyncRequestQueue - Priority Scheduling

### Purpose
Maintains priority-based queue of inference requests with dynamic batching.

### Queue Structure

```s
struct AsyncRequestQueue {
    high_priority   // URGENT/HIGH priority queue
    normal_queue    // NORMAL priority queue
    low_queue       // LOW priority queue
    current_batch   // Batch being formed
}
```

### Request Types by Priority

```
PRIORITY_URGENT  (3) ─┐
                      ├─ Processed first
PRIORITY_HIGH    (2) ─┤
                      │
PRIORITY_NORMAL  (1) ─┤ Second batch
                      │
PRIORITY_LOW     (0) ─ Processed last (if space available)
```

### Batch Formation Algorithm

```
1. Collect requests from high_priority queue (up to max_batch_size)
2. Add from normal_queue (remaining space)
3. Add from low_queue (remaining space)
4. Form batch with all collected requests
5. Clear queues of consumed requests
```

### Key Functions

```s
enqueue_request()       // Add single request
enqueue_batch()         // Add multiple requests
create_batch()          // Form batch (priority-aware)
get_queue_depth()       // Check pending count
get_priority_distribution()  // Statistics by priority
```

---

## 3. AsyncBatchExecutor - Computation

### Purpose
Executes inference batches with prefill and decode phases.

### Execution Pipeline

```
┌─────────────────────────────────────────────┐
│ Input: RequestBatch (max 64 requests)       │
└────────────────┬────────────────────────────┘
                 │
        ┌────────▼────────┐
        │ PREFILL PHASE   │  [Process input tokens]
        │ (1-10ms)        │  - Embedding
        │                 │  - Attention over full seq
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │ DECODE PHASE    │  [Generate tokens]
        │ (per-token)     │  - Compute logits
        │                 │  - Sample next token
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │ Results         │  - Output tokens
        │                 │  - Latency metrics
        │                 │  - Throughput stats
        └────────┬────────┘
                 │
        ┌────────▼────────────────────┐
        │ Optional: Stream Tokens      │
        │ (if streaming_enabled)      │
        └─────────────────────────────┘
```

### Result Calculation

```
For each request in batch:
  prefill_time = time after prefill phase
  decode_time = time in decode phase
  total_latency = prefill_time + decode_time
  
  tokens_per_sec = output_tokens * 1000 / total_latency
```

### Key Functions

```s
load_batch()              // Load batch for execution
execute_batch()           // Run full pipeline
execute_prefill_phase()   // Input processing
execute_decode_step()     // Generate one token
stream_token()            // Add to stream buffer
get_executor_statistics() // Throughput metrics
```

---

## 4. AsyncStreamingResponseManager - Token Streaming

### Purpose
Manages streaming responses with buffering and flush strategies.

### Streaming Workflow

```
1. start_stream(request_id)
   └─ Creates StreamingResponse
   
2. add_token_to_stream(token)
   └─ Appends to token_buffer
   
3. Check if buffer full (size >= max_buffer_size)
   └─ If yes: flush_stream()
   
4. flush_stream()
   └─ Invoke on_token_ready callback
   └─ Clear buffer
   
5. complete_stream()
   └─ Final flush
   └─ Mark as completed
   └─ Invoke on_stream_end callback
```

### Buffer Management

```s
token_buffer: [token1, token2, ..., tokenN]
              ↓ (when size >= max_buffer_size)
              FLUSH → Notify via callback
              ↓
              Clear buffer
```

### Key Functions

```s
start_stream()              // Begin streaming
add_token_to_stream()       // Buffer token
flush_stream()              // Send buffered tokens
complete_stream()           // End streaming
get_stream_status()         // Monitor progress
on_token_ready_callback()   // Register callback
on_stream_end_callback()    // Register completion
```

---

## 5. AsyncEventLoop - Event-Driven Architecture

### Purpose
Implements pub/sub event system for task coordination.

### Event Types

```s
EVENT_TASK_SUBMITTED     (0)  // New task submitted
EVENT_TASK_STARTED       (1)  // Task execution started
EVENT_TASK_COMPLETED     (2)  // Task finished successfully
EVENT_TASK_FAILED        (3)  // Task execution failed
EVENT_BATCH_CREATED      (4)  // New batch formed
EVENT_BATCH_EXECUTED     (5)  // Batch processing done
EVENT_STREAM_STARTED     (6)  // Streaming started
EVENT_STREAM_TOKEN       (7)  // Token received
EVENT_STREAM_COMPLETED   (8)  // Stream finished
EVENT_ERROR              (9)  // Error occurred
```

### Event Processing

```
┌────────────────────────────────────┐
│ Event Queue (max_queue_size)       │
├────────────────────────────────────┤
│ • Priority queue (high priority)   │
│ • Normal queue (normal priority)   │
└────────────┬───────────────────────┘
             │
      ┌──────▼──────┐
      │ Get next    │  Priority processing:
      │ event       │  1. Priority queue first
      │             │  2. Normal queue next
      └──────┬──────┘
             │
      ┌──────▼───────────────────────┐
      │ Find registered handlers    │
      │ for event_type              │
      └──────┬───────────────────────┘
             │
      ┌──────▼──────────────────────────┐
      │ Invoke all handlers for event  │
      │ (can be multiple handlers)     │
      └──────┬──────────────────────────┘
             │
      ┌──────▼──────────────────────┐
      │ Update event stats          │
      │ • events_processed++        │
      │ • avg_latency update        │
      └─────────────────────────────┘
```

### Key Functions

```s
submit_event()          // Add event to queue
register_handler()      // Add event handler
process_next_event()    // Process one event
process_batch()         // Process up to 32 events
get_statistics()        // Event processing stats
start() / stop()        // Control loop
```

---

## 6. AsyncInferenceEngine - Complete Orchestration

### Purpose
Coordinates all subsystems in a unified inference engine.

### Processing Cycle

```
┌─────────────────────────────────────────────────────────────┐
│ process_cycle() - Main processing loop                      │
└──────────────┬────────────────────────────────────────────┬─┘
               │                                            │
        ┌──────▼──────┐                               ┌─────▼─────┐
        │ Step 1:     │                               │ Step 3:   │
        │ Process     │                               │ Execute  │
        │ Event Queue │                               │ Batch    │
        └─────────────┘                               └───────────┘
               │                                            │
        ┌──────▼──────────────────────┐                    │
        │ Step 2:                      │                    │
        │ Create Batch if requests     │                    │
        │ available                    │                    │
        └──────────────────────────────┘                    │
                                                            │
              ┌─────────────────────────────────────────────┘
              │
        ┌─────▼────────────────────────────────────────┐
        │ Step 4: Process Results                      │
        │ • Update task status                         │
        │ • Stream tokens if enabled                   │
        │ • Update metrics                             │
        │ • Invoke callbacks                           │
        └────────────────────────────────────────────┘
```

### Integration Points

```
submit_request()
  ├─ Enqueue in request_queue
  ├─ Create task in task_manager
  └─ Post event to event_loop

process_cycle()
  ├─ event_loop.process_batch()
  ├─ request_queue.create_batch()
  ├─ batch_executor.execute_batch()
  ├─ Process results
  └─ Update streaming_manager
```

### Key Functions

```s
new_async_inference_engine()    // Initialize
submit_request()                // Async request
submit_request_streaming()      // Streaming request
process_cycle()                 // Process one cycle
start() / stop()                // Lifecycle
get_status()                    // Current status
get_statistics()                // All metrics
wait_completion()               // Blocking wait
```

---

## Concurrency Model

### Thread Safety Strategy

```s
// Each component uses sync.Mutex
task_manager.mutex       // Protects tasks map
request_queue.mutex      // Protects queues
batch_executor.mutex     // Protects results
streaming_manager.mutex  // Protects streams
event_loop.mutex         // Protects event queues

// Lock acquisition pattern:
func (m *Manager) operation() {
    m.mutex.Lock()
    defer m.mutex.Unlock()
    
    // Critical section
}
```

### Concurrent Scenarios

```
Scenario 1: Multiple request submissions
  ├─ submit_request() acquired lock
  ├─ Add to queue
  ├─ Create task
  └─ Release lock
  
Scenario 2: Batch formation during processing
  ├─ process_cycle() acquires queue lock
  ├─ Read queue state
  ├─ Release lock
  ├─ Process batch (no lock)
  └─ Results stored with lock

Scenario 3: Streaming response buffering
  ├─ Executor fills buffer (no lock)
  ├─ Acquire lock when flushing
  ├─ Read/clear buffer
  └─ Release lock
```

---

## Performance Optimization

### Key Techniques

1. **Batch Processing**
   - Amortize overhead across multiple requests
   - Higher throughput at cost of latency

2. **Priority Queuing**
   - Urgent requests processed first
   - Fair scheduling across priorities

3. **Token Buffering**
   - Reduce callback overhead
   - Better streaming throughput

4. **Event Batching**
   - Process up to 32 events per cycle
   - Reduce iteration overhead

5. **Pre-allocation**
   - Initialize queues with capacity
   - Reduce allocations during execution

### Memory Considerations

```
Per-request overhead:
  AsyncTask:       ~1KB
  InferenceRequest: ~0.5KB
  ExecutionResult:  ~2KB
  StreamingResponse: ~1KB
  ──────────────────────
  Total per request: ~4.5KB

For 100 concurrent requests: ~450KB base memory
Plus token buffers and state: ~1-2MB typical

Configuration memory:
  - max_concurrent_tasks=32: ~150KB
  - max_batch_size=64: ~50KB overhead
  - event_loop_max_queue=1000: ~100KB
```

---

## Extending the Engine

### Adding Custom Processor

```s
// 1. Define processor
struct CustomProcessor {
    config        SomeConfig
    mutex         sync.Mutex
}

// 2. Implement interface
func (p *CustomProcessor) process(logits []float64) []float64 {
    // Custom logic
}

// 3. Register with engine
// (Extend AsyncInferenceEngine to hold processor)
```

### Adding Event Handler

```s
// Register handler
handler := EventHandler{
    handler_id: make([]string, 1),
    event_type: EVENT_TASK_COMPLETED,
    callback_fn: "handle_task",
}
handler.handler_id[0] = "my_handler"

engine.event_loop.register_handler(EVENT_TASK_COMPLETED, handler)
```

### Custom Scheduling Policy

```s
// Override create_batch() logic
func (q *AsyncRequestQueue) create_batch() RequestBatch {
    // Custom batching logic
    // Example: Size-based or latency-based batching
}
```

---

## Debugging & Monitoring

### Log Points

```
// Add logging at key points:
submit_request()        → Log with request_id
process_cycle()         → Log cycle count
execute_batch()         → Log batch_size, duration
add_token_to_stream()   → Log token count
```

### Statistics to Monitor

```
1. Throughput
   - Requests per second
   - Tokens per second

2. Latency
   - Average request latency
   - Tail latency (p99)

3. Utilization
   - Queue depth
   - Active tasks
   - Batch sizes

4. Quality
   - Error rate
   - Success rate
```

---

## Performance Tuning Checklist

- [ ] Measure baseline throughput with `benchmark`
- [ ] Profile with different batch sizes (8, 16, 32, 64)
- [ ] Test thread configurations (1-16 decode threads)
- [ ] Monitor memory with different queue sizes
- [ ] Verify streaming latency with buffer sizes
- [ ] Measure event processing overhead
- [ ] Test priority distribution impact
- [ ] Validate under sustained load

---

## Troubleshooting Guide

### Problem: Queue overflowing

Solution:
1. Increase `max_concurrent_tasks`
2. Increase `max_batch_size`
3. Reduce `batch_timeout_ms` for faster batching
4. Process more frequently: call `process_cycle()` more often

### Problem: High latency

Solution:
1. Reduce `max_batch_size` for faster processing
2. Increase number of `decode_threads`
3. Disable streaming if not needed
4. Reduce event queue size to prioritize critical events

### Problem: High memory usage

Solution:
1. Reduce `max_concurrent_tasks`
2. Reduce `stream_buffer_size`
3. Call `clear_completed_tasks()` periodically
4. Reduce `event_loop_max_queue`

---

## Testing Strategy

### Unit Tests
- Individual component functionality
- State transition validation
- Boundary condition testing

### Integration Tests
- Multi-component interactions
- Concurrent access patterns
- Result correctness

### Performance Tests
- Throughput under load
- Latency distribution
- Memory usage patterns

---

This completes the implementation guide for the Async Inference Engine.

For questions, refer to specific component sections above or review test cases in `test_async_inference.s`.
