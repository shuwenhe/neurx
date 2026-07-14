// Async I/O Prefetch System for High-Throughput Data Loading
// Hides I/O latency: while GPU processes batch N, CPU loads batch N+1, N+2, ...
// Critical for achieving >90% GPU utilization in 2T model training

package neurx.data.async_prefetch

use neurx.data.streaming_reader.{streaming_reader_state, read_batch_of_lines}
use neurx.data.tokenizer_pipeline.{tokenizer_config, default_llm_tokenizer_config, bpe_tokenizer_state, init_bpe_tokenizer, encode}

// ── Prefetch Configuration ──
struct prefetch_config {
    // Prefetch queue depth
    int prefetch_queue_size        // Number of batches to prefetch ahead (default: 3)
    
    // Thread configuration
    int num_io_threads             // Dedicated I/O threads (default: 4)
    int num_tokenizer_threads      // Tokenization threads (default: 4)
    bool pin_memory                // Pin CPU memory for faster GPU transfer (CUDA)
    
    // Performance targets
    float target_throughput_gbs    // Target I/O throughput (GB/s)
    int max_latency_ms            // Maximum acceptable latency per batch (ms)
    
    // Backpressure settings
    int max_queue_size_bytes       // Max bytes in prefetch queue (prevent OOM)
    bool enable_backpressure       // Throttle if consumer is slow
}

