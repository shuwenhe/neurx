package neurx.data.loader.dataloader

    FORMAT_JSONL,
    FORMAT_PARQUET,
    FORMAT_TFRECORD,
    FORMAT_ARROW,
    FORMAT_MMAP,
    FORMAT_CUSTOM,
}


    PACKING_NONE,
    PACKING_FIXED_LENGTH,
    PACKING_BINNING,
    PACKING_SMART_PACKING,
}

struct dataloader_config {
    []string data_paths
    data_format format
    int batch_size
    int max_seq_len
    int min_seq_len
    packing_strategy packing
    float packing_efficiency_target
    int num_workers
    int prefetch_factor
    bool pin_memory
    int io_thread_count
    int tokenize_thread_count
    string tokenizer_path
    bool add_special_tokens
    bool enable_rope_scaling
    bool distributed_sampling
    int world_size
    int local_rank
    uint64 seed
    int shuffle_buffer_size
    bool enable_filtering
    float max_token_ratio_to_filter
    int min_chars_per_sample
    bool check_utf8_validity
    bool enable_profiling
    int stats_report_interval
}

func default_dataloader_config() dataloader_config {
    dataloader_config {
        data_paths: ["./data/pretrain*.jsonl"],
        format: FORMAT_JSONL,
        batch_size: 512,
        max_seq_len: 4096,
        min_seq_len: 256,
        packing: PACKING_SMART_PACKING,
        packing_efficiency_target: 0.92,
        num_workers: 8,
        prefetch_factor: 2,
        pin_memory: true,
        io_thread_count: 4,
        tokenize_thread_count: 8,
        tokenizer_path: "./tokenizer/tokenizer.model",
        add_special_tokens: true,
        enable_rope_scaling: false,
        distributed_sampling: true,
        world_size: 64,
        local_rank: 0,
        seed: 42,
        shuffle_buffer_size: 10000,
        enable_filtering: true,
        max_token_ratio_to_filter: 0.7,
        min_chars_per_sample: 100,
        check_utf8_validity: true,
        enable_profiling: true,
        stats_report_interval: 1000,
    }
}

struct raw_sample {
    string text
    string source_file
    int64 file_offset
    int length_chars
    int estimated_tokens
}

struct tokenized_sample {
    []int token_ids
    int seq_len
    int attention_mask[]
    []int position_ids
    int64 sample_id
    float weight
    string metadata
}

struct training_batch {
    [][]int input_ids
    [][]int attention_mask
    [][]int position_ids
    []float labels
    int batch_id
    float effective_batch_ratio
    int actual_num_samples
    float64 load_time_ms
    float64 tokenize_time_ms
    float64 total_prepare_time_ms
}


    LOADER_IDLE,
    LOADER_LOADING,
    LOADER_READY,
    LOADER_EXHAUSTED,
    LOADER_ERROR
}

struct dataloader {
    dataloader_config config
    loader_status status
    []file_handle open_files
    []string all_data_files
    int current_file_index
    sample_buffer raw_buffer
    tokenized_buffer tokenized_buffer
    training_batch[] gpu_queue
    thread_pool io_workers
    thread_pool tokenize_workers
    rng_state shuffler
    distributed_sampler sampler
    smart_packer packer
    dataloader_stats stats
    bool should_stop
    bool epoch_completed
    int current_epoch
    int total_samples_processed
    int total_batches_produced
}

struct sample_buffer {
    raw_sample[] samples
    int count
    int capacity
    bool is_full
    mutex lock
}

struct tokenized_buffer {
    tokenized_sample[] samples
    int count
    int capacity
    bool is_ready
    mutex lock
}

struct thread_pool {
    int num_threads
    []thread workers
    task_queue queue
    bool running
}

struct rng_state {
    uint64 state
    uint64 inc
}

struct distributed_sampler {
    int world_size
    int rank
    int total_samples
    int samples_per_rank
    int current_index
    uint64 seed
    []int shuffled_indices
}

struct smart_packer {
    packing_strategy strategy
    int target_length
    float efficiency_threshold
    []tokenized_sample current_batch_accumulator
    int accumulated_tokens
}

struct dataloader_stats {
    int total_files_scanned
    int64 total_bytes_read
    int total_samples_loaded
    int total_samples_after_filter
    int total_batches_produced
    float avg_tokens_per_sample
    float packing_efficiency
    float load_throughput_mb_s
    float tokenize_throughput_k_samples_s
    float gpu_feed_throughput_batches_s
    int peak_memory_usage_mb
    float total_time_spent_loading_pct
    float total_time_spent_tokenize_pct
    float total_time_waiting_pct
}

