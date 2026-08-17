package neurx.data.dynamic_batching
use neurx.strings

struct packing_config:
    int max_seq_len
    int target_batch_size
    string packing_strategy
    bool enable_cross_sample_packing
    float min_utilization_threshold
    int max_sequences_per_batch
    bool use_length_bucketing
    int num_length_buckets
    int pad_token_id
    bool pad_to_power_of_two
    bool truncate_long_sequences
    bool scale_loss_by_length
    bool apply_position_ids
    bool async_packing
    int prefetch_queue_size

func default_2t_packing_config() packing_config:
    packing_config cfg
    cfg.max_seq_len = 2048
    cfg.target_batch_size = 32
    cfg.packing_strategy = "bin_pack"
    cfg.enable_cross_sample_packing = true
    cfg.min_utilization_threshold = 0.80
    cfg.max_sequences_per_batch = 8
    cfg.use_length_bucketing = true
    cfg.num_length_buckets = 16
    cfg.pad_token_id = 0
    cfg.pad_to_power_of_two = false
    cfg.truncate_long_sequences = true
    cfg.scale_loss_by_length = true
    cfg.apply_position_ids = true
    cfg.async_packing = true
    cfg.prefetch_queue_size = 3
    return cfg

struct packed_batch:
    []int input_ids
    []int attention_masks
    []int position_ids
    []int sample_boundaries
    []float loss_weights
    int num_sequences
    int total_tokens
    int total_slots
    float utilization_ratio
    int max_sequence_in_batch
    []int original_lengths
    []int sequence_indices
    float avg_quality_score
    int batch_id
    bool is_final_in_epoch

struct sequence_buffer:
    int sequence_id
    []int token_ids
    int original_length
    float quality_score
    bool should_truncate

struct bin_packer_state:
    packing_config config
    []sequence_buffer current_bin_contents
    int current_bin_used_tokens
    int current_bin_capacity
    int total_batches_produced
    int total_sequences_processed
    float cumulative_utilization
    int total_padding_wasted
    int total_real_tokens
    []packed_batch output_queue
    int max_queue_size

func new_bin_packer(packing_config config) bin_packer_state:
    bin_packer_state packer
    packer.config = config
    packer.current_bin_contents = []sequence_buffer{cap: config.max_sequences_per_batch}
    packer.current_bin_used_tokens = 0
    packer.current_bin_capacity = config.max_seq_len * config.max_sequences_per_batch
    packer.total_batches_produced = 0
    packer.total_sequences_processed = 0
    packer.cumulative_utilization = 0.0
    packer.total_padding_wasted = 0
    packer.total_real_tokens = 0
    packer.output_queue = []packed_batch{cap: config.prefetch_queue_size}
    packer.max_queue_size = config.prefetch_queue_size
    return packer

struct add_sequence_result:
    bool batch_completed
    packed_batch completed_batch
    bin_packer_state updated_state

func add_sequence(
    bin_packer_state packer,
    sequence_buffer seq
) add_sequence_result:
    add_sequence_result result
    result.batch_completed = false
    result.updated_state = packer
    if len(seq.token_ids) > packer.config.max_seq_len and packer.config.truncate_long_sequences:
        seq.token_ids = seq.token_ids[0:packer.config.max_seq_len]
        seq.should_truncate = true
    int seq_len = len(seq.token_ids)
    if seq_len == 0:
        packer.total_sequences_processed = packer.total_sequences_processed + 1
        result.updated_state = packer
        return result
    bool fits_in_current_bin = can_fit_in_bin(packer, seq_len)
    if !fits_in_current_bin:
        if len(packer.current_bin_contents) > 0:
            packed_batch completed = finalize_current_bin(packer)
            if completed.num_sequences > 0:
                result.batch_completed = true
                result.completed_batch = completed
                packer = update_statistics(packer, completed)
        packer.current_bin_contents = []sequence_buffer{cap: packer.config.max_sequences_per_batch}
        packer.current_bin_used_tokens = 0
    packer.current_bin_contents.push(seq)
    packer.current_bin_used_tokens = packer.current_bin_used_tokens + seq_len
    packer.total_sequences_processed = packer.total_sequences_processed + 1
    packer.total_real_tokens = packer.total_real_tokens + seq_len
    if is_bin_ready_to_finalize(packer):
        packed_batch completed = finalize_current_bin(packer)
        if completed.num_sequences > 0:
            result.batch_completed = true
            result.completed_batch = completed
            packer = update_statistics(packer, completed)
            packer.current_bin_contents = []sequence_buffer{cap: packer.config.max_sequences_per_batch}
            packer.current_bin_used_tokens = 0
    result.updated_state = packer
    return result

func can_fit_in_bin(bin_packer_state packer, int seq_len) bool:
    int potential_new_total = packer.current_bin_used_tokens + seq_len
    if len(packer.current_bin_contents) >= packer.config.max_sequences_per_batch:
        return false
    if potential_new_total > packer.current_bin_capacity:
        return false
    if len(packer.current_bin_contents) > 0:
        float seq_fraction = float(seq_len) / float(potential_new_total)
        if seq_fraction > 0.7 and len(packer.current_bin_contents) < 3:
            return false
    return true

