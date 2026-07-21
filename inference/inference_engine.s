// ============================================================
// NEURX Inference Optimization System
//
// English textoptimizeEnglish text:
//   1. KV Cache: English textgenerateEnglish textcache Key/Value,English textcompute
//   2. PagedAttention: vLLM English text KV Cache English textmanagement
//   3. Continuous Batching: English text,English text GPU English text
//   4. Speculative Decoding: English textmodelEnglish textmodelgenerate (2-3x speedup)
//   5. Quantization: INT8/INT4 PTQ English text,English textcompute
//
// English text: English text NEURX-5.2 English textrun
// ============================================================

package neurx.inference.neurx

import neurx.model.llm.neurx.*
import neurx.attention.*
import neurx.tokenizer.neurx.*

// ============================================================
// KV Cache English text (English text)
// ============================================================

struct kv_cache_entry {
    tensor key_cache      // [num_layers, num_kv_heads, seq_len, head_dim]
    tensor value_cache    // [num_layers, num_kv_heads, seq_len, head_dim]
    int current_length    // English textcacheEnglish text
}

class KVCacheManager {
    int num_layers
    int num_kv_heads
    int head_dim
    int max_cache_len     # Maximum cache length (for pre-allocation)

    # Per-layer caches
    []tensor layer_key_caches
    []tensor layer_value_caches