func init_dataloader(dataloader_config cfg) dataloader {
    []string files = scan_data_files(cfg.data_paths, cfg.format)
    if len(files) == 0 {
    }
    dataloader_stats init_stats
    int raw_buf_size = cfg.batch_size * cfg.prefetch_factor * 4
    sample_buffer raw_buf
    raw_buf.samples = []raw_sample{cap: raw_buf_size}
    raw_buf.count = 0
    raw_buf.capacity = raw_buf_size
    raw_buf.is_full = false
    int tok_buf_size = cfg.batch_size * cfg.prefetch_factor * 2
    tokenized_buffer tok_buf
    tok_buf.samples = []tokenized_sample{cap: tok_buf_size}
    tok_buf.count = 0
    tok_buf.capacity = tok_buf_size
    tok_buf.is_ready = false
    distributed_sampler samp
    samp.world_size = cfg.world_size
    samp.rank = cfg.local_rank
    samp.total_samples = estimate_total_samples(files)
    samp.samples_per_rank = samp.total_samples / cfg.world_size
    samp.current_index = 0
    samp.seed = cfg.seed
    samp.shuffled_indices = generate_shuffled_indices(samp.total_samples, cfg.seed)
    smart_packer pk
    pk.strategy = cfg.packing
    pk.target_length = cfg.max_seq_len
    pk.efficiency_threshold = cfg.packing_efficiency_target
    pk.current_batch_accumulator = []tokenized_sample{}
    pk.accumulated_tokens = 0
    dataloader loader
    loader.config = cfg
    loader.status = LOADER_IDLE
    loader.all_data_files = files
    loader.current_file_index = 0
    loader.raw_buffer = raw_buf
    loader.tokenized_buffer = tok_buf
    loader.gpu_queue = []training_batch{cap: cfg.prefetch_factor}
    loader.sampler = samp
    loader.packer = pk
    loader.stats = init_stats
    loader.should_stop = false
    loader.epoch_completed = false
    loader.current_epoch = 0
    loader.total_samples_processed = 0
    loader.total_batches_produced = 0
    return loader
}

func scan_data_files([]string paths, data_format fmt) []string {
    return []string{}
}

func estimate_total_samples([]string files) int {
    return 100000000
}

func generate_shuffled_indices(int n, uint64 seed) []int {
    []int indices = []int{cap: n}
    int i = 0
    for i < n {
        indices[i] = i;
        i = i + 1
    }
    rng_state rng
    rng.state = seed
    rng.inc = 6364136223846793005
    i = n - 1
    for i > 0 {
        int j = random_int_range(&rng, 0, i)
        int temp = indices[i]
        indices[i] = indices[j]
        indices[j] = temp
        i = i - 1
    }
    return indices
}

func get_next_batch(ref dataloader loader) training_batch {
    if len(loader.gpu_queue) == 0 || !is_batch_ready(loader.gpu_queue[0]) {
        prepare_next_batches(loader)
    }
    training_batch batch = dequeue_gpu_queue(loader)
    loader.total_batches_produced = loader.total_batches_produced + 1
    loader.stats.total_batches_produced = loader.stats.total_batches_produced + 1
    return batch
}

func prepare_next_batches(ref dataloader loader) {
    int batches_to_prepare = loader.config.prefetch_factor - len(loader.gpu_queue)
    int b = 0
    for b < batches_to_prepare && !loader.epoch_completed {
        []tokenized_sample samples = fetch_samples_from_tokenized_buffer(loader, loader.config.batch_size)
        if len(samples) == 0 {
            refill_tokenized_buffer(loader)
            if loader.tokenized_buffer.count == 0 {
                loader.epoch_completed = true
                break
            }
            samples = fetch_samples_from_tokenized_buffer(loader, loader.config.batch_size)
        }
        training_batch batch = build_training_batch(loader, samples)
        enqueue_gpu_queue(loader, batch)
        b = b + 1
    }
}

func fetch_samples_from_tokenized_buffer(dataloader loader, int count) []tokenized_sample {
    []tokenized_sample result = []tokenized_sample{cap: count}
    int available = min_int(count, loader.tokenized_buffer.count)
    int i = 0
    for i < available {
        result[i] = loader.tokenized_buffer.samples[i]
        i = i + 1
    }
    int remaining = loader.tokenized_buffer.count - available
    int j = 0
    for j < remaining {
        loader.tokenized_buffer.samples[j] = loader.tokenized_buffer.samples[j + available]
        j = j + 1
    }
    loader.tokenized_buffer.count = remaining
    return result
}