func is_bin_ready_to_finalize(bin_packer_state packer) bool:
    if len(packer.current_bin_contents) == 0:
        return false
    if len(packer.current_bin_contents) >= packer.config.target_batch_size:
        return true
    if packer.current_bin_used_tokens >= packer.current_bin_capacity * 0.95:
        return true
    if len(packer.current_bin_contents) >= packer.config.target_batch_size / 2:
        float util = calculate_current_utilization(packer)
        if util >= packer.config.min_utilization_threshold:
            return True
    return False

func finalize_current_bin(bin_packer_state packer) packed_batch:
    int num_seqs = len(packer.current_bin_contents)
    if num_seqs == 0:
        return empty_packed_batch()
    int max_len = 0
    int i = 0
    while i < num_seqs:
        if len(packer.current_bin_contents[i].token_ids) > max_len:
            max_len = len(packer.current_bin_contents[i].token_ids)
        i = i + 1
    if packer.config.pad_to_power_of_two and max_len > 1:
        max_len = next_power_of_two(max_len)
        if max_len > packer.config.max_seq_len:
            max_len = packer.config.max_seq_len
    int total_slots = num_seqs * max_len
    []int input_ids = []int{cap: total_slots}
    []int attention_masks = []int{cap: total_slots}
    []int position_ids = []int{cap: total_slots}
    []int sample_boundaries = []int{cap: num_seqs + 1}
    []float loss_weights = []float{cap: num_seqs}
    []int original_lengths = []int{cap: num_seqs}
    []int sequence_indices = []int{cap: num_seqs}
    int boundary_pos = 0
    sample_boundaries[0] = boundary_pos
    float total_quality = 0.0
    int real_token_count = 0
    i = 0
    while i < num_seqs:
        sequence_buffer seq = packer.current_bin_contents[i]
        int seq_len = len(seq.token_ids)
        int t = 0
        while t < max_len:
            int global_idx = i * max_len + t
            if t < seq_len:
                input_ids[global_idx] = seq.token_ids[t]
                attention_masks[global_idx] = 1
                position_ids[global_idx] = t
                real_token_count = real_token_count + 1
            else:
                input_ids[global_idx] = packer.config.pad_token_id
                attention_masks[global_idx] = 0
                position_ids[global_idx] = 0
            t = t + 1
        boundary_pos = boundary_pos + max_len
        sample_boundaries[i + 1] = boundary_pos
        if seq_len > 0:
            if packer.config.scale_loss_by_length:
                loss_weights[i] = float(seq_len) / float(max_len)
            else:
                loss_weights[i] = 1.0
        else:
            loss_weights[i] = 0.0
        original_lengths[i] = seq.original_length
        sequence_indices[i] = seq.sequence_id
        total_quality = total_quality + seq.quality_score
        i = i + 1
    float utilization = float(real_token_count) / float(total_slots)
    packed_batch batch
    batch.input_ids = input_ids
    batch.attention_masks = attention_masks
    batch.position_ids = position_ids
    batch.sample_boundaries = sample_boundaries
    batch.loss_weights = loss_weights
    batch.num_sequences = num_seqs
    batch.total_tokens = real_token_count
    batch.total_slots = total_slots
    batch.utilization_ratio = utilization
    batch.max_sequence_in_batch = max_len
    batch.original_lengths = original_lengths
    batch.sequence_indices = sequence_indices
    batch.avg_quality_score = total_quality / float(num_seqs)
    batch.batch_id = packer.total_batches_produced
    batch.is_final_in_epoch = false
    return batch

func update_statistics(bin_packer_state packer, packed_batch batch) bin_packer_state:
    packer.total_batches_produced = packer.total_batches_produced + 1
    packer.total_padding_wasted = packer.total_padding_wasted + (batch.total_slots - batch.total_tokens)
    int n = packer.total_batches_produced
    packer.cumulative_utilization =
        (packer.cumulative_utilization * float(n - 1) + batch.utilization_ratio) / float(n)
    return packer

func calculate_current_utilization(bin_packer_state packer) float:
    if len(packer.current_bin_contents) == 0:
        return 0.0
    int max_len_in_bin = 0
    int i = 0
    while i < len(packer.current_bin_contents):
        if len(packer.current_bin_contents[i].token_ids) > max_len_in_bin:
            max_len_in_bin = len(packer.current_bin_contents[i].token_ids)
        i = i + 1
    if max_len_in_bin == 0:
        return 0.0
    int estimated_total_slots = len(packer.current_bin_contents) * max_len_in_bin
    if estimated_total_slots == 0:
        return 0.0
    return float(packer.current_bin_used_tokens) / float(estimated_total_slots)

struct cross_packed_batch:
    []int input_ids
    []int attention_masks
    []int segment_ids
    []int sample_boundaries
    []float loss_weights
    int num_original_samples
    int total_tokens
    int total_allocated
    float utilization_ratio

