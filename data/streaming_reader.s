package neurx.data.streaming_reader
use neurx.strings
struct stream_reader_config {
    int64 chunk_size_bytes
    int read_ahead_buffers
    int buffer_size_mb
    bool use_mmap
    bool mmap_populate
    string default_encoding
    bool handle_bom
    bool enable_direct_io
    int io_thread_count
}

func default_tb_stream_reader_config() stream_reader_config {
    stream_reader_config cfg
    cfg.chunk_size_bytes = 256 * 1024 * 1024
    cfg.read_ahead_buffers = 3
    cfg.buffer_size_mb = 300
    cfg.use_mmap = true
    cfg.mmap_populate = false
    cfg.default_encoding = "utf-8"
    cfg.handle_bom = true
    cfg.enable_direct_io = false
    cfg.io_thread_count = 4
    return cfg
}

struct file_metadata {
    string filepath
    int64 file_size_bytes
    int64 file_size_gb
    string encoding
    bool has_bom
    int64 line_count
    int64 estimated_token_count
    string checksum_md5
    float quality_score
}

struct data_chunk {
    int chunk_id
    int64 start_byte_offset
    int64 end_byte_offset
    int64 size_bytes
    []byte raw_data
    bool is_loaded
    bool is_mmap_mapped
    int access_count
    int last_access_time
}

struct streaming_reader_state {
    file_metadata meta
    stream_reader_config config
    []data_chunk chunks
    int num_chunks
    int current_chunk_idx
    int max_loaded_chunks
    []int loaded_chunk_indices
    int64 current_byte_pos
    int current_line_in_chunk
    int total_lines_processed
    int total_tokens_processed
    bool is_initialized
    bool end_of_file_reached
    bool error_state
    string last_error_message
}