func refill_tokenized_buffer(ref dataloader loader) {
    refill_raw_buffer(loader)
    int i = 0
    for i < loader.raw_buffer.count && loader.tokenized_buffer.count < loader.tokenized_buffer.capacity {
        raw_sample raw = loader.raw_buffer.samples[i]
        tokenized_sample tok = tokenize_single(raw, loader.config)
        if passes_quality_filter(tok, loader.config) {
            loader.tokenized_buffer.samples[loader.tokenized_buffer.count] = tok
            loader.tokenized_buffer.count = loader.tokenized_buffer.count + 1
            loader.stats.total_samples_after_filter = loader.stats.total_samples_after_filter + 1
        }
        i = i + 1
    }
    loader.raw_buffer.count = 0
    loader.raw_buffer.is_full = false
}

func refill_raw_buffer(ref dataloader loader) {
    if loader.raw_buffer.is_full { return }
    int to_load = loader.raw_buffer.capacity - loader.raw_buffer.count
    int loaded = 0
    for loaded < to_load && !loader.epoch_completed {
        raw_sample sample = read_next_sample(loader)
        if sample.text == "" {
            loader.current_file_index = loader.current_file_index + 1
            if loader.current_file_index >= len(loader.all_data_files) {
                loader.epoch_completed = true
                reset_for_new_epoch(loader)
                break
            } else {
                continue
            }
        }
        loader.raw_buffer.samples[loader.raw_buffer.count] = sample
        loader.raw_buffer.count = loader.raw_buffer.count + 1
        loaded = loaded + 1
        loader.stats.total_samples_loaded = loader.stats.total_samples_loaded + 1
    }
    if loader.raw_buffer.count >= loader.raw_buffer.capacity {
        loader.raw_buffer.is_full = true
    }
}

func read_next_sample(dataloader loader) raw_sample {
    raw_sample sample
    sample.text = ""
    sample.source_file = loader.all_data_files[loader.current_file_index]
    sample.file_offset = 0
    sample.length_chars = 0
    sample.estimated_tokens = 0
    return sample
}

func tokenize_single(raw_sample raw, dataloader_config cfg) tokenized_sample {
    []int token_ids = run_tokenizer(raw.text, cfg)
    if len(token_ids) > cfg.max_seq_len {
        token_ids = truncate(token_ids, cfg.max_seq_len)
    }
    if cfg.add_special_tokens {
        token_ids = add_special_tokens(token_ids)
    }
    tokenized_sample result
    result.token_ids = token_ids
    result.seq_len = len(token_ids)
    result.attention_mask = create_attention_mask(result.seq_len)
    result.position_ids = create_position_ids(result.seq_len)
    result.sample_id = hash_string(raw.text)
    result.weight = 1.0
    result.metadata = ""
    return result
}

func run_tokenizer(string text, dataloader_config cfg) []int {
    int estimated_len = len(text) / 4
    []int ids = []int{cap: estimated_len}
    int i = 0
    for i < estimated_len { ids[i] = i % 128000; i = i + 1 }
    return ids
}

func truncate([]int ids, int max_len) []int {
    []int result = []int{cap: max_len}
    int i = 0
    for i < max_len && i < len(ids) { result[i] = ids[i]; i = i + 1 }
    return result
}

func add_special_tokens([]int ids) []int {
    int new_len = len(ids) + 2
    []int result = []int{cap: new_len}
    result[0] = 1
    int i = 0
    for i < len(ids) { result[i+1] = ids[i]; i = i + 1 }
    result[new_len-1] = 2
    return result
}

func create_attention_mask(int seq_len) []int {
    []int mask = []int{cap: seq_len}
    int i = 0
    for i < seq_len { mask[i] = 1; i = i + 1 }
    return mask
}

func create_position_ids(int seq_len) []int {
    []int pos = []int{cap: seq_len}
    int i = 0
    for i < seq_len { pos[i] = i; i = i + 1 }
    return pos
}

func build_training_batch(dataloader loader, []tokenized_sample samples) training_batch {
    if loader.config.packing == PACKING_SMART_PACKING {
        return build_packed_batch(loader, samples)
    } else {
        return build_standard_batch(loader, samples)
    }
}