func pack_samples_crosswise(
    []sequence_buffer sequences,
    packing_config config,
    int max_combined_length
) cross_packed_batch:
    cross_packed_batch result
    result.input_ids = []int{cap: max_combined_length}
    result.attention_masks = []int{cap: max_combined_length}
    result.segment_ids = []int{cap: max_combined_length}
    result.sample_boundaries = []int{cap: len(sequences) + 1}
    result.loss_weights = []float{cap: len(sequences)}
    int current_pos = 0
    int sample_idx = 0
    int total_real = 0
    float total_quality = 0.0
    result.num_original_samples = 0
    result.sample_boundaries[0] = 0
    int s = 0
    while s < len(sequences) and current_pos < max_combined_length:
        sequence_buffer seq = sequences[s]
        int seq_len = len(seq.token_ids)
        int remaining_space = max_combined_length - current_pos
        if seq_len > remaining_space:
            seq_len = remaining_space
        if seq_len <= 0:
            break
        int t = 0
        while t < seq_len:
            result.input_ids[current_pos + t] = seq.token_ids[t]
            result.attention_masks[current_pos + t] = 1
            result.segment_ids[current_pos + t] = sample_idx
            t = t + 1
        result.sample_boundaries[s + 1] = current_pos + seq_len
        if config.scale_loss_by_length:
            result.loss_weights[s] = float(seq_len) / float(max_combined_length)
        else:
            result.loss_weights[s] = 1.0
        current_pos = current_pos + seq_len
        total_real = total_real + seq_len
        total_quality = total_quality + seq.quality_score
        result.num_original_samples = result.num_original_samples + 1
        sample_idx = sample_idx + 1
        s = s + 1
    while current_pos < max_combined_length:
        result.input_ids[current_pos] = config.pad_token_id
        result.attention_masks[current_pos] = 0
        result.segment_ids[current_pos] = 0
        current_pos = current_pos + 1
    result.total_tokens = total_real
    result.total_allocated = max_combined_length
    result.utilization_ratio = float(total_real) / float(max_combined_length)
    result.avg_quality_score = total_quality / float(max(result.num_original_samples, 1))
    return result

struct packing_statistics:
    int total_batches_produced
    int total_sequences_processed
    float avg_utilization
    float min_utilization
    float max_utilization
    float median_utilization
    int total_padding_tokens
    float padding_percentage
    float gpu_utilization_estimate
    int batches_below_threshold

func get_packing_statistics(bin_packer_state packer) packing_statistics:
    packing_statistics stats
    stats.total_batches_produced = packer.total_batches_produced
    stats.total_sequences_processed = packer.total_sequences_processed
    stats.avg_utilization = packer.cumulative_utilization
    stats.total_padding_tokens = packer.total_padding_wasted
    int total_allocated = packer.total_real_tokens + packer.total_padding_wasted
    if total_allocated > 0:
        stats.padding_percentage = float(packer.total_padding_wasted) / float(total_allocated) * 100.0
    else:
        stats.padding_percentage = 0.0
    stats.gpu_utilization_estimate = packer.cumulative_utilization * 0.95
    return stats

func print_packing_report(packing_statistics stats) void:
    print("\n=== Dynamic Packing Report ===")
    print("Total batches produced: ", stats.total_batches_produced)
    print("Total sequences processed: ", stats.total_sequences_processed)
    print("")
    print("Efficiency Metrics:")
    print("  Average batch utilization: ", stats.avg_utilization * 100, "%")
    print("  Padding wasted: ", stats.padding_percentage, "% of allocated space")
    print("  Estimated GPU utilization: ", stats.gpu_utilization_estimate * 100, "%")
    print("")
    print("Impact Analysis:")
    float wasted_compute_ratio = stats.padding_percentage / 100.0
    float compute_saved = (1.0 - wasted_compute_ratio) * 100.0
    print("  Effective compute saved: ~", compute_saved, "% vs naive padding")
    if stats.avg_utilization > 0.9:
        print("  status: EXCELLENT (enterprise-grade efficiency)")
    elif stats.avg_utilization > 0.8:
        print("  status: GOOD (production-ready)")
    elif stats.avg_utilization > 0.7:
        print("  status: ACCEPTABLE (room for improvement)")
    else:
        print("  status: POOR (review configuration)")

func empty_packed_batch() packed_batch:
    return packed_batch{
        input_ids: []int{cap: 0},
        attention_masks: []int{cap: 0},
        position_ids: []int{cap: 0},
        sample_boundaries: []int{cap: 0},
        loss_weights: []float{cap: 0},
        num_sequences: 0,
        total_tokens: 0,
        total_slots: 0,
        utilization_ratio: 0.0,
        max_sequence_in_batch: 0,
        original_lengths: []int{cap: 0},
        sequence_indices: []int{cap: 0},
        avg_quality_score: 0.0,
        batch_id: -1,
        is_final_in_epoch: false
    }

func next_power_of_two(int n) int:
    if n <= 1:
        return 1
    int p = 1
    while p < n:
        p = p * 2
    return p

func max(int a, int b) int:
    if a > b: return a else: return b

func min(int a, int b) int:
    if a < b: return a else: return b