func init_streaming_reader(
    string filepath,
    stream_reader_config config
) streaming_reader_state {
    streaming_reader_state reader
    reader.config = config
    reader.current_chunk_idx = 0
    reader.current_byte_pos = 0
    reader.current_line_in_chunk = 0
    reader.total_lines_processed = 0
    reader.total_tokens_processed = 0
    reader.is_initialized = false
    reader.end_of_file_reached = false
    reader.error_state = false
    reader.meta = analyze_file_metadata(filepath, config)
    if reader.meta.file_size_bytes <= 0:
        reader.error_state = true
        reader.last_error_message = "File not found or empty: " + filepath
        return reader
    reader = divide_into_chunks(reader)
    reader.max_loaded_chunks = config.read_ahead_buffers + 2
    reader.is_initialized = true
    return reader
func analyze_file_metadata(string filepath, stream_reader_config config) file_metadata {
    file_metadata meta
    meta.filepath = filepath
    meta.file_size_bytes = get_file_size(filepath)
    meta.file_size_gb = meta.file_size_bytes / (1024 * 1024 * 1024)
    if meta.file_size_bytes > 0:
        []byte header = read_file_header(filepath, 8192)
        (meta.encoding, meta.has_bom) = detect_encoding(header, config.default_encoding)
        if meta.file_size_bytes > 10 * 1024 * 1024:
            (meta.line_count, meta.quality_score) = sample_file_quality(filepath, meta.file_size_bytes)
        else:
            meta.line_count = count_all_lines_small_file(filepath)
            meta.quality_score = 1.0
        meta.estimated_token_count = meta.file_size_bytes / 3
        if meta.file_size_bytes < 100 * 1024 * 1024 * 1024:
            meta.checksum_md5 = compute_file_checksum(filepath)
        else:
            meta.checksum_md5 = "skipped_too_large"
    else:
        meta.encoding = "unknown"
        meta.has_bom = false
        meta.line_count = 0
        meta.estimated_token_count = 0
        meta.quality_score = 0.0
        meta.checksum_md5 = ""
    return meta
func divide_into_chunks(streaming_reader_state reader) streaming_reader_state {
    int64 file_size = reader.meta.file_size_bytes
    int64 chunk_size = reader.config.chunk_size_bytes
    int num_chunks = int(file_size / chunk_size)
    if (file_size - (file_size / chunk_size) * chunk_size) != 0 {
        num_chunks = num_chunks + 1
    }
    if num_chunks == 0:
        num_chunks = 1
    reader.num_chunks = num_chunks
    reader.chunks = []data_chunk{cap: num_chunks}
    int64 current_offset = 0
    int c = 0
    while c < num_chunks:
        data_chunk chunk
        chunk.chunk_id = c
        chunk.start_byte_offset = current_offset
        int64 end_offset = current_offset + chunk_size
        if end_offset >= file_size:
            end_offset = file_size
            reader.end_of_file_reached = true
        else:
            end_offset = find_next_newline(reader.meta.filepath, end_offset)
        chunk.end_byte_offset = end_offset
        chunk.size_bytes = end_offset - current_offset
        chunk.is_loaded = false
        chunk.is_mmap_mapped = false
        chunk.access_count = 0
        chunk.last_access_time = 0
        reader.chunks[c] = chunk
        current_offset = end_offset
        c = c + 1
    reader.loaded_chunk_indices = []int{cap: reader.max_loaded_chunks}
    return reader
struct line_read_result {
    string line_content
    bool success
    bool end_of_chunk
    bool end_of_file
    streaming_reader_state updated_reader
}

func read_next_line(streaming_reader_state reader) line_read_result {
    if !reader.is_initialized or reader.error_state:
        return line_read_result{
            line_content: "",
            success: false,
            end_of_chunk: false,
            end_of_file: true,
            updated_reader: reader
        }
    reader = ensure_chunk_loaded(reader, reader.current_chunk_idx)
    if reader.error_state:
        return line_read_result{
            line_content: "",
            success: false,
            end_of_chunk: false,
            end_of_file: true,
            updated_reader: reader
        }
    data_chunk current_chunk = reader.chunks[reader.current_chunk_idx]
    string line
    bool line_found
    bool chunk_exhausted
    (line, line_found, chunk_exhausted) = extract_line_from_chunk(
        current_chunk,
        reader.current_line_in_chunk
    )
    if !line_found:
        if reader.current_chunk_idx >= reader.num_chunks - 1:
            return line_read_result{
                line_content: "",
                success: false,
                end_of_chunk: true,
                end_of_file: true,
                updated_reader: reader
            }
        else:
            reader.current_chunk_idx = reader.current_chunk_idx + 1
            reader.current_line_in_chunk = 0
            return read_next_line(reader)
    reader.current_line_in_chunk = reader.current_line_in_chunk + 1
    reader.total_lines_processed = reader.total_lines_processed + 1
    reader.current_byte_pos = current_chunk.start_byte_offset + get_line_byte_offset(current_chunk, reader.current_line_in_chunk - 1)
    reader.chunks[reader.current_chunk_idx].access_count =
        reader.chunks[reader.current_chunk_idx].access_count + 1
    reader.chunks[reader.current_chunk_idx].last_access_time = get_current_time_ms()
    return line_read_result{
        line_content: line,
        success: true,
        end_of_chunk: chunk_exhausted,
        end_of_file: false,
        updated_reader: reader
    }
func ensure_chunk_loaded(streaming_reader_state reader, int chunk_idx) streaming_reader_state {
    if chunk_idx < 0 or chunk_idx >= reader.num_chunks:
        reader.error_state = true
        reader.last_error_message = "Invalid chunk index: " + chunk_idx
        return reader
    data_chunk target = reader.chunks[chunk_idx]
    if target.is_loaded:
        move_to_front_of_lru(reader.loaded_chunk_indices, chunk_idx)
        return reader
    if len(reader.loaded_chunk_indices) >= reader.max_loaded_chunks:
        int victim_idx = reader.loaded_chunk_indices[len(reader.loaded_chunk_indices) - 1]
        unload_chunk(reader, victim_idx)
    reader = load_chunk_from_disk(reader, chunk_idx)
    return reader
func load_chunk_from_disk(streaming_reader_state reader, int chunk_idx) streaming_reader_state {
    data_chunk chunk = reader.chunks[chunk_idx]
    if reader.config.use_mmap and chunk.size_bytes > 100 * 1024 * 1024:
        chunk.raw_data = mmap_region(reader.meta.filepath, chunk.start_byte_offset, chunk.size_bytes)
        chunk.is_mmap_mapped = true
    else:
        chunk.raw_data = read_file_range(
            reader.meta.filepath,
            chunk.start_byte_offset,
            chunk.size_bytes
        )
        chunk.is_mmap_mapped = false
    chunk.is_loaded = true
    reader.chunks[chunk_idx] = chunk
    insert_at_front_of_lru(reader.loaded_chunk_indices, chunk_idx)
    return reader
func unload_chunk(streaming_reader_state reader, int chunk_idx) streaming_reader_state {
    data_chunk chunk = reader.chunks[chunk_idx]
    if chunk.is_mmap_mapped:
        unmap_region(chunk.raw_data)
    else:
        chunk.raw_data = []byte{cap: 0}
    chunk.is_loaded = false
    reader.chunks[chunk_idx] = chunk
    remove_from_lru(reader.loaded_chunk_indices, chunk_idx)
    return reader
struct batch_read_result {
    []string lines
    int count
    bool end_of_file
    streaming_reader_state updated_reader
}

func read_batch_of_lines(
    streaming_reader_state reader,
    int batch_size
) batch_read_result {
    []string batch_lines = []string{cap: batch_size}
    int count = 0
    bool eof = false
    while count < batch_size and !eof:
        line_read_result result = read_next_line(reader)
        reader = result.updated_reader
        if result.success:
            batch_lines.push(result.line_content)
            count = count + 1
        elif result.end_of_file:
            eof = true
        else:
            eof = true
    batch_read_result{
        lines: batch_lines,
        count: count,
        end_of_file: eof,
        updated_reader: reader
    }
func seek_to_approximate_line(
    streaming_reader_state reader,
    int target_line_number
) streaming_reader_state {
    float lines_per_chunk = float(reader.meta.line_count) / float(reader.num_chunks)
    int estimated_chunk = int(float(target_line_number) / lines_per_chunk)
    if estimated_chunk < 0:
        estimated_chunk = 0
    if estimated_chunk >= reader.num_chunks:
        estimated_chunk = reader.num_chunks - 1
    reader = ensure_chunk_loaded(reader, estimated_chunk)
    int offset_within_chunk = int(float(target_line_number) - float(estimated_chunk) * lines_per_chunk)
    reader.current_chunk_idx = estimated_chunk
    reader.current_line_in_chunk = offset_within_chunk
    return reader
func reset_reader(streaming_reader_state reader) streaming_reader_state {
    int i = 0
    while i < len(reader.loaded_chunk_indices):
        reader = unload_chunk(reader, reader.loaded_chunk_indices[i])
        i = i + 1
    reader.current_chunk_idx = 0
    reader.current_line_in_chunk = 0
    reader.current_byte_pos = 0
    reader.total_lines_processed = 0
    reader.total_tokens_processed = 0
    reader.end_of_file_reached = false
    return reader
struct reader_progress {
    int64 bytes_processed
    int lines_processed
    int tokens_processed
    float percent_complete
    int current_chunk_id
    float mb_per_second
}

func get_progress(streaming_reader_state reader) reader_progress {
    float percent = 0.0
    if reader.meta.file_size_bytes > 0:
        percent = float(reader.current_byte_pos) / float(reader.meta.file_size_bytes) * 100.0
    reader_progress{
        bytes_processed: reader.current_byte_pos,
        lines_processed: reader.total_lines_processed,
        tokens_processed: reader.total_tokens_processed,
        percent_complete: percent,
        current_chunk_id: reader.current_chunk_idx,
        mb_per_second: 0.0
    }
func get_file_size(string path) int64:
    return 0
func read_file_header(string path, int num_bytes) []byte:
    return []byte{cap: 0}
func detect_encoding([]byte header, string default_enc) (string, bool):
    return (default_enc, false)
func sample_file_quality(string path, int64 size) (int, float):
    return (0, 0.0)
func count_all_lines_small_file(string path) int:
    return 0
func compute_file_checksum(string path) string:
    return ""
func find_next_newline(string path, int64 offset) int64:
    return offset
func extract_line_from_chunk(data_chunk chunk, int line_index) (string, bool, bool):
    return ("", false, false)
func get_line_byte_offset(data_chunk chunk, int line_index) int64:
    return 0
func mmap_region(string path, int64 offset, int64 size) []byte:
    return []byte{cap: 0}
func unmap_region([]byte mapped_data) void:
    return
func read_file_range(string path, int64 offset, int64 size) []byte:
    return []byte{cap: 0}
func move_to_front_of_lru([]int lru_list, int item) void:
    return
func insert_at_front_of_lru([]int lru_list, int item) void:
    return
func remove_from_lru([]int lru_list, int item) void:
    return
func get_current_time_ms() int:
    return 0