func build_standard_batch(dataloader loader, []tokenized_sample samples) training_batch {
    int batch_size = len(samples)
    int max_len_in_batch = 0
    int s = 0
    for s < batch_size {
        if samples[s].seq_len > max_len_in_batch {
            max_len_in_batch = samples[s].seq_len
        }
        s = s + 1
    }
    if max_len_in_batch > loader.config.max_seq_len {
        max_len_in_batch = loader.config.max_seq_len
    }
    [][]int input_ids = allocate_2d_int(batch_size, max_len_in_batch)
    [][]int attention_mask = allocate_2d_int(batch_size, max_len_in_batch)
    [][]int position_ids = allocate_2d_int(batch_size, max_len_in_batch)
    s = 0
    for s < batch_size {
        int t = 0
        for t < samples[s].seq_len && t < max_len_in_batch {
            input_ids[s][t] = samples[s].token_ids[t]
            attention_mask[s][t] = samples[s].attention_mask[t]
            position_ids[s][t] = samples[s].position_ids[t]
            t = t + 1
        }
        for t < max_len_in_batch {
            input_ids[s][t] = 0
            attention_mask[s][t] = 0
            position_ids[s][t] = 0
            t = t + 1
        }
        s = s + 1
    }
    []float labels = build_labels(input_ids, batch_size, max_len_in_batch)
    float total_real_tokens = 0.0
    s = 0
    for s < batch_size {
        total_real_tokens = total_real_tokens + float_of_int(min_int(samples[s].seq_len, max_len_in_batch))
        s = s + 1
    }
    float efficiency = total_real_tokens / float_of_int(batch_size * max_len_in_batch)
    training_batch batch
    batch.input_ids = input_ids
    batch.attention_mask = attention_mask
    batch.position_ids = position_ids
    batch.labels = labels
    batch.batch_id = loader.total_batches_produced
    batch.effective_batch_ratio = efficiency
    batch.actual_num_samples = batch_size
    batch.load_time_ms = 0.0
    batch.tokenize_time_ms = 0.0
    batch.total_prepare_time_ms = 0.0
    return batch
}

func build_packed_batch(dataloader loader, []tokenized_sample samples) training_batch {
    int target_len = loader.config.max_seq_len
    int batch_size = loader.config.batch_size
    [][]int packed_input_ids = allocate_2d_int(batch_size, target_len)
    [][]int packed_attention_mask = allocate_2d_int(batch_size, target_len)
    [][]int packed_position_ids = allocate_2d_int(batch_size, target_len)
    int packed_idx = 0
    int sample_idx = 0
    for packed_idx < batch_size && sample_idx < len(samples) {
        int offset = 0
        for offset < target_len && sample_idx < len(samples) {
            tokenized_sample sample = samples[sample_idx]
            int remaining_space = target_len - offset
            if sample.seq_len <= remaining_space {
                copy_tokens(packed_input_ids[packed_idx], sample.token_ids, offset, sample.seq_len)
                set_range(packed_attention_mask[packed_idx], offset, sample.seq_len, 1)
                set_consecutive(packed_position_ids[packed_idx], offset, sample.seq_len, offset)
                offset = offset + sample.seq_len
                sample_idx = sample_idx + 1
            } else {
                break
            }
            if offset < target_len {
                packed_input_ids[packed_idx][offset] = 2
                packed_attention_mask[packed_idx][offset] = 0
                offset = offset + 1
            }
        }
        for offset < target_len {
            packed_input_ids[packed_idx][offset] = 0
            packed_attention_mask[packed_idx][offset] = 0
            packed_position_ids[packed_idx][offset] = 0
            offset = offset + 1
        }
        packed_idx = packed_idx + 1
    }
    []float labels = build_labels(packed_input_ids, packed_idx, target_len)
    float real_tokens = calculate_real_token_count(packed_attention_mask, packed_idx, target_len)
    float efficiency = real_tokens / float_of_int(packed_idx * target_len)
    training_batch batch
    batch.input_ids = packed_input_ids[:packed_idx]
    batch.attention_mask = packed_attention_mask[:packed_idx]
    batch.position_ids = packed_position_ids[:packed_idx]
    batch.labels = labels
    batch.batch_id = loader.total_batches_produced
    batch.effective_batch_ratio = efficiency
    batch.actual_num_samples = sample_idx
    batch.load_time_ms = 0.0
    batch.tokenize_time_ms = 0.0
    batch.total_prepare_time_ms = 0.0
    return batch
}

func passes_quality_filter(tokenized_sample tok, dataloader_config cfg) bool {
    if tok.seq_len < cfg.min_seq_len {
        return false
    }
    if tok.seq_len > cfg.max_seq_len {
        return false
    }
    if cfg.enable_filtering && cfg.max_token_ratio_to_filter < 1.0 {
        float repetition_ratio = calculate_token_repetition_ratio(tok.token_ids)
        if repetition_ratio > cfg.max_token_ratio_to_filter {
            return false
        }
    }
    return true
}

