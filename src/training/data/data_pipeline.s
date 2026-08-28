package neurx.data.data_pipeline
use neurx.shard.shard_manager.{dataset_manifest, build_training_dataset_manifest, default_training_dataset_path}
use neurx.data.streaming_reader.{batch_read_result, streaming_reader_state, init_streaming_reader, read_batch_of_lines, default_tb_stream_reader_config}
use neurx.data.loader.distributed.{data_shard, distributed_dataloader, distributed_loader_config, create_data_shards, new_distributed_loader_config}
use neurx.tokenizer.data_pipeline.{bpe_tokenizer_state, streaming_encode_state, streaming_batch_result, default_llm_tokenizer_config, init_bpe_tokenizer, init_streaming_encode, streaming_next_batch}
use neurx.data.pipeline.preprocessing.{preprocessing_config, new_preprocessing_config, compute_quality_metrics}
use neurx.data.batch_optimization.{batch_config, optimized_batch, sequence_info, create_dynamic_batch, new_batch_config}
use neurx.runtime.io.{runtime_file_exists, runtime_dir_exists, runtime_read_text_file, runtime_run_command_output, runtime_shell_escape}
struct data_pipeline_config {
    int rank_id
    int world_size
    int batch_size
    int seq_len
    int num_epochs
    string data_dir
    string dataset_path
    bool enable_prefetch
    bool enable_dedup
    bool enable_quality_filter
    bool enable_packing
}
struct data_pipeline {
    dataset_manifest manifest
    string manifest_path
    streaming_reader_state reader
    bpe_tokenizer_state tokenizer
    streaming_encode_state encoder
    distributed_dataloader loader
    preprocessing_config preprocess_cfg
    batch_config batch_cfg
    data_pipeline_config pipeline_cfg
    string[] shard_paths
    int[] shard_order
    int shard_order_index
    int shard_epoch
    int shard_shuffle_seed
    int active_shard_index
    string active_shard_path
    string[] active_documents
    int[] active_token_stream
    int shard_document_cursor
    int shard_token_cursor
    bool shard_finished
    bool end_of_stream
    int batches_yielded
    int tokens_processed
}
struct data_pipeline_stats {
    int batches_total
    int samples_skipped_quality
    int samples_skipped_dedup
    int tokens_total
    float avg_batch_tokens
    int data_pipeline_cache_size_mb
}
struct data_pipeline_batch_result {
    data_pipeline pipeline
    optimized_batch batch
    bool end_of_data
}
func new_data_pipeline_config() data_pipeline_config {
    data_pipeline_config {
        rank_id: 0,
        world_size: 1,
        batch_size: 32,
        seq_len: 2048,
        num_epochs: 1,
        data_dir: "./data",
        dataset_path: "./dataset/pretrain/manifest.json",
        enable_prefetch: true,
        enable_dedup: true,
        enable_quality_filter: true,
        enable_packing: true,
    }
}
func new_training_data_pipeline_config() data_pipeline_config {
    new_data_pipeline_config()
}
func new_data_pipeline(data_pipeline_config cfg) data_pipeline {
    string manifest_path = data_pipeline_resolve_manifest_path(cfg.dataset_path)
    string[] shard_paths = data_pipeline_resolve_shard_paths(manifest_path)
    string dataset_path = data_pipeline_resolve_dataset_path(manifest_path)
    if len(shard_paths) > 0 {
        dataset_path = shard_paths[0]
    }
    dataset_manifest manifest = build_training_dataset_manifest(dataset_path)
    streaming_reader_state reader = init_streaming_reader(
        dataset_path,
        default_tb_stream_reader_config()
    )
    bpe_tokenizer_state tokenizer = init_bpe_tokenizer(default_llm_tokenizer_config())
    streaming_encode_state encoder = init_streaming_encode(
        tokenizer,
        reader,
        cfg.batch_size * cfg.seq_len
    )
    distributed_loader_config loader_cfg = new_distributed_loader_config()
    loader_cfg.batch_size = cfg.batch_size
    loader_cfg.seq_len = cfg.seq_len
    loader_cfg.num_workers = 4
    string shard_dir = dataset_path
    if runtime_file_exists(manifest_path) {
        shard_dir = path_dirname(manifest_path) + "/shard"
    } else if runtime_dir_exists(manifest_path) {
        shard_dir = manifest_path + "/shard"
    }
    []data_shard shards = create_data_shards(shard_dir, cfg.world_size, cfg.rank_id)
    distributed_dataloader loader = new_distributed_dataloader(shards, loader_cfg)
    if len(shard_paths) == 0 {
        shard_paths = string[]{cap: 1}
        shard_paths[0] = dataset_path
    }
    int shard_shuffle_seed = cfg.rank_id * 1009 + cfg.world_size * 313 + len(shard_paths)
    data_pipeline {
        manifest: manifest,
        manifest_path: manifest_path,
        reader: reader,
        tokenizer: tokenizer,
        encoder: encoder,
        loader: loader,
        preprocess_cfg: new_preprocessing_config(),
        batch_cfg: new_batch_config(),
        pipeline_cfg: cfg,
        shard_paths: shard_paths,
        shard_order: data_pipeline_build_shard_order(len(shard_paths), shard_shuffle_seed, 0),
        shard_order_index: 0,
        shard_epoch: 0,
        shard_shuffle_seed: shard_shuffle_seed,
        active_shard_index: 0,
        active_shard_path: data_pipeline_shard_path_at(shard_paths, 0),
        active_documents: string[]{cap: 0},
        active_token_stream: int[]{cap: 0},
        shard_document_cursor: 0,
        shard_token_cursor: 0,
        shard_finished: false,
        end_of_stream: false,
        batches_yielded: 0,
        tokens_processed: 0,
    }
}
func new_training_data_pipeline() data_pipeline {
    new_data_pipeline(new_training_data_pipeline_config())
}
func estimate_text_tokens(string text, int fallback) int {
    int length = len(text)
    if length <= 0 {
        return fallback
    }
    int estimated = length / 4
    if estimated < 1 {
        estimated = 1
    }
    estimated
}
func data_pipeline_trim(string s) string {
    int left = 0
    for left < len(s) && (s[left] == 32 || s[left] == 9 || s[left] == 10 || s[left] == 13) {
        left = left + 1
    }
    int right = len(s) - 1
    for right >= left && (s[right] == 32 || s[right] == 9 || s[right] == 10 || s[right] == 13) {
        right = right - 1
    }
    if right < left {
        return ""
    }
    string out = ""
    int i = left
    for i <= right {
        out = out + chr(s[i])
        i = i + 1
    }
    out
}
func data_pipeline_split_lines(string text) string[] {
    string[] lines = string[]{cap: 1}
    string current = ""
    int i = 0
    for i < len(text) {
        if text[i] == 10 || text[i] == 13 {
            if len(current) > 0 {
                lines = append(lines, current)
                current = ""
            }
        } else {
            current = current + chr(text[i])
        }
        i = i + 1
    }
    if len(current) > 0 {
        lines = append(lines, current)
    }
    lines
}
func data_pipeline_find_substring(string text, string pattern) int {
    if len(pattern) == 0 {
        return 0
    }
    int i = 0
    for i + len(pattern) <= len(text) {
        int j = 0
        for j < len(pattern) && text[i + j] == pattern[j] {
            j = j + 1
        }
        if j == len(pattern) {
            return i
        }
        i = i + 1
    }
    -1
}
func data_pipeline_extract_jsonl_text(string line) string {
    string text = data_pipeline_trim(line)
    if text == "" {
        return ""
    }
    int key_idx = data_pipeline_find_substring(text, "\"text\"")
    if key_idx < 0 {
        return data_pipeline_trim(text)
    }
    int colon_idx = key_idx
    for colon_idx < len(text) && text[colon_idx] != 58 {
        colon_idx = colon_idx + 1
    }
    if colon_idx >= len(text) {
        return data_pipeline_trim(text)
    }
    int i = colon_idx + 1
    for i < len(text) && (text[i] == 32 || text[i] == 9) {
        i = i + 1
    }
    if i >= len(text) {
        return ""
    }
    string value = ""
    if text[i] == 34 {
        i = i + 1
        for i < len(text) {
            if text[i] == 34 {
                break
            }
            if text[i] == 92 && i + 1 < len(text) {
                i = i + 1
            }
            value = value + chr(text[i])
            i = i + 1
        }
        return data_pipeline_trim(value)
    }
    for i < len(text) && text[i] != 44 && text[i] != 125 {
        value = value + chr(text[i])
        i = i + 1
    }
    data_pipeline_trim(value)
}
func data_pipeline_parse_manifest_file(string manifest_path) string[] {
    if !runtime_file_exists(manifest_path) {
        return string[]{cap: 0}
    }
    string text = runtime_read_text_file(manifest_path)
    string[] paths = string[]{cap: 3}
    string[] shard_paths = data_pipeline_extract_json_manifest_paths(text, "file_path")
    if len(shard_paths) > 0 {
        return shard_paths
    }
    string train_path = data_pipeline_extract_json_manifest_value(text, "train", "")
    if data_pipeline_trim(train_path) != "" {
        paths = append(paths, train_path)
    }
    string val_path = data_pipeline_extract_json_manifest_value(text, "val", "")
    if data_pipeline_trim(val_path) != "" {
        paths = append(paths, val_path)
    }
    string test_path = data_pipeline_extract_json_manifest_value(text, "test", "")
    if data_pipeline_trim(test_path) != "" {
        paths = append(paths, test_path)
    }
    paths
}
func data_pipeline_extract_json_manifest_paths(string text, string key) string[] {
    string[] paths = string[]{cap: 16}
    string[] lines = data_pipeline_split_lines(text)
    string needle = "\"" + key + "\""
    int i = 0
    for i < len(lines) {
        string line = data_pipeline_trim(lines[i])
        int key_idx = data_pipeline_find_substring(line, needle)
        if key_idx >= 0 {
            int colon_idx = key_idx + len(needle)
            for colon_idx < len(line) && line[colon_idx] != 58 {
                colon_idx = colon_idx + 1
            }
            if colon_idx < len(line) {
                int value_start = colon_idx + 1
                for value_start < len(line) && (line[value_start] == 32 || line[value_start] == 9) {
                    value_start = value_start + 1
                }
                if value_start < len(line) && line[value_start] == 34 {
                    value_start = value_start + 1
                    string value = ""
                    for value_start < len(line) && line[value_start] != 34 {
                        value = value + chr(line[value_start])
                        value_start = value_start + 1
                    }
                    value = data_pipeline_trim(value)
                    if value != "" {
                        paths = append(paths, value)
                    }
                }
            }
        }
        i = i + 1
    }
    paths
}
func data_pipeline_extract_json_manifest_value(string text, string key, string fallback) string {
    string[] lines = data_pipeline_split_lines(text)
    string needle = "\"" + key + "\""
    int i = 0
    for i < len(lines) {
        string line = data_pipeline_trim(lines[i])
        int key_idx = data_pipeline_find_substring(/home/shuwen/shuwen/train/neurxline, needle)
        if key_idx >= 0 {
            int colon_idx = key_idx + len(needle)
            for colon_idx < len(line) && line[colon_idx] != 58 {
                colon_idx = colon_idx + 1
            }
            if colon_idx < len(line) {
                int value_start = colon_idx + 1
                for value_start < len(line) && (line[value_start] == 32 || line[value_start] == 9) {
                    value_start = value_start + 1
                }
                if value_start < len(line) && line[value_start] == 34 {
                    value_start = value_start + 1
                    string value = ""
                    for value_start < len(line) && line[value_start] != 34 {
                        value = value + chr(line[value_start])
                        value_start = value_start + 1
                    }
                    return value
                }
            }
        }
        i = i + 1
    }
    fallback
}
func data_pipeline_resolve_dataset_path(string source_path) string {
    string path = data_pipeline_trim(source_path)
    if path == "" {
        return default_training_dataset_path()
    }
    if runtime_file_exists(path) {
        if data_pipeline_find_substring(path, ".json") >= 0 {
            string manifest_text = runtime_read_text_file(path)
            string[] shard_paths = data_pipeline_extract_json_manifest_paths(manifest_text, "file_path")
            if len(shard_paths) > 0 {
                return shard_paths[0]
            }
            string train_path = data_pipeline_extract_json_manifest_value(manifest_text, "train", "")
            if data_pipeline_trim(train_path) != "" {
                return train_path
            }
        }
        return path
    }
    default_training_dataset_path()
}
func data_pipeline_resolve_manifest_path(string source_path) string {
    string path = data_pipeline_trim(source_path)
    if path == "" {
        return "./dataset/pretrain/manifest.json"
    }
    if data_pipeline_find_substring(path, ".json") >= 0 {
        return path
    }
    if runtime_dir_exists(path) {
        return path + "/manifest.json"
    }
    path
}
func data_pipeline_resolve_shard_paths(string manifest_path) string[] {
    if runtime_dir_exists(manifest_path) {
        return data_pipeline_parse_directory_shards(manifest_path)
    }
    if runtime_file_exists(manifest_path) {
        return data_pipeline_parse_manifest_file(manifest_path)
    }
    string[]{cap: 0}
}
func data_pipeline_parse_directory_shards(string dir_path) string[] {
    string cmd = "find " + runtime_shell_escape(dir_path) + " -maxdepth 1 -name '*.jsonl' | sort"
    string raw = runtime_run_command_output(cmd)
    string[] paths = string[]{cap: 8}
    string current = ""
    int i = 0
    for i < len(raw) {
        if raw[i] == 10 || raw[i] == 13 {
            if len(current) > 0 {
                paths = append(paths, current)
                current = ""
            }
        } else {
            current = current + chr(raw[i])
        }
        i = i + 1
    }
    if len(current) > 0 {
        paths = append(paths, current)
    }
    paths
}
func data_pipeline_positive_mod(int value, int modulus) int {
    if modulus <= 0 {
        return 0
    }
    int div_result = value / modulus
    int result = value - div_result * modulus
    if result < 0 {
        result = result + modulus
    }
    result
}
func data_pipeline_shuffle_ints(int[] values, int seed) int[] {
    int[] out = int[]{cap: len(values)}
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    int j = len(out) - 1
    int state = seed
    for j > 0 {
        state = state * 1664525 + 1013904223
        int k = data_pipeline_positive_mod(state, j + 1)
        int tmp = out[j]
        out[j] = out[k]
        out[k] = tmp
        j = j - 1
    }
    out
}
func data_pipeline_build_shard_order(int shard_count, int seed, int epoch) int[] {
    if shard_count <= 0 {
        return int[]{cap: 0}
    }
    int[] order = int[]{cap: shard_count}
    int i = 0
    for i < shard_count {
        order[i] = i
        i = i + 1
    }
    data_pipeline_shuffle_ints(order, seed + epoch * 1103515245 + shard_count)
}
func data_pipeline_shard_path_at(string[] paths, int index) string {
    if len(paths) == 0 {
        return ""
    }
    int idx = index
    if idx < 0 {
        idx = 0
    }
    if idx >= len(paths) {
        idx = len(paths) - 1
    }
    if idx < 0 {
        return ""
    }
    paths[idx]
}
func data_pipeline_jsonl_to_documents(string text) string[] {
    string[] lines = data_pipeline_split_lines(text)
    string[] docs = string[]{cap: len(lines)}
    int i = 0
    for i < len(lines) {
        string doc = data_pipeline_extract_jsonl_text(lines[i])
        doc = data_pipeline_trim(doc)
        if doc != "" {
            docs = append(docs, doc)
        }
        i = i + 1
    }
    docs
}
func data_pipeline_documents_to_tokens(string[] documents) int[] {
    int[] tokens = int[]{cap: 0}
    int i = 0
    for i < len(documents) {
        string doc = data_pipeline_trim(documents[i])
        if doc != "" {
            int j = 0
            for j < len(doc) {
                tokens = append(tokens, doc[j])
                j = j + 1
            }
            tokens = append(tokens, 10)
        }
        i = i + 1
    }
    tokens
}
func line_to_sequence_info(string line, int doc_id, int seq_id, int target_seq_len) sequence_info {
    sequence_info {
        doc_id: doc_id,
        seq_id: seq_id,
        num_tokens: estimate_text_tokens(line, target_seq_len),
        loss_weight: 1.0,
    }
}
func token_chunk_to_sequence_info(int token_count, int doc_id, int seq_id, int target_seq_len) sequence_info {
    sequence_info {
        doc_id: doc_id,
        seq_id: seq_id,
        num_tokens: token_count,
        loss_weight: 1.0,
    }
}
func data_pipeline_active_documents_for_shard(string shard_path) string[] {
    if shard_path == "" || !runtime_file_exists(shard_path) {
        return string[]{cap: 0}
    }
    string text = runtime_read_text_file(shard_path)
    if data_pipeline_find_substring(shard_path, ".jsonl") >= 0 {
        return data_pipeline_jsonl_to_documents(text)
    }
    string[] docs = data_pipeline_split_lines(text)
    docs
}
func data_pipeline_refresh_active_shard(data_pipeline pipeline) data_pipeline {
    if len(pipeline.shard_paths) == 0 {
        pipeline.active_shard_index = 0
        pipeline.active_shard_path = ""
        pipeline.active_documents = string[]{cap: 0}
        pipeline.active_token_stream = int[]{cap: 0}
        pipeline.shard_document_cursor = 0
        pipeline.shard_token_cursor = 0
        pipeline.shard_finished = true
        return pipeline
    }
    if data_pipeline_epoch_limit_reached(pipeline) {
        pipeline.active_shard_index = 0
        pipeline.active_shard_path = ""
        pipeline.active_documents = string[]{cap: 0}
        pipeline.active_token_stream = int[]{cap: 0}
        pipeline.shard_document_cursor = 0
        pipeline.shard_token_cursor = 0
        pipeline.shard_finished = true
        pipeline.end_of_stream = true
        return pipeline
    }
    if pipeline.shard_order_index >= len(pipeline.shard_order) {
        pipeline.shard_epoch = pipeline.shard_epoch + 1
        pipeline.shard_order = data_pipeline_build_shard_order(len(pipeline.shard_paths), pipeline.shard_shuffle_seed, pipeline.shard_epoch)
        pipeline.shard_order_index = 0
    }
    int order_idx = pipeline.shard_order_index
    int shard_idx = 0
    if len(pipeline.shard_order) > 0 {
        shard_idx = pipeline.shard_order[order_idx]
    }
    if shard_idx < 0 {
        shard_idx = 0
    }
    if shard_idx >= len(pipeline.shard_paths) {
        shard_idx = len(pipeline.shard_paths) - 1
    }
    pipeline.active_shard_index = shard_idx
    pipeline.active_shard_path = data_pipeline_shard_path_at(pipeline.shard_paths, shard_idx)
    pipeline.active_documents = data_pipeline_active_documents_for_shard(pipeline.active_shard_path)
    pipeline.active_token_stream = data_pipeline_documents_to_tokens(pipeline.active_documents)
    pipeline.shard_document_cursor = 0
    pipeline.shard_token_cursor = 0
    pipeline.shard_finished = false
    pipeline
}
func data_pipeline_epoch_limit_reached(data_pipeline pipeline) bool {
    if pipeline.pipeline_cfg.num_epochs <= 0 {
        return false
    }
    pipeline.shard_epoch >= pipeline.pipeline_cfg.num_epochs
}
func build_empty_optimized_batch() optimized_batch {
    optimized_batch {
        sequences: []sequence_info{cap: 0},
        total_tokens: 0,
        sequences_in_batch: 0,
        avg_loss_weight: 1.0,
    }
}
func get_next_batch_with_state(data_pipeline pipeline) data_pipeline_batch_result {
    data_pipeline_batch_result result
    result.pipeline = pipeline
    result.end_of_data = false
    if pipeline.end_of_stream {
        result.batch = build_empty_optimized_batch()
        result.end_of_data = true
        return result
    }
    if pipeline.pipeline_cfg.dataset_path == "" {
        result.batch = build_empty_optimized_batch()
        result.end_of_data = true
        return result
    }
    if result.pipeline.shard_finished || len(result.pipeline.active_token_stream) == 0 {
        result.pipeline = data_pipeline_refresh_active_shard(result.pipeline)
    }
    []sequence_info sequences = []sequence_info{cap: 0}
    int seq_len = result.pipeline.pipeline_cfg.seq_len
    if seq_len <= 0 {
        seq_len = result.pipeline.batch_cfg.seq_len
    }
    if seq_len <= 0 {
        seq_len = 1
    }
    int target_tokens = result.pipeline.pipeline_cfg.batch_size * seq_len
    int token_idx = result.pipeline.shard_token_cursor
    int seq_id = 0
    for token_idx < len(result.pipeline.active_token_stream) && len(sequences) < result.pipeline.pipeline_cfg.batch_size {
        int remaining = len(result.pipeline.active_token_stream) - token_idx
        int current_len = seq_len
        if remaining < current_len {
            current_len = remaining
        }
        if current_len <= 0 {
            break
        }
        sequences.push(token_chunk_to_sequence_info(
            current_len,
            result.pipeline.tokens_processed + token_idx,
            seq_id,
            seq_len
        ))
        token_idx = token_idx + current_len
        seq_id = seq_id + 1
    }
    if len(sequences) == 0 {
        result.pipeline.shard_finished = true
        result.pipeline.shard_order_index = result.pipeline.shard_order_index + 1
        if result.pipeline.shard_order_index >= len(result.pipeline.shard_order) {
            if data_pipeline_epoch_limit_reached(result.pipeline) {
                result.pipeline.end_of_stream = true
                result.end_of_data = true
                result.batch = build_empty_optimized_batch()
                return result
            }
            result.pipeline.shard_epoch = result.pipeline.shard_epoch + 1
            result.pipeline.shard_order = data_pipeline_build_shard_order(len(result.pipeline.shard_paths), result.pipeline.shard_shuffle_seed, result.pipeline.shard_epoch)
            result.pipeline.shard_order_index = 0
        }
        result.end_of_data = true
        result.batch = build_empty_optimized_batch()
        return result
    }
    if result.pipeline.batch_cfg.enable_packing {
        result.batch = create_dynamic_batch(sequences, target_tokens)
    } else {
        result.batch = create_dynamic_batch(sequences, target_tokens)
    }
    result.pipeline.shard_token_cursor = token_idx
    result.pipeline.batches_yielded = result.pipeline.batches_yielded + 1
    result.pipeline.tokens_processed = result.pipeline.tokens_processed + result.batch.total_tokens
    if result.pipeline.shard_token_cursor >= len(result.pipeline.active_token_stream) {
        result.pipeline.shard_finished = true
        result.pipeline.shard_order_index = result.pipeline.shard_order_index + 1
        if result.pipeline.shard_order_index >= len(result.pipeline.shard_order) {
            if data_pipeline_epoch_limit_reached(result.pipeline) {
                result.pipeline.end_of_stream = true
                result.end_of_data = true
                return result
            }
            result.pipeline.shard_epoch = result.pipeline.shard_epoch + 1
            result.pipeline.shard_order = data_pipeline_build_shard_order(len(result.pipeline.shard_paths), result.pipeline.shard_shuffle_seed, result.pipeline.shard_epoch)
            result.pipeline.shard_order_index = 0
        }
    }
    result.end_of_data = false
    result
}
func get_next_batch(data_pipeline pipeline) optimized_batch {
    get_next_batch_with_state(pipeline).batch
}
func process_epoch(data_pipeline pipeline) data_pipeline {
    data_pipeline current = pipeline
    current.shard_epoch = current.shard_epoch + 1
    current.shard_order = data_pipeline_build_shard_order(len(current.shard_paths), current.shard_shuffle_seed, current.shard_epoch)
    current.shard_order_index = 0
    current = data_pipeline_refresh_active_shard(current)
    current
}
func get_pipeline_stats(data_pipeline pipeline) data_pipeline_stats {
    float avg_tokens = 0.0
    if pipeline.batches_yielded > 0 {
        avg_tokens = (0.0 + pipeline.tokens_processed) / (0.0 + pipeline.batches_yielded)
    }
    data_pipeline_stats {
        batches_total: pipeline.batches_yielded,
        samples_skipped_quality: 0,
        samples_skipped_dedup: 0,
        tokens_total: pipeline.tokens_processed,
        avg_batch_tokens: avg_tokens,
        data_pipeline_cache_size_mb: 0,
    }
}
func warmup_pipeline(data_pipeline pipeline, int num_batches) data_pipeline {
    int i = 0
    data_pipeline current = pipeline
    for i < num_batches {
        data_pipeline_batch_result batch_result = get_next_batch_with_state(current)
        current = batch_result.pipeline
        i = i + 1
    }
    current
}
func create_epoch_iterator(data_pipeline pipeline) int {
    pipeline.shard_epoch
}
func get_rank_data_stats(data_pipeline pipeline) map[string]int {
    map[string]int{
        "rank_id": pipeline.pipeline_cfg.rank_id,
        "world_size": pipeline.pipeline_cfg.world_size,
        "batch_size": pipeline.pipeline_cfg.batch_size,
        "seq_len": pipeline.pipeline_cfg.seq_len,
        "num_epochs": pipeline.pipeline_cfg.num_epochs,
        "shard_count": len(pipeline.shard_paths),
        "active_shard_index": pipeline.active_shard_index,
        "shard_epoch": pipeline.shard_epoch,
        "batches_yielded": pipeline.batches_yielded,
        "tokens_processed": pipeline.tokens_processed,
    }
}
func verify_data_integrity(data_pipeline pipeline) bool {
    if len(pipeline.shard_paths) == 0 {
        return false
    }
    int i = 0
    for i < len(pipeline.shard_paths) {
        if !runtime_file_exists(pipeline.shard_paths[i]) {
            return false
        }
        i = i + 1
    }
    true
}
func reset_pipeline(data_pipeline pipeline) data_pipeline {
    data_pipeline current = pipeline
    current.batches_yielded = 0
    current.tokens_processed = 0
    current.shard_order_index = 0
    current.shard_epoch = 0
    current.shard_order = data_pipeline_build_shard_order(len(current.shard_paths), current.shard_shuffle_seed, 0)
    current = data_pipeline_refresh_active_shard(current)
    current.end_of_stream = false
    current
}
func set_random_seed(data_pipeline pipeline, int seed) data_pipeline {
    data_pipeline current = pipeline
    current.shard_shuffle_seed = seed
    current.shard_order = data_pipeline_build_shard_order(len(current.shard_paths), seed, current.shard_epoch)
    current = data_pipeline_refresh_active_shard(current)
    current
}
func data_pipeline_state_dict(data_pipeline pipeline) data_pipeline {
    data_pipeline {
        manifest: pipeline.manifest,
        manifest_path: pipeline.manifest_path,
        reader: pipeline.reader,
        tokenizer: pipeline.tokenizer,
        encoder: pipeline.encoder,
        loader: pipeline.loader,
        preprocess_cfg: pipeline.preprocess_cfg,
        batch_cfg: pipeline.batch_cfg,
        pipeline_cfg: pipeline.pipeline_cfg,
        shard_paths: pipeline.shard_paths,
        shard_order: pipeline.shard_order,
        shard_order_index: pipeline.shard_order_index,
        shard_epoch: pipeline.shard_epoch,
        shard_shuffle_seed: pipeline.shard_shuffle_seed,
        active_shard_index: pipeline.active_shard_index,
        active_shard_path: pipeline.active_shard_path,
        active_documents: pipeline.active_documents,
        active_token_stream: pipeline.active_token_stream,
        shard_document_cursor: pipeline.shard_document_cursor,
        shard_token_cursor: pipeline.shard_token_cursor,
        shard_finished: pipeline.shard_finished,
        end_of_stream: pipeline.end_of_stream,
        batches_yielded: pipeline.batches_yielded,
        tokens_processed: pipeline.tokens_processed,
    }
}
func data_pipeline_load_state_dict(data_pipeline pipeline, data_pipeline other) data_pipeline {
    del pipeline
    other
}