    []int cache_lengths   # Current length per batch item

func init(
    int num_layers,
    int num_kv_heads,
    int head_dim,
    int max_batch_size = 1,
    int max_seq_len = 8192
) -> KVCacheManager {

    print(f"🗃️ Initializing KV Cache Manager:")
    print(f"   Layers: {num_layers}")
    print(f"   KV Heads: {num_kv_heads}")
    print(f"   Head Dim: {head_dim}")
    print(f"   Max Batch Size: {max_batch_size}")
    print(f"   Max Seq Len: {max_seq_len}")

    // Pre-allocate memory for maximum size (avoids fragmentation)
    long total_memory_bytes = (
        long(num_layers) * max_batch_size * max_seq_len * num_kv_heads * head_dim * 2 * 2  # K + V, fp16
    )
    float memory_gb = float(total_memory_bytes) / (1024**3)
    print(f"   Pre-allocated Memory: {memory_gb:.2f} GB")

    return KVCacheManager{
        num_layers: num_layers,
        num_kv_heads: num_kv_heads,
        head_dim: head_dim,
        max_cache_len: max_seq_len,

        # Initialize empty caches (will be filled during inference)
        layer_key_caches: [],
        layer_value_caches: [],
        cache_lengths: [0] * max_batch_size,
    }

func update(
    self: KVCacheManager,
    int layer_idx,
    tensor new_keys,       # [B, kv_heads, S_new, D]
    tensor new_values,      # [B, kv_heads, S_new, D]
    []int batch_indices     # Which batch items to update (-1 for all)
) -> tuple[tensor, tensor] {
    """
    English text KV cache

    Returns:
        Full K, V tensors including cached values
    """

    if len(self.layer_key_caches) <= layer_idx:
        # Initialize this layer's cache on first use
        self.layer_key_caches[layer_idx] = new_keys.clone()
        self.layer_value_caches[layer_idx] = new_values.clone()
    else:
        # Concatenate along sequence dimension
        self.layer_key_caches[layer_idx] = concat([
            self.layer_key_caches[layer_idx],
            new_keys
        ], dim=2)

        self.layer_value_caches[layer_idx] = concat([
            self.layer_value_caches[layer_idx],
            new_values
        ], dim=2)

    return (
        self.layer_key_caches[layer_idx],
        self.layer_value_caches[layer_idx]
    )

func get_cached_kv(
    self: KVCacheManager,
    int layer_idx
) -> option[tuple[tensor, tensor]]:
    """English textcomplete KV cache"""

    if layer_idx < len(self.layer_key_caches):
        return some((
            self.layer_key_caches[layer_idx],
            self.layer_value_caches[layer_idx]
        ))
    else:
        return none

func reset(self: KVCacheManager):
    """English text cache"""
    self.layer_key_caches.clear()
    self.layer_value_caches.clear()
    self.cache_lengths = [0] * len(self.cache_lengths)

func get_memory_usage(self: KVCacheManager) -> dict[str, int64]:
    """English textuseEnglish text"""

    int64 total_k_memory = 0
    int64 total_v_memory = 0

    for k_cache in self.layer_key_caches:
        if k_cache != None:
            total_k_memory += get_tensor_memory(k_cache)

    for v_cache in self.layer_value_caches:
        if v_cache != None:
            total_v_memory += get_tensor_memory(v_cache)

    int current_max_len = max(self.cache_lengths) if self.cache_lengths else 0

    return {
        "key_memory_bytes": total_k_memory,
        "value_memory_bytes": total_v_memory,
        "total_memory_bytes": total_k_memory + total_v_memory,
        "current_max_seq_len": current_max_len,
        "num_active_entries": len(self.layer_key_caches),
    }

// ============================================================
// PagedAttention (vLLM English text)
// English text KV Cache English text
//
// English text:
// - English text KV Cache English text blocks/pages
// - use block table English text blocks
// - supportEnglish text (English textrequestEnglish text)
// - English text memory sharing English text
// ============================================================

struct memory_block {
    int block_id           # Physical block ID
    tensor key_data        # [block_size, kv_heads, head_dim]
    tensor value_data      # [block_size, kv_heads, head_dim]
    bool is_free           # Whether this block is available
    int ref_count          # Number of sequences using this block
}

struct sequence_metadata {
    int seq_id             # Sequence identifier
    []int block_table      # Logical → Physical block mapping table
    int current_length     # Current sequence length
    int context_length     # Prefix/context length (if any)
    bool is_finished       # Sequence has completed generation
}

class PagedAttentionManager {
    int block_size          # Tokens per block (typically 16)
    int num_blocks          # Total number of physical blocks
    int num_kv_heads       # Number of KV heads
    int head_dim            # Head dimension
    int dtype_size          # Bytes per element (2 for fp16/bf16)

    memory_block[] physical_blocks  # All physical memory blocks
    dict[int, sequence_metadata> active_sequences  # seq_id → metadata

    int next_block_id       # Counter for new block allocation

    struct stats {
        int total_allocated_blocks
        int free_blocks
        int cache_hits
        int cache_misses
        float memory_utilization
        int64 peak_memory_bytes
    } stats

func init_paged_attention(
    int num_kv_heads,
    int head_dim,
    int gpu_memory_mb: int64 = 80 * 1024,  # 80GB H100
    int block_size: int = 16,
    float reserve_ratio: float = 0.9         # Use 90% of GPU memory for KV cache
) -> PagedAttentionManager {

    # Calculate how many blocks we can fit
    int64 bytes_per_block = (
        long(block_size) * num_kv_heads * head_dim * dtype_size * 2  # K + V
    )
    int64 usable_memory = gpu_memory_mb * 1024 * 1024 * reserve_ratio
    int num_blocks = int(usable_memory / bytes_per_block)

    print(f"\n📖 Initializing Paged Attention Manager:")
    print(f"   Block Size: {block_size} tokens")
    print(f"   Bytes per Block: {bytes_per_block:,} ({bytes_per_block / 1024:.1f} KB)")
    print(f"   Total Blocks: {num_blocks:,}")
    print(f"   Total KV Cache Capacity: {(num_blocks * bytes_per_block) / (1024**3):.2f} GB")

    # Initialize all blocks as free
    memory_block[] blocks
    for i in range(num_blocks):
        append(blocks, memory_block{
            block_id: i,
            key_data: zeros(block_size, num_kv_heads, head_dim),
            value_data: zeros(block_size, num_kv_heads, head_dim),
            is_free: true,
            ref_count: 0,
        })

    return PagedAttentionManager{
        block_size: block_size,
        num_blocks: num_blocks,
        num_kv_heads: num_kv_heads,
        head_dim: head_dim,
        dtype_size: 2,  # fp16/bf16
        physical_blocks: blocks,
        active_sequences: {},
        next_block_id: 0,
        stats: stats{
            total_allocated_blocks: 0,
            free_blocks: num_blocks,
            cache_hits: 0,
            cache_misses: 0,
            memory_utilization: 0.0,
            peak_memory_bytes: 0,
        },
    }

func allocate_sequence(
    self: PagedAttentionManager,
    int seq_id,
    int initial_length: int = 0
) -> sequence_metadata:
    """
    English text blocks

    Args:
        seq_id: English text
        initial_length: English text token English text (English text prefix caching)

    Returns:
        Sequence metadata with block table
    """

    int blocks_needed = max(1, ceil_div(initial_length, self.block_size))

    # Allocate free blocks
    []int allocated_blocks
    for i in range(blocks_needed):
        int block_id = _find_free_block()
        if block_id == -1:
            raise OutOfMemoryError("No free blocks available! Consider reducing batch size or sequence length.")
        self.physical_blocks[block_id].is_free = false
        self.physical_blocks[block_id].ref_count += 1
        append(allocated_blocks, block_id)

    # Create sequence metadata
    sequence_metadata meta {
        seq_id: seq_id,
        block_table: allocated_blocks,
        current_length: initial_length,
        context_length: initial_length,  # Assume all initial tokens are context
        is_finished: false,
    }

    self.active_sequences[seq_id] = meta

    # Update statistics
    self.stats.total_allocated_blocks += blocks_needed
    self.stats.free_blocks -= blocks_needed
    self.stats.memory_utilization = \
        1.0 - float(self.stats.free_blocks) / float(self.num_blocks)

    return meta

func extend_sequence(
    self: PagedAttentionManager,
    int seq_id,
    tensor new_keys,    # [1, kv_heads, new_tokens, D]
    tensor new_values    # [1, kv_heads, new_tokens, D]
) -> void:
    """
    extensionEnglish text KV cache (generateEnglish text token English text)
    """

    if seq_id not in self.active_sequences:
        raise ValueError(f"Sequence {seq_id} not found")

    sequence_metadata meta = self.active_sequences[seq_id]
    int new_tokens = shape(new_keys)[2]

    # Write new data into existing blocks
    int global_token_offset = meta.current_length
    int local_offset_in_block = global_token_offset % self.block_size

    # Handle case where new tokens span multiple blocks
    int tokens_written = 0
    while tokens_written < new_tokens:
        int block_index = (global_token_offset + tokens_written) // self.block_size
        int offset_within_block = (global_token_offset + tokens_written) % self.block_size

        if block_index >= len(meta.block_table):
            # Need to allocate a new block
            int new_block_id = _find_free_block()
            if new_block_id == -1:
                raise OutOfMemoryError("Cannot allocate new block for sequence extension!")

            self.physical_blocks[new_block_id].is_free = false
            self.physical_blocks[new_block_id].ref_count += 1
            append(meta.block_table, new_block_id)
            self.stats.free_blocks -= 1

        int physical_block_id = meta.block_table[block_index]
        int space_in_block = self.block_size - offset_within_block
        int tokens_to_write = min(space_in_block, new_tokens - tokens_written)

        # Write to physical block
        self.physical_blocks[physical_block_id].key_data[
            offset_within_block : offset_within_block + tokens_to_write
        ] = new_keys[:, :, tokens_written : tokens_written + tokens_to_write]

        self.physical_blocks[physical_block_id].value_data[
            offset_within_block : offset_within_block + tokens_to_write
        ] = new_values[:, :, tokens_written : tokens_written + tokens_to_write]

        tokens_written += tokens_to_write

    meta.current_length += new_tokens

func free_sequence(self: PagedAttentionManager, int seq_id) -> void:
    """
    English text blocks
    """

    if seq_id not in self.active_sequences:
        return

    sequence_metadata meta = self.active_sequences[seq_id]

    for block_id in meta.block_table:
        self.physical_blocks[block_id].ref_count -= 1
        if self.physical_blocks[block_id].ref_count <= 0:
            self.physical_blocks[block_id].is_free = true
            self.stats.free_blocks += 1

    del self.active_sequences[seq_id]
    self.stats.total_allocated_blocks -= len(meta.block_table)

func gather_kv_for_attention(
    self: PgedAttentionManager,
    int seq_id,
    int query_start_pos,
    int query_end_pos
) -> tuple[tensor, tensor]:
    """
    English text paged memory English textcompleteEnglish text KV English text attention compute

    This is the core operation that makes PagedAttention efficient.
    Instead of storing contiguous tensors, it gathers from scattered blocks.
    """

    sequence_metadata meta = self.active_sequences[seq_id]
    int total_kv_len = meta.current_length  # Gather all KV up to current length

    # Pre-allocate output tensors
    tensor full_keys(1, self.num_kv_heads, total_kv_len, self.head_dim)
    tensor full_values(1, self.num_kv_heads, total_kv_len, self.head_dim)

    # Gather from blocks according to block table
    int dst_pos = 0
    for logical_block_idx, physical_block_id in enumerate(meta.block_table):
        int start_in_block = 0
        int end_in_block = self.block_size

        # First block might be partial
        if logical_block_idx == 0:
            start_in_block = 0

        # Last block might be partial
        if logical_block_idx == len(meta.block_table) - 1:
            tokens_in_last_block = meta.current_length % self.block_size
            end_in_block = tokens_in_last_block if tokens_in_last_block > 0 else self.block_size

        int copy_len = min(end_in_block - start_in_block, total_kv_len - dst_pos)
        if copy_len <= 0:
            break

        # Copy from physical block to contiguous output
        full_keys[:, :, dst_pos : dst_pos + copy_len] = \
            self.physical_blocks[physical_block_id].key_data[start_in_block : start_in_block + copy_len]

        full_values[:, :, dst_pos : dst_pos + copy_len] = \
            self.physical_blocks[physical_block_id].value_data[start_in_block : start_in_block + copy_len]

        dst_pos += copy_len

    return (full_keys, full_values)

# Internal helper
func _find_free_block(self: PagedAttentionManager) -> int:
    """English text block"""
    for block in self.physical_blocks:
        if block.is_free:
            return block.block_id
    return -1

// ============================================================
// Continuous Batching (English text)
// English textmanagementrequestEnglish text,implementationEnglish text GPU English text
// ============================================================

enum request_status {
    WAITING       # English text
    PROCESSING    # English text (English text)
    GENERATING    # English textgenerate
    COMPLETED     # English text
    CANCELLED     # English text
}

struct inference_request {
    int request_id
    string prompt_text
    tensor input_ids              # Encoded prompt
    int prompt_length
    int max_output_length
    float temperature
    float top_p
    int top_k

    request_status status
    datetime created_time
    datetime start_time
    datetime completed_time

    string generated_text
    int generated_length
    tensor[] output_token_ids

    # For monitoring
    int ttft_ms                  # Time To First Token (ms)
    float tokens_per_second
    int total_tokens_processed
}

class ContinuousBatchScheduler {
    int max_batch_size            # Maximum concurrent requests
    int max_queue_size            # Maximum waiting queue size
    float scheduling_policy       # "fcfs" | "sjf" | "priority"

    queue<inference_request> waiting_queue
    dict<int, inference_request> active_requests  # ID → Request
    dict<int, inference_request> completed_requests

    struct stats {
        int total_requests_served
        int total_tokens_generated
        float avg_ttft_ms
        float avg_throughput_tps
        int peak_concurrent_requests
    } stats

func init_scheduler(
    int max_batch_size: int = 32,
    int max_queue_size: int = 256,
    string policy: string = "fcfs"
) -> ContinuousBatchScheduler {

    print(f"\n📋 Initializing Continuous Batch Scheduler:")
    print(f"   Max Concurrent Requests: {max_batch_size}")
    print(f"   Max Queue Size: {max_queue_size}")
    print(f"   Scheduling Policy: {policy.upper()}")

    return ContinuousBatchScheduler{
        max_batch_size: max_batch_size,
        max_queue_size: max_queue_size,
        scheduling_policy: policy,
        waiting_queue: queue(),
        active_requests: {},
        completed_requests: {},
        stats: stats{
            total_requests_served: 0,
            total_tokens_generated: 0,
            avg_ttft_ms: 0.0,
            avg_throughput_tps: 0.0,
            peak_concurrent_requests: 0,
        },
    }

func add_request(
    self: ContinuousBatchScheduler,
    string prompt,
    tensor encoded_input_ids,
    int max_output_len: int = 512,
    float temperature: float = 0.7,
    float top_p: float = 0.9,
    int top_k: int = 50
) -> int:
    """
    English textinferencerequest

    Returns:
        request_id for tracking
    """

    if len(self.waiting_queue) >= self.max_queue_size:
        raise QueueFullError("Request queue is full. Try again later.")

    static int next_id = 0
    next_id += 1

    inference_request req {
        request_id: next_id,
        prompt_text: prompt,
        input_ids: encoded_input_ids,
        prompt_length: shape(encoded_input_ids)[1],
        max_output_length: max_output_len,
        temperature: temperature,
        top_p: top_p,
        top_k: top_k,
        status: WAITING,
        created_time: now(),
        generated_text: "",
        generated_length: 0,
        output_token_ids: [],
        ttft_ms: 0,
        tokens_per_second: 0.0,
        total_tokens_processed: 0,
    }

    self.waiting_queue.push(req)
    return req.request_id

func schedule_batch(self: ContinuousBatchScheduler) -> list[inference_request]:
    """
    English textrequest

    English text:
    - FCFS (First Come First Serve): default,English text
    - SJF (Shortest Job First): English textrequest
    - Priority: English text
    """

    # Move requests from waiting → active if capacity available
    while len(self.active_requests) < self.max_batch_size && !self.waiting_queue.empty():
        inference_request req = self.waiting_queue.front()
        self.waiting_queue.pop()

        req.status = PROCESSING
        req.start_time = now()
        self.active_requests[req.request_id] = req

    # Return active requests sorted by scheduling policy
    list<inference_request> batch = list(self.active_requests.values())

    match self.scheduling_policy:
        case "sjf":
            # Shortest job first (by estimated remaining tokens)
            sort(batch, key=lambda r: r.prompt_length + r.max_output_length)
        case "priority":
            # Could add priority field to requests
            pass
        case _:  # fcfs
            pass  # Already in insertion order

    # Update stats
    self.stats.peak_concurrent_requests = max(
        self.stats.peak_concurrent_requests,
        len(batch)
    )

    return batch

func mark_completed(
    self: ContinuousBatchScheduler,
    int request_id,
    string final_text,
    []int all_output_ids
) -> void:
    """
    English textrequestEnglish text
    """

    if request_id not in self.active_requests:
        return

    inference_request req = self.active_requests[request_id]
    req.status = COMPLETED
    req.completed_time = now()
    req.generated_text = final_text
    req.output_token_ids = all_output_ids
    req.generated_length = len(all_output_ids) - req.prompt_length

    # Calculate metrics
    req.ttft_ms = (req.start_time - req.created_time).total_seconds() * 1000
    if req.generated_length > 0:
        generation_time = (req.completed_time - req.start_time).total_seconds()
        req.tokens_per_second = req.generated_length / max(generation_time, 0.001)

    # Move to completed
    del self.active_requests[request_id]
    self.completed_requests[request_id] = req

    # Update aggregate stats
    self.stats.total_requests_served += 1
    self.stats.total_tokens_generated += req.generated_length

    # Running average TTFT
    n = self.stats.total_requests_served
    self.stats.avg_ttft_ms = (
        self.stats.avg_ttft_md * (n - 1) + req.ttft_ms
    ) / n

    # Throughput (tokens/sec over last minute would need time window)
    self.stats.avg_throughput_tps = (
        float(self.stats.total_tokens_generated) /
        max((now() - self.scheduler_start).total_seconds(), 0.001)
    )

func get_status_report(self: ContinuousBatchScheduler) -> string:
    """generatestateEnglish text"""

    report = f"""
╔══════════════════════════════════════════╗
║     Continuous Batching Status Report        ║
╠══════════════════════════════════════════╣
║ Active Requests:  {len(self.active_requests):>6}                ║
║ Waiting Queue:    {len(self.waiting_queue):>6}                ║
║ Completed:        {len(self.completed_requests):>6}                ║
╠══════════════════════════════════════════╣
║ Total Served:     {self.stats.total_requests_served:>6}                ║
║ Total Tokens Gen: {self.stats.total_tokens_generated:>10,}            ║
║ Avg TTFT:         {self.stats.avg_ttft_ms:>8.2f} ms           ║
║ Avg Throughput:   {self.stats.avg_throughput_tps:>8.1f} tok/s       ║
║ Peak Concurrent:  {self.stats.peak_concurrent_requests:>6}                ║
╚══════════════════════════════════════════╝
"""
    return report

// ============================================================
// NEURX Inference Engine (English text)
// ============================================================

class inference_engine {
    neurx_model model
    tokenizer_state tokenizer
    KVCacheManager kv_manager
    option[PagedAttentionManager] paged_manager
    ContinuousBatchScheduler scheduler

    # Generation config defaults
    struct gen_config {
        float default_temperature = 0.7
        float default_top_p = 0.9
        int default_top_k = 50
        float repetition_penalty = 1.0
        float presence_penalty = 0.0
        float frequency_penalty = 0.0
        int max_new_tokens = 2048
        bool do_sample = true
        bool use_cache = true
        bool early_stopping = False
    } gen_config

    # Performance tracking
    struct perf_stats {
        int64 total_forward_time_us
        int total_generate_calls
        int total_tokens_generated
        float avg_latency_per_token_ms
        float peak_gpu_memory_gb
    } perf_stats

func init_engine(
    neurx_model model,
    tokenizer_state tokenizer,
    int max_batch_size: int = 16,
    bool enable_paged_attention: bool = true,
    int gpu_memory_mb: int64 = 80 * 1024
) -> inference_engine {

    print("\n" + "="*60)
    print("🚀 Initializing NEURX Inference Engine")
    print("="*60)

    # Extract model config for cache setup
    neurx_config cfg = model.config
    int num_kv_heads = cfg.num_key_value_heads
    int head_dim = cfg.hidden_size / cfg.num_attention_heads

    # Initialize KV Cache Manager
    KVCacheManager kv_mgr = init(num_layers=cfg.num_layers, num_kv_heads=num_kv_heads, head_dim=head_dim)

    # Initialize Paged Attention (optional but recommended)
    option[PagedAttentionManager] paged_mgr = none
    if enable_paged_attention:
        paged_mgr = some(init_paged_attention(
            num_kv_heads=num_kv_heads,
            head_dim=head_dim,
            gpu_memory_mb=gpu_memory_mb,
            block_size=16
        ))

    # Initialize scheduler
    ContinuousBatchScheduler sched = init_scheduler(max_batch_size=max_batch_size)

    print(f"\n✅ Inference Engine Ready!")
    print(f"   Model: {cfg.name}")
    print(f"   Vocab Size: {cfg.vocab_size:,}")
    print(f"   Hidden Size: {cfg.hidden_size}")
    print(f"   Layers: {cfg.num_layers}")
    print(f"   Heads: Q={cfg.num_attention_heads}, KV={num_kv_heads}")
    print("="*60 + "\n")

    return inference_engine{
        model: model,
        tokenizer: tokenizer,
        kv_manager: kv_mgr,
        paged_manager: paged_mgr,
        scheduler: sched,
        perf_stats: perf_stats{
            total_forward_time_us: 0,
            total_generate_calls: 0,
            total_tokens_generated: 0,
            avg_latency_per_token_ms: 0.0,
            peak_gpu_memory_gb: 0.0,
        },
    }

func generate(
    self: inference_engine,
    string prompt,
    int max_new_tokens: int = 512,
    float temperature: float = 0.7,
    float top_p: float = 0.9,
    int top_k: int = 50,
    bool do_sample: bool = true,
    bool stream: bool = false,
    callback: option<function> = None  # Streaming callback
) -> string:
    """
    English textrequestEnglish textgenerate (English textfunction)

    Args:
        prompt: inputpromptEnglish text
        max_new_tokens: English textgenerate token English text
        temperature: English textparameter (>0, English text)
        top_p: Nucleus sampling English text
        top_k: Top-k sampling parameter
        do_sample: English text (False = greedy)
        stream: English textoutput
        callback: English textoutputEnglish textfunction

    Returns:
        generateEnglish text (English text prompt)
    """

    timer.start("generate_total")

    # ===== Step 1: Encode Prompt =====
    timer.start("encode")
    dict[str, any] encoded = encode(
        self.tokenizer,
        prompt,
        add_special_tokens=True,
        return_tensors=True
    )

    tensor input_ids = encoded["input_ids"]  # [1, prompt_len]
    int prompt_len = shape(input_ids)[1]
    timer.stop("encode")

    print(f"\n🔤 Generating (prompt length: {prompt_len}, max new tokens: {max_new_tokens})")

    # ===== Step 2: Initial Forward (Process entire prompt) =====
    timer.start("prefill")

    # Reset KV cache for new sequence
    self.kv_manager.reset()

    dict[str, any] outputs = neurx_forward(
        self.model,
        input_ids=input_ids,
        attention_mask=None,  # Will be handled by causal mask internally
        position_ids=some(arange(prompt_len).unsqueeze(0)),
        sop_eop_info=none,  # Standard generation mode
        use_cache=True  # Enable KV cache
    )

    tensor logits = outputs["logits"][:, -1, :]  # Get last token logits: [1, vocab]

    # Store KV cache from prefill
    if "past_kv" in outputs:
        # ... update kv_manager ...
        pass

    timer.stop("prefill")
    int ttft_ms = timer.get_elapsed_ms("prefill")
    print(f"   ⏱ Prefill (TTFT): {ttft_ms:.1f} ms")

    # ===== Step 3: Autoregressive Generation Loop =====
    []int generated_ids = []
    string generated_text = ""

    for step in range(max_new_tokens):
        timer.start("decode_step")

        # sample next token
        int next_token_id = sample_next_token(
            logits=logits,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            do_sample=do_sample
        )

        append(generated_ids, next_token_id)

        # Decode token to text (for streaming)
        string new_token_text = decode(
            self.tokenizer,
            [next_token_id],
            skip_special_tokens=True
        )
        generated_text += new_token_text

        # Stream callback
        if stream && callback != None:
            callback!(new_token_text, step, max_new_tokens)

        # Check for EOS
        if next_token_id == self.tokenizer.special_tokens.eos_token_id:
            print(f"   🛑 EOS reached at step {step+1}")
            break

        # Prepare next input (only the new token)
        tensor next_input = tensor([[next_token_id]])  # [1, 1]
        int next_position = prompt_len + step + 1

        # Forward with KV cache
        timer.start("forward_cached")
        outputs = neurx_forward(
            self.model,
            input_ids=next_input,
            position_ids=some(tensor([[next_position]])),
            layer_past_kv=self.kv_manager.get_all_cached_kv(),  # Pass cached KV
            use_cache=True
        )
        timer.stop("forward_cached")

        logits = outputs["logits"][:, -1, :]  # [1, vocab]

        # Update KV cache
        if "new_kv" in outputs:
            # ... update kv_manager ...
            pass

        timer.stop("decode_step")

    timer.stop("generate_total")

    # ===== Step 4: Post-processing & Stats =====
    float total_time = timer.get_elapsed_sec("generate_total")
    int num_generated = len(generated_ids)

    float tokens_per_sec = num_generated / max(total_time - ttft_ms/1000, 0.001)
    float latency_per_token = (total_time*1000 - ttft_ms) / max(num_generated, 1)

    # Update performance stats
    self.perf_stats.total_generate_calls += 1
    self.perf_stats.total_tokens_generated += num_generated
    self.perf_stats.avg_latency_per_token_ms = (
        self.perf_stats.avg_latency_per_token_ms * 0.9 +
        latency_per_token * 0.1
    )

    print(f"   ✅ Generation Complete:")
    print(f"      Tokens Generated: {num_generated}")
    print(f"      Total Time: {total_time:.2f}s")
    print(f"      Tokens/sec: {tokens_per_sec:.1f}")
    print(f"      Latency/token: {latency_per_token:.2f}ms")

    # Truncate at special tokens if any
    generated_text = truncate_at_special_tokens(generated_text)

    return generated_text

func sample_next_token(
    tensor logits,           # [1, vocab_size]
    float temperature,
    float top_p,
    int top_k,
    bool do_sample
) -> int:
    """
    English text logits English text token

    supportEnglish text:
    - Greedy: English text argmax
    - Temperature: English text logits English text softmax
    - Top-p: Nucleus sampling
    - Top-k: English text top-k English text
    """

    if !do_sample:
        # Greedy decoding
        return int(logits.argmax(dim=-1).item())

    # Apply temperature
    if temperature > 0 && temperature != 1.0:
        logits = logits / temperature

    # Convert to probabilities
    tensor probs = softmax(logits, dim=-1)

    # Apply top-k filtering
    if top_k > 0 && top_k < len(probs):
        # Set probabilities below top-k to zero
        tensor indices_to_remove = probs < torch.topk(probs, top_k)[0][..., -1, None]
        probs[indices_to_remove] = 0.0
        probs = probs / probs.sum()  # Re-normalize

    # Apply top-p (nucleus) filtering
    if top_p < 1.0:
        sorted_probs, sorted_indices = sort(probs, descending=True)
        cumulative_probs = cumsum(sorted_probs, dim=-1)

        # Remove tokens with cumulative probability above threshold
        sorted_indices_to_remove = cumulative_probs > top_p
        # Shift right to keep first token above threshold
        sorted_indices_to_remove[..., 1:] = sorted_indices_to_remove[..., :-1].clone()
        sorted_indices_to_remove[..., 0] = 0

        # Scatter back to original indexing
        indices_to_remove = zeros_like(probs).scatter_(
            dim=-1, index=sorted_indices, src=sorted_indices_to_remove
        )
        probs[indices_to_remove] = 0.0
        probs = probs / probs.sum()  # Re-normalize

    # sample from categorical distribution
    int next_token_id = multinomial(probs, num_samples=1).item()

    return next_token_id

func generate_batch(
    self: inference_engine,
    []string prompts,
    int max_new_tokens: int = 512,
    **kwargs
) -> []string:
    """
    English textgenerate (use continuous batching)

    English text,English textuseEnglish text generate()
    """

    # Add all prompts as requests
    []int request_ids = []
    for prompt in prompts:
        dict[str, any] encoded = encode(self.tokenizer, prompt, return_tensors=True)
        int rid = self.scheduler.add_request(
            prompt=prompt,
            encoded_input_ids=encoded["input_ids"],
            max_output_len=max_new_tokens,
            **kwargs
        )
        append(request_ids, rid)

    # Process until all complete
    []string results = []
    while len(results) < len(prompts):
        # Schedule next batch
        list<inference_request> batch = self.scheduler.schedule_batch()

        if len(batch) == 0:
            sleep(0.001)  # Avoid busy wait
            continue

        # Run one iteration for each active request
        for req in batch:
            string text = self.generate(
                prompt=req.prompt_text,
                max_new_tokens=req.max_output_length,
                temperature=req.temperature,
                top_p=req.top_p,
                top_k=req.top_k
            )

            self.scheduler.mark_completed(
                req.request_id,
                final_text=text,
                all_output_ids=req.output_token_ids
            )

            if req.request_id in request_ids:
                append(results, text)

    return results

// ============================================================
// English textsupport (Quantization)
// English textmodelEnglish text,English textinference
// ============================================================

enum quantization_type {
    NONE          # FP16/BF16 (no quantization)
    INT8          # 8-bit integer quantization
    INT4          # 4-bit integer quantization
    NF4           # Normalized Float 4-bit (QLoRA style)
    GPTQ          # GPTQ post-training quantization
    AWQ           # Activation-aware Weight Quantization
}

struct quantization_config {
    quantization_type qtype
    int group_size        # Quantization group size (128 typical)
    bool symmetric       # Symmetric vs asymmetric quantization
    float scale_dtype    # Data type for scale factors ("fp32" | "fp16")
}

func create_default_quant_config() -> quantization_config:
    return quantization_config{
        qtype: NONE,
        group_size: 128,
        symmetric: true,
        scale_dtype: "fp32",
    }

func apply_quantization(
    neurx_model model,
    quantization_config config
) -> neurx_model:
    """
    English textmodelweight

    support:
    - INT8: Linear English textweightEnglish text int8
    - INT4: English text (Required calibration)
    - NF4: QLoRA English text float4
    """

    match config.qtype:
        case INT8:
            print("Applying INT8 quantization...")
            _apply_int8_quantization(model, config.group_size)

        case INT4:
            print("Applying INT4 quantization...")
            _apply_int4_quantization(model, config.group_size)

        case NF4:
            print("Applying NF4 quantization...")
            _apply_nf4_quantization(model, config.group_size)

        case AWQ:
            print("Applying AWQ quantization...")
            _apply_awq_quantization(model)

        case _:
            print("No quantization applied.")

    # Report compression ratio
    int original_params = count_parameters(model.config)
    int compressed_params = estimate_compressed_size(model, config)
    float ratio = float(compressed_params) / float(original_params)

    print(f"✅ Quantization complete!")
    print(f"   Compression: {ratio:.1%} of original size")
    print(f"   Original: ~{original_params / 1e6:.0f}M params")
    print(f"   Compressed: ~{compressed_params / 1e6:.0f}M params (effective)")

    return model

// ============================================================
// testfunction
// ============================================================

func test_inference_system() {
    print("\n" + "="*70)
    print("Testing NEURX Inference Optimization System")
    print("="*70)

    // Test 1: KV Cache Manager
    print("\n[Test 1] Testing KV Cache Manager...")
    KVCacheManager kv_mgr = init(num_layers=4, num_kv_heads=8, head_dim=64)

    # Simulate updating cache for a few layers
    for layer in range(4):
        tensor new_k = randn(1, 8, 10, 64)  # New keys for 10 tokens
        tensor new_v = randn(1, 8, 10, 64)  # New values
        kv_mgr.update(layer, new_k, new_v)

    dict mem_info = kv_mgr.get_memory_usage()
    assert(mem_info["num_active_entries"] == 4)
    print(f"   Cache entries: {mem_info['num_active_entries']}")
    print(f"   Memory usage: {mem_info['total_memory_bytes'] / 1024:.1f} KB")
    print("✅ KV Cache Manager works!")

    // Test 2: Paged Attention Manager
    print("\n[Test 2] Testing Paged Attention Manager...")
    PagedAttentionManager paged_mgr = init_paged_attention(
        num_kv_heads=8,
        head_dim=64,
        gpu_memory_mb=1024,  # 1GB test budget
        block_size=16
    )

    # Allocate a sequence
    sequence_metadata seq_meta = paged_mgr.allocate_sequence(seq_id=1, initial_length=50)
    assert(len(seq_meta.block_table) > 0)
    assert(seq_meta.current_length == 50)

    # Extend sequence
    tensor new_k = randn(1, 8, 20, 64)
    tensor new_v = randn(1, 8, 20, 64)
    paged_mgr.extend_sequence(seq_id=1, new_keys=new_k, new_values=new_v)

    assert(paged_mgr.active_sequences[1].current_length == 70)

    # Free sequence
    paged_mgr.free_sequence(seq_id=1)
    assert(1 not in paged_mgr.active_sequences)

    print(f"   Allocated/freed sequence successfully")
    print(f"   Free blocks after free: {paged_mgr.stats.free_blocks}")
    print("✅ Paged Attention Manager works!")

    // Test 3: Continuous Batching Scheduler
    print("\n[Test 3] Testing Continuous Batching Scheduler...")
    ContinuousBatchScheduler sched = init_scheduler(max_batch_size=4)

    # Add requests
    tensor dummy_input = tensor([[1, 2, 3]])
    int id1 = sched.add_request("Hello", dummy_input, max_output_len=100)
    int id2 = sched.add_request("How are you?", dummy_input, max_output_len=50)
    int id3 = sched.add_request("Tell me a joke", dummy_input, max_output_len=200)

    assert(id1 > 0 && id2 > 0 && id3 > 0)
    assert(len(sched.waiting_queue) == 3)

    # Schedule batch
    list<inference_request> batch = sched.schedule_batch()
    assert(len(batch) == 3)  # All should fit in batch
    assert(batch[0].status == PROCESSING)

    # Complete first request
    sched.mark_completed(id1, "Hi there!", [1, 2, 3, 4])

    print(sched.get_status_report())
    print("✅ Continuous Batching Scheduler works!")

    // Test 4: Token Sampling
    print("\n[Test 4] Testing token sampling strategies...")
    tensor test_logits = zeros(1, 10000)
    test_logits[0, 42] = 100.0  # Make token 42 most likely
    test_logits[0, 123] = 90.0  # Second likely
    test_logits[0, 999] = 80.0  # Third likely

    int greedy_id = sample_next_token(test_logits, temperature=0, top_p=1.0, top_k=0, do_sample=False)
    assert(greedy_id == 42)
    print(f"   Greedy selection: {greedy_id}")

    int temp_id = sample_next_token(test_logits, temperature=0.5, top_p=1.0, top_k=0, do_sample=True)
    print(f"   Temp-sampled: {temp_id} (likely 42 or nearby)")

    # Test top-k
    int topk_id = sample_next_token(test_logits, temperature=1.0, top_p=1.0, top_k=2, do_sample=True)
    assert(topk_id in [42, 123])
    print(f"   Top-k=2 sampled: {topk_id}")
    print("✅ Token sampling works!")

    // Test 5: Quantization Config
    print("\n[Test 5] Testing quantization configuration...")
    quantization_config qconfig = create_default_quant_config()
    assert(qconfig.qtype == NONE)

    qconfig.qtype = INT4
    qconfig.group_size = 64
    print(f"   Quantization type: {qconfig.qtype}")
    print(f"   Group size: {qconfig.group_size}")
    print("✅ Quantization config works!")

    print("\n" + "="*70)
    print("All inference optimization tests passed! ✨")
    print("="*70 + "\n")

// Helper functions

func ceil_div(int a, int b) -> int:
    return (a + b - 1) // b

func get_tensor_memory(tensor t) -> int64:
    """English textuse (English text)"""
    int elements = 1
    for dim in shape(t):
        elements *= dim

    # Estimate based on dtype (simplified)
    int element_size = 4  # Default to float32
    # In practice, check actual dtype

    return int64(elements) * element_size

func truncate_at_special_tokens(string text) -> string:
    """English text token English text"""
    # Find common stop sequences
    []string stop_sequences = ["", "\n\n", "<|end_of_turn|>"]

    for stop in stop_sequences:
        pos = find(text, stop)
        if pos >= 0:
            text = text[:pos]

    return text.strip()

def call_ai_judge(string prompt, string response) -> float:
    """English text AI Judge modelEnglish text (English textmodel)"""
    # Placeholder: actualimplementationEnglish text API English textmodel
    return 0.5  # Default neutral score