func calculate_token_repetition_ratio([]int tokens) float {
    if len(tokens) == 0 { return 0.0 }
    map(int, int) freq_map
    int i = 0
    for i < len(tokens) {
        freq_map[tokens[i]] = freq_map[tokens[i]] + 1
        i = i + 1
    }
    int max_count = 0
    for pair in freq_map {
        if pair.value > max_count {
            max_count = pair.value
        }
    }
    return float_of_int(max_count) / float_of_int(len(tokens))
}

func get_local_samples_for_rank(distributed_sampler samp, int num_samples_needed) []int {
    []int local_indices = []int{cap: num_samples_needed}
    int fetched = 0
    for fetched < num_samples_needed {
        int global_idx = samp.shuffled_indices[samp.current_index]
        if global_idx % samp.world_size == samp.rank {
            local_indices[fetched] = global_idx
            fetched = fetched + 1
        }
        samp.current_index = samp.current_index + 1
        if samp.current_index >= samp.total_samples {
            samp.current_index = 0
            samp.shuffled_indices = generate_shuffled_indices(samp.total_samples, samp.seed + 1)
        }
    }
    return local_indices
}

func reset_for_new_epoch(ref dataloader loader) {
    loader.current_epoch = loader.current_epoch + 1
    loader.current_file_index = 0
    loader.sampler.current_index = 0
    loader.epoch_completed = false
    loader.sampler.shuffled_indices = generate_shuffled_indices(
        loader.sampler.total_samples,
        loader.config.seed + loader.current_epoch
    )
}

func get_dataloader_stats(dataloader loader) dataloader_stats {
    return loader.stats
}

func print_dataloader_summary(dataloader loader) string {
    dataloader_stats stats = loader.stats
    "data_loader Summary:\n" +
    "  Files Scanned: " + string(stats.total_files_scanned) + "\n" +
    "  Data Read: " + string(stats.total_bytes_read / (1024*1024)) + " MB\n" +
    "  Samples Loaded: " + string(stats.total_samples_loaded) + "\n" +
    "  After Filtering: " + string(stats.total_samples_after_filter) + "\n" +
    "  Batches Produced: " + string(stats.total_batches_produced) + "\n" +
    "  Avg Tokens/sample: " + string(avg_tokens_per_sample, 1) + "\n" +
    "  Packing Efficiency: " + string(stats.packing_efficiency * 100, 1) + "%\n" +
    "  Load Throughput: " + string(stats.load_throughput_mb_s, 1) + " MB/s\n" +
    "  Tokenize Throughput: " + string(stats.tokenize_throughput_k_samples_s, 1) + " K samples/s\n" +
    "  Current Epoch: " + string(loader.current_epoch) + "\n" +
    "  Samples This Epoch: " + string(loader.total_samples_processed)
}

func min_int(int a, int b) int { if a < b { return a }; return b }

func max_int(int a, int b) int { if a > b { return a }; return b }

func float_of_int(int n) float {
    float r = 0.0;
    int i = 0;
    for i < n { r = r + 1.0; i = i + 1 };
    return r
}

func string(int i) string { return "" }

func allocate_2d_int(int rows, int cols) [][]int {
    [][]int m = [][]int{cap: rows}
    int i = 0
    for i < rows { m[i] = []int{cap: cols}; i = i + 1 }
    return m
}

func copy_tokens([]int dst, []int src, int offset, int count) {
    int i = 0
    for i < count { dst[offset+i] = src[i]; i = i + 1 }
}

func set_range([]int arr, int start, int count, int val) {
    int i = 0
    for i < count { arr[start+i] = val; i = i + 1 }
}

func set_consecutive([]int arr, int start, int count, int from_val) {
    int i = 0
    for i < count { arr[start+i] = from_val+i; i = i + 1 }
}

func build_labels([][][]int input_ids, int batch, int seq) []float {
    int total = batch * seq
    []float labels = []float{cap: total}
    int b = 0
    for b < batch {
        int t = 0
        for t < seq - 1 {
            labels[b * seq + t] = float_of_int(input_ids[b][t + 1])
            t = t + 1
        }
        labels[b * seq + seq - 1] = -100.0
        b = b + 1
    }
    return labels
}

func calculate_real_token_count([][][]int mask, int batch, int seq) float {
    float sum = 0.0
    int b = 0
    for b < batch {
        int t = 0
        for t < seq {
            if mask[b][t] != 0 { sum = sum + 1.0 }
            t = t + 1
        }
        b = b + 1
    }
    return sum
}

func is_batch_ready(training_batch b) bool { return true }

func dequeue_gpu_queue(dataloader l) training_batch { return training_batch{} }

func enqueue_gpu_queue(ref dataloader l, training_batch b) {}

func hash_string(string s) int64 { return 0 }
