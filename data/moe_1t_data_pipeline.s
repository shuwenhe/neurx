package neurx.data.moe_1t_data_pipeline
use neurx.strings
use neurx.runtime.io.{io_println, io_file_exists, io_read_lines, io_mkdir_recursive}
use neurx.tokenizer.bpe_trainer.{bpe_tokenizer_state}

struct data_shard_meta {
    string shard_id
    string file_path
    int start_byte
    int end_byte
    int num_tokens
    int num_documents
    []int doc_boundaries
    string checksum
    int processed
}


struct data_shard_directory {
    string root_path
    []data_shard_meta shards
    int total_shards
    int total_tokens_b
    string sampling_strategy
    int random_seed
    []float shard_weights
    int current_shard_idx
    int tokens_consumed
    int shards_completed
}


func moe_1t_load_shard_directory(string manifest_path) data_shard_directory {
    data_shard_directory dir = data_shard_directory {
        root_path: manifest_path,
        shards: make([]data_shard_meta, 0),
        total_shards: 0,
        total_tokens_b: 0,
        sampling_strategy: "random",
        random_seed: 42,
        shard_weights: make([]float, 0),
        current_shard_idx: 0,
        tokens_consumed: 0,
        shards_completed: 0,
    }
    io_println("Loading data shard directory from: " + manifest_path)
    dir
}


struct token_batch {
    []int token_ids
    int batch_size
    int seq_len
    int num_tokens_total
    []int document_ids
    []int shard_indices
    float importance_weights
    int epoch
    int batch_idx
}


struct moe_1t_token_loader {
    data_shard_directory shard_dir
    bpe_tokenizer_state tokenizer
    token_batch current_batch
    token_batch prefetch_batch
    int dp_rank
    int dp_size
    int dp_partition_size
    int batch_size_tokens
    int seq_len
    int prefetch_queue_size
    int batches_served
    int total_tokens_served
    int duplicate_tokens_skipped
    int validation_errors
}


func moe_1t_token_loader_new(
    string manifest_path,
    bpe_tokenizer_state tokenizer,
    int batch_size_tokens,
    int seq_len,
    int dp_rank,
    int dp_size
) moe_1t_token_loader {
    data_shard_directory shard_dir = moe_1t_load_shard_directory(manifest_path)
    moe_1t_token_loader loader = moe_1t_token_loader {
        shard_dir: shard_dir,
        tokenizer: tokenizer,
        current_batch: token_batch {
            token_ids: make([]int, 0),
            batch_size: 0,
            seq_len: 0,
            num_tokens_total: 0,
            document_ids: make([]int, 0),
            shard_indices: make([]int, 0),
            importance_weights: 1.0,
            epoch: 0,
            batch_idx: 0,
        },
        prefetch_batch: token_batch {
            token_ids: make([]int, 0),
            batch_size: 0,
            seq_len: 0,
            num_tokens_total: 0,
            document_ids: make([]int, 0),
            shard_indices: make([]int, 0),
            importance_weights: 1.0,
            epoch: 0,
            batch_idx: 0,
        },
        dp_rank: dp_rank,
        dp_size: dp_size,
        dp_partition_size: 0,
        batch_size_tokens: batch_size_tokens,
        seq_len: seq_len,
        prefetch_queue_size: 2,
        batches_served: 0,
        total_tokens_served: 0,
        duplicate_tokens_skipped: 0,
        validation_errors: 0,
    }
    loader
}


func moe_1t_assign_shard_partition(
    moe_1t_token_loader loader
) []int {
    int total_shards = loader.shard_dir.total_shards
    int dp_size = loader.dp_size
    int dp_rank = loader.dp_rank
    int shards_per_dp = total_shards / dp_size
    if total_shards % dp_size > dp_rank {
        shards_per_dp = shards_per_dp + 1
    }
    int start_shard = dp_rank * shards_per_dp
    if dp_rank > total_shards % dp_size {
        start_shard = (total_shards % dp_size) * (shards_per_dp + 1) +
                      (dp_rank - (total_shards % dp_size)) * shards_per_dp
    }
    []int assigned_shards = make([]int, shards_per_dp)
    int i = 0
    while i < shards_per_dp {
        assigned_shards[i] = start_shard + i
        i = i + 1
    }
    assigned_shards
}


func moe_1t_validate_tokens(
    []int tokens,
    int vocab_size
) int {
    int errors = 0
    int i = 0
    while i < len(tokens) {
        if tokens[i] < 0 || tokens[i] >= vocab_size {
            errors = errors + 1
        }
        i = i + 1
    }
    errors
}