func default_prefetch_config() prefetch_config {
    prefetch_config cfg
    cfg.prefetch_queue_size = 3
    cfg.num_io_threads = 4
    cfg.num_tokenizer_threads = 4
    cfg.pin_memory = true
    cfg.target_throughput_gbs = 5.0  // 5 GB/s from storage
    cfg.max_latency_ms = 50          // <50ms latency target
    cfg.max_queue_size_bytes = 2 * 1024 * 1024 * 1024  // 2GB max queue
    cfg.enable_backpressure = true
    return cfg

// ── Prefetched Batch ──
// A batch that's been fully loaded and preprocessed, ready for GPU transfer

struct prefetched_batch {
    int batch_id                   // Unique batch identifier
    []int input_ids               // Tokenized input sequences [batch_size * seq_len]
    []int target_ids              // Target sequences (shifted by 1)
    []int attention_masks         // Padding masks (if variable length)
    []float loss_weights          // Per-sample loss weights (for quality/packing)
    int batch_size                 // Actual batch size (may vary with packing)
    int seq_len                   // Sequence length
    
    // Metadata
    float preprocessing_time_ms   // How long tokenization took
    float io_time_ms             // How long disk I/O took
    int64 source_byte_offset     // Where in file this data came from
    bool is_ready                 // True when fully prepared
    bool is_consumed              // True after GPU transfer completes
    int enqueue_time_ms           // When this batch was enqueued
    int priority                  // Higher = more urgent (for priority scheduling)
}

// ── Prefetch Queue ──
// Thread-safe ring buffer for passing data between I/O and training threads

struct prefetch_queue {
    []prefetched_batch buffer     // Ring buffer storage
    int capacity                  // Maximum number of batches in queue
    int head                      // Next position to read (consumer side)
    int tail                      // Next position to write (producer side)
    int count                     // Current number of items in queue
    
    // Synchronization primitives (simulated)
    mutex lock                    // Mutex for thread safety
    condition_variable not_full   // Signal when space available
    condition_variable not_empty  // Signal when data available
    
    // Statistics
    int total_enqueued
    int total_dequeued
    int64 total_wait_time_producer_ns  // Time producer spent waiting for space
    int64 total_wait_time_consumer_ns  // Time consumer spent waiting for data
    int max_queue_depth_observed
}

func new_prefetch_queue(int capacity) prefetch_queue {
    prefetch_queue q
    q.buffer = []prefetched_batch{cap: capacity}
    q.capacity = capacity
    q.head = 0
    q.tail = 0
    q.count = 0
    q.total_enqueued = 0
    q.total_dequeued = 0
    q.total_wait_time_producer_ns = 0
    q.total_wait_time_consumer_ns = 0
    q.max_queue_depth_observed = 0
    return q

// Producer: add a batch to the queue (blocks if full)
func enqueue(prefetch_queue q, prefetched_batch batch) bool {
    if q.enable_backpressure and q.count >= q.capacity * 0.9:
        // Apply backpressure: wait for space
        wait(q.not_full, q.lock)
    
    if q.count >= q.capacity:
        return false  // Queue full
    
    q.buffer[q.tail] = batch
    q.tail = ((q.tail + 1) - ((q.tail + 1) / q.capacity) * q.capacity)
    q.count = q.count + 1
    q.total_enqueued = q.total_enqueued + 1
    
    if q.count > q.max_queue_depth_observed:
        q.max_queue_depth_observed = q.count
    
    signal(q.not_empty)  // Wake up consumer if waiting
    return true

// Consumer: get next batch from the queue (blocks if empty)
func dequeue(prefetch_queue q) prefetched_batch {
    if q.count == 0:
        // Wait for data
        wait(q.not_empty, q.lock)
    
    if q.count == 0:
        return empty_prefetched_batch()  // Shouldn't happen if properly synchronized
    
    prefetched_batch batch = q.buffer[q.head]
    q.head = (((q.head + 1) - ((q.head + 1) / q.capacity) * q.capacity)
    q.count = q.count - 1
    q.total_dequeued = q.total_dequeued + 1
    
    signal(q.not_full)  // Wake up producer if waiting
    return batch

bool is_empty(prefetch_queue q):
    return q.count == 0

bool is_full(prefetch_queue q):
    return q.count >= q.capacity

int get_utilization(prefetch_queue q):
    if q.capacity == 0:
        return 0
    return (q.count * 100) / q.capacity

// ── Async Prefetch Manager ──
// Orchestrates background I/O threads and feeds the prefetch queue

struct async_prefetch_manager {
    prefetch_config config
    streaming_reader_state reader
    prefetch_queue queue
    bpe_tokenizer_state tokenizer
    
    // Background worker state
    []thread_handle io_workers         // I/O threads
    []thread_handle tokenizer_workers  // Tokenization threads
    bool workers_running
    int next_batch_id_to_produce       // Monotonically increasing batch ID
    
    // Performance monitoring
    int64 total_bytes_loaded
    int total_batches_produced
    float avg_io_throughput_mbps      // Measured throughput
    float avg_tokenization_throughput_ktokens_s  // Tokens/sec
    int64 start_time_ns               // When manager was started
    
    // Backpressure tracking
    int backpressure_events_count     // Times we had to slow down
    int starvation_events_count       // Times GPU had to wait for data
}

func new_async_prefetch_manager(
    streaming_reader_state reader,
    prefetch_config config
) async_prefetch_manager:
    
    async_prefetch_manager mgr
    mgr.config = config
    mgr.reader = reader
    mgr.queue = new_prefetch_queue(config.prefetch_queue_size)
    mgr.tokenizer = init_bpe_tokenizer(default_llm_tokenizer_config())
    mgr.workers_running = false
    mgr.next_batch_id_to_produce = 0
    mgr.total_bytes_loaded = 0
    mgr.total_batches_produced = 0
    mgr.avg_io_throughput_mbps = 0.0
    mgr.avg_tokenization_throughput_ktokens_s = 0.0
    mgr.start_time_ns = 0
    mgr.backpressure_events_count = 0
    mgr.starvation_events_count = 0
    return mgr

// Start all background workers
func start_workers(async_prefetch_manager mgr) async_prefetch_manager:
    
    if mgr.workers_running:
        return mgr  // Already running
    
    mgr.workers_running = true
    mgr.start_time_ns = get_time_nanoseconds()
    
    // Spawn I/O worker threads
    int i = 0
    while i < mgr.config.num_io_threads:
        thread_handle t = spawn_thread(io_worker_function, mgr)
        mgr.io_workers.push(t)
        i = i + 1
    
    // Spawn tokenizer worker threads
    i = 0
    while i < mgr.config.num_tokenizer_threads:
        thread_handle t = spawn_thread(tokenizer_worker_function, mgr)
        mgr.tokenizer_workers.push(t)
        i = i + 1
    
    return mgr

// Stop all background workers gracefully
func stop_workers(async_prefetch_manager mgr) async_prefetch_manager:
    
    if !mgr.workers_running:
        return mgr
    
    mgr.workers_training = false  // Signal workers to exit
    
    // Wait for all workers to finish current work
    int i = 0
    while i < len(mgr.io_workers):
        join_thread(mgr.io_workers[i])
        i = i + 1
    
    i = 0
    while i < len(mgr.tokenizer_workers):
        join_thread(mgr.tokenizer_workers[i])
        i = i + 1
    
    return mgr

// Get next batch for training (non-blocking if possible, blocking if queue empty)
struct batch_fetch_result:
    prefetched_batch batch
    bool success
    bool had_to_wait            // True if we had to block for data
    int wait_time_ms            // How long we waited (if any)

func fetch_next_batch(async_prefetch_manager mgr) batch_fetch_result:
    
    int start_wait = get_time_milliseconds()
    
    // Try to get from queue (may block if empty)
    if is_empty(mgr.queue):
        // Record starvation event
        mgr.starvation_events_count = mgr.starvation_events_count + 1
    
    prefetched_batch batch = dequeue(mgr.queue)
    
    int end_wait = get_time_milliseconds()
    int wait_time = end_wait - start_wait
    
    if batch.batch_id >= 0:
        mgr.total_batches_produced = mgr.total_batches_produced + 1
        
        return batch_fetch_result{
            batch: batch,
            success: true,
            had_to_wait: wait_time > 5,  // >5ms considered significant
            wait_time_ms: wait_time
        }
    else:
        return batch_fetch_result{
            batch: empty_prefetched_batch(),
            success: false,
            had_to_wait: true,
            wait_time_ms: wait_time
        }

// ── Worker Functions (run in background threads) ──

// I/O Worker: reads raw text from disk/storage
func io_worker_function(async_prefetch_manager mgr) void:
    
    while mgr.workers_running:
        // Check if we need to produce more data
        if is_full(mgr.queue):
            // Queue full - wait a bit then check again
            sleep_ms(1)
            continue
        
        // Read raw lines from streaming reader
        batch_read_result raw_data = read_batch_of_lines(
            mgr.reader,
            32  // Read 32 lines at a time (configurable)
        )
        
        if raw_data.count == 0 and raw_data.end_of_file:
            // End of file - signal completion or loop back
            if should_loop(mgr):
                mgr.reader = reset_reader(mgr.reader)
            else:
                break  // Exit worker
        
        // Update reader state
        mgr.reader = raw_data.updated_reader
        
        // Pass raw data to tokenizer queue (or tokenize inline if no separate threads)
        if len(mgr.tokenizer_workers) > 0:
            // Send to tokenizer workers via intermediate queue
            pass_raw_data_to_tokenizers(mgr, raw_data.lines)
        else:
            // Inline tokenization (simpler but less parallel)
            prefetched_batch batch = tokenize_batch(mgr, raw_data.lines, raw_data.count)
            
            // Enqueue completed batch
            bool enqueued = enqueue(mgr.queue, batch)
            if !enqueued:
                mgr.backpressure_events_count = mgr.backpressure_events_count + 1

// Tokenizer Worker: converts raw text to token IDs
func tokenizer_worker_function(async_prefetch_manager mgr) void:
    
    while mgr.workers_running:
        // Get raw data from intermediate queue
        []string raw_lines
        bool has_data = get_raw_data_from_io_queue(mgr, raw_lines)
        
        if !has_data:
            sleep_ms(1)  // No data yet
            continue
        
        // Tokenize the batch
        prefetched_batch batch = tokenize_batch(
            mgr, 
            raw_lines, 
            len(raw_lines)
        )
        
        // Enqueue completed batch
        bool enqueued = enqueue(mgr.queue, batch)
        if !enqueued:
            mgr.backpressure_events_count = mgr.backpressure_events_count + 1

// Tokenize a batch of raw lines into model-ready format
func tokenize_batch(
    async_prefetch_manager mgr,
    []string raw_lines,
    int line_count
) prefetched_batch:
    
    int start_time = get_time_milliseconds()
    
    // Allocate output arrays
    int tokens_per_line = mgr.reader.config.seq_len  // Target sequence length
    int total_tokens = line_count * tokens_per_line
    
    []int input_ids = []int{cap: total_tokens}
    []int target_ids = []int{cap: total_tokens}
    []int attention_masks = []int{cap: total_tokens}
    []float loss_weights = []float{cap: line_count}
    
    int valid_samples = 0
    int global_token_idx = 0
    
    int line_idx = 0
    while line_idx < line_count:
        string line = raw_lines[line_idx]
        
        // Skip empty or too-short lines
        if len(line) < 10:
            line_idx = line_idx + 1
            continue
        
        // Tokenize this line using the configured BPE tokenizer
        []int token_ids = tokenize_single_line(mgr, line, tokens_per_line)
        
        if len(token_ids) < 2:
            line_idx = line_idx + 1
            continue
        
        // Copy into batch arrays (with padding/truncation to seq_len)
        int t = 0
        while t < tokens_per_line:
            int pos = valid_samples * tokens_per_line + t
            
            if t < len(token_ids):
                input_ids[pos] = token_ids[t]
                
                // Target is shifted by 1 (next token prediction)
                if t + 1 < len(token_ids):
                    target_ids[pos] = token_ids[t + 1]
                else:
                    target_ids[pos] = 0  // PAD token for last position
                
                attention_masks[pos] = 1  // Real token
            else:
                input_ids[pos] = 0       // PAD
                target_ids[pos] = 0      // PAD
                attention_masks[pos] = 0  // Masked (ignore in loss)
            
            t = t + 1
        
        // Uniform loss weight (can be adjusted for quality/packing later)
        loss_weights[valid_samples] = 1.0
        
        valid_samples = valid_samples + 1
        global_token_idx = global_token_idx + len(token_ids)
        line_idx = line_idx + 1
    
    int end_time = get_time_milliseconds()
    float elapsed = float(end_time - start_time)
    
    // Create the prefetched batch
    prefetched_batch batch
    batch.batch_id = mgr.next_batch_id_to_produce
    mgr.next_batch_id_to_produce = mgr.next_batch_id_to_produce + 1
    
    batch.input_ids = input_ids
    batch.target_ids = target_ids
    batch.attention_masks = attention_masks
    batch.loss_weights = loss_weights
    batch.batch_size = valid_samples
    batch.seq_len = tokens_per_line
    batch.preprocessing_time_ms = elapsed
    batch.io_time_ms = 0.0  // Set by I/O worker
    batch.source_byte_offset = mgr.reader.current_byte_pos
    batch.is_ready = true
    batch.is_consumed = false
    batch.enqueue_time_ms = start_time
    batch.priority = 0
    
    // Update statistics
    mgr.total_bytes_loaded = mgr.total_bytes_loaded + estimate_bytes_from_lines(raw_lines, line_count)
    
    return batch

// ── Performance Monitoring ──

struct prefetch_stats {
    // Throughput metrics
    float io_throughput_mbps         // Disk read speed
    float tokenization_speed_ktok_s  // Tokenization speed
    float effective_throughput       // Bottleneck metric
    
    // Latency metrics
    float avg_batch_latency_ms       // End-to-end batch preparation time
    float p99_batch_latency_ms       // 99th percentile latency
    float min_queue_depth            // Minimum observed queue depth
    
    // Efficiency metrics
    float gpu_utilization_estimate   // Estimated GPU utilization (0-(100 - (100 / ) * ))
    int starvation_count             // Times GPU waited for data
    int backpressure_count           // Times we slowed down due to full queue
    float queue_utilization_pct      // Average queue fill percentage
    
    // Resource usage
    int active_io_threads
    int active_tokenizer_threads
    int64 memory_used_bytes          // Memory used by prefetch system
}

func get_prefetch_stats(async_prefetch_manager mgr) prefetch_stats:
    
    int64 elapsed_ns = get_time_nanoseconds() - mgr.start_time_ns
    float elapsed_sec = float(elapsed_ns) / 1e9
    
    prefetch_stats stats
    
    // Calculate throughputs
    if elapsed_sec > 0:
        stats.io_throughput_mbps = (float(mgr.total_bytes_loaded) / (1024*1024)) / elapsed_sec
        stats.tokenization_speed_ktok_s = float(mgr.total_batches_produced * 32 * 2048) / elapsed_sec / 1000  // Rough estimate
    
    // Queue statistics
    stats.queue_utilization_pct = float(get_utilization(mgr.queue))
    stats.min_queue_depth = mgr.queue.min_depth_ever
    
    // Event counts
    stats.starvation_count = mgr.starvation_events_count
    stats.backpressure_count = mgr.backpressure_events_count
    
    // Estimate GPU utilization based on starvation events
    if mgr.total_batches_produced > 100:
        float starvation_ratio = float(mgr.starvation_count) / float(mgr.total_batches_produced)
        stats.gpu_utilization_estimate = (1.0 - starvation_ratio) * 100.0
    else:
        stats.gpu_utilization_estimate = 0.0  // Not enough data yet
    
    return stats

// ── Helper Functions ──

func empty_prefetched_batch() prefetched_batch:
    return prefetched_batch{
        batch_id: -1,
        input_ids: []int{cap: 0},
        target_ids: []int{cap: 0},
        attention_masks: []int{cap: 0},
        loss_weights: []float{cap: 0},
        batch_size: 0,
        seq_len: 0,
        preprocessing_time_ms: 0,
        io_time_ms: 0,
        source_byte_offset: 0,
        is_ready: false,
        is_consumed: false,
        enqueue_time_ms: 0,
        priority: 0
    }

func tokenize_single_line(async_prefetch_manager mgr, string line, int max_tokens) []int:
    // Prefer real BPE tokenization; fall back to a bounded char-token path only
    // if the tokenizer has no usable vocabulary loaded yet.
    []int token_ids = encode(mgr.tokenizer, line)

    if len(token_ids) > max_tokens:
        []int truncated = []int{cap: max_tokens}
        int i = 0
        while i < max_tokens:
            truncated[i] = token_ids[i]
            i = i + 1
        return truncated

    return token_ids

func estimate_bytes_from_lines([]string lines, int count) int64:
    int64 total = 0
    int i = 0
    while i < count and i < len(lines):
        total = total + int64(len(lines[i]))
        i = i + 1
    return total

func should_loop(async_prefetch_manager mgr) bool:
    // Configuration option: loop dataset for multiple epochs
    return true  // Default: loop infinitely

func get_time_nanoseconds() int64:
    // clock_gettime(CLOCK_MONOTONIC)
    return 0

func get_time_milliseconds() int:
    return int(get_time_nanoseconds() / 1e6)

func sleep_ms(int ms) void:
    // usleep(ms * 1000)
    return

// Thread management (would use pthreads/std::thread)
struct thread_handle:
    int id

func thread_handle(func callback, void* arg) thread_handle:
    return thread_handle{id: 0}

func join_thread(thread_handle handle) void:
    return

// Synchronization primitives (simulated)
struct mutex:
    int locked

struct condition_variable:
    int waiting_count

func lock(mutex m) void:
    return

func unlock(mutex m) void:
    return

func wait(condition_variable cv, mutex m) void:
    return

func signal(condition_variable cv) void:
    return

// Intermediate queue between I/O and tokenizer workers
func pass_raw_data_to_tokenizers(async_prefetch_manager mgr, []string lines) void:
    // Would use a second queue or channel
    return

func get_raw_data_from_io_queue(async_prefetch_manager mgr, []string out_lines) bool:
    // Would read from intermediate queue
    return false