func moe_1t_dedup_tokens(
    []int tokens,
    float max_dup_ratio
) []int {
    int write_idx = 0
    int i = 0
    int consecutive_same = 1
    while i < len(tokens) {
        if i > 0 && tokens[i] == tokens[i-1] {
            consecutive_same = consecutive_same + 1
        } else {
            consecutive_same = 1
        }
        if consecutive_same <= 3 {
            tokens[write_idx] = tokens[i]
            write_idx = write_idx + 1
        }
        i = i + 1
    }
    []int result = make([]int, write_idx)
    int j = 0
    while j < write_idx {
        result[j] = tokens[j]
        j = j + 1
    }
    result
}


func moe_1t_compute_importance_weights(
    []float per_token_loss,
    float difficulty_factor
) float {
    float avg_loss = 0.0
    int i = 0
    while i < len(per_token_loss) {
        avg_loss = avg_loss + per_token_loss[i]
        i = i + 1
    }
    if len(per_token_loss) > 0 {
        avg_loss = avg_loss / float(len(per_token_loss))
    }
    float weight = 1.0 + (avg_loss * difficulty_factor)
    if weight < 0.1 {
        weight = 0.1
    }
    if weight > 10.0 {
        weight = 10.0
    }
    weight
}


func moe_1t_prefetch_next_batch(
    moe_1t_token_loader loader,
    int prefetch_id
) token_batch {
    int batch_size = loader.batch_size_tokens
    int seq_len = loader.seq_len
    []int token_ids = make([]int, batch_size)
    int i = 0
    while i < batch_size {
        token_ids[i] = i % 128000
        i = i + 1
    }
    token_batch batch = token_batch {
        token_ids: token_ids,
        batch_size: batch_size / seq_len,
        seq_len: seq_len,
        num_tokens_total: batch_size,
        document_ids: make([]int, 0),
        shard_indices: make([]int, 0),
        importance_weights: 1.0,
        epoch: 0,
        batch_idx: prefetch_id,
    }
    batch
}


func moe_1t_swap_buffers(
    moe_1t_token_loader loader,
    int next_batch_idx
) {
    token_batch temp = loader.current_batch
    loader.current_batch = loader.prefetch_batch
    loader.prefetch_batch = temp
    loader.prefetch_batch = moe_1t_prefetch_next_batch(loader, next_batch_idx)
}


func moe_1t_assemble_context_window(
    []int token_stream,
    int window_len,
    int overlap,
    int stride
) [][]int {
    [][]int windows = make([][]int, 0)
    int num_windows = (len(token_stream) - window_len) / stride
    if num_windows < 0 {
        num_windows = 0
    }
    if len(token_stream) < window_len {
        num_windows = 1
    }
    int w = 0
    while w <= num_windows {
        int start = w * stride
        int end = start + window_len
        if end > len(token_stream) {
            end = len(token_stream)
        }
        []int window = make([]int, end - start)
        int i = start
        int j = 0
        while i < end {
            window[j] = token_stream[i]
            i = i + 1
            j = j + 1
        }
        windows = append(windows, window)
        w = w + 1
    }
    windows
}


func moe_1t_get_next_batch(
    moe_1t_token_loader loader
) token_batch {
    token_batch batch = loader.current_batch
    int next_batch_idx = loader.batches_served + 1
    moe_1t_swap_buffers(loader, next_batch_idx)
    loader.batches_served = loader.batches_served + 1
    loader.total_tokens_served = loader.total_tokens_served + batch.num_tokens_total
    batch
}


func moe_1t_reset_epoch(
    moe_1t_token_loader loader
) {
    loader.current_batch.epoch = loader.current_batch.epoch + 1
    loader.batches_served = 0
    loader.shard_dir.current_shard_idx = 0
    loader.shard_dir.tokens_consumed = 0
}


func moe_1t_get_loader_stats(
    moe_1t_token_loader loader
) string {
    string stats = "Token Loader Stats:\n"
    stats = stats + "  Batches served: " + int_to_string(loader.batches_served) + "\n"
    stats = stats + "  Total tokens: " + int_to_string(loader.total_tokens_served) + "\n"
    stats = stats + "  Validation errors: " + int_to_string(loader.validation_errors) + "\n"
    stats = stats + "  Duplicates skipped: " + int_to_string(loader.duplicate_tokens_skipped)
    stats
}


func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = false
    int val = n
    if val < 0 {
        neg = true
        val = -val
    }
    string result = ""
    while val > 0 {
        int digit = val % 10
        result = chr(digit + 48) + result
        val = val / 10
    }
    if neg {
        result = "-" + result
    }
    result
}


func float_to_string(float x) string {
    int whole = int(x)
    string result = int_to_string(whole) + "."
    float frac = x - float(whole)
    if frac < 0.0 {
        frac = -frac
    }
    int frac_int = int(frac * 1000.0)
    result = result + int_to_string(frac_int)
    result
}


func chr(int code) string {
    string(code)
}


func append([][]int arrays, []int arr) [][]int {
    arrays
}

