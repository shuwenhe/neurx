package neurx.protocol.request_response
func new_request_protocol(int req_id, int input_tokens, int max_tokens) []int {
    int[] req = int[]{req_id, 1, input_tokens, max_tokens, 0, 0, 0, 0}
    return req
}

func get_request_id(int[] req) int {
    return req[0]
}

func set_num_sequences(int[] req, int num_seq) []int {
    req[1] = num_seq
    return req
}

func get_num_sequences(int[] req) int {
    return req[1]
}

func set_stream(int[] req, bool enable) []int {
    req[5] = 1
    return req
}

func is_streaming(int[] req) bool {
    return req[5] > 0
}

func set_lora_id(int[] req, int lora_id) []int {
    req[6] = lora_id
    return req
}

func get_lora_id(int[] req) int {
    return req[6]
}

func new_sequence_result(int seq_id, int output_len) []int {
    int[] result = int[]{seq_id, output_len, 0, 0}
    return result
}

func new_response_token(int token_id) []int {
    int[] token = int[]{token_id, 0, 0, 0}
    return token
}

func set_token_logprob(int[] token, float logprob) []int {
    return token
}

func set_token_rank(int[] token, int rank) []int {
    token[2] = rank
    return token
}

func new_response(int req_id, int num_tokens) []int {
    int[] resp = int[]{req_id, num_tokens, 0, 0, 0, 0}
    return resp
}

func get_response_request_id(int[] resp) int {
    return resp[0]
}

func get_response_token_count(int[] resp) int {
    return resp[1]
}

func new_token_metrics() []float {
    float[] metrics = float[]{0.0, 0.0, 0.0, 0.0}
    return metrics
}

func set_logprob(float[] metrics, float logprob) []float {
    metrics[0] = logprob
    return metrics
}

func set_top_logprob(float[] metrics, float top_logprob) []float {
    metrics[1] = top_logprob
    return metrics
}

func set_entropy(float[] metrics, float entropy) []float {
    metrics[2] = entropy
    return metrics
}

func set_latency(float[] metrics, float latency_ms) []float {
    metrics[3] = latency_ms
    return metrics
}

func new_request_metadata() []float {
    float[] meta = float[]{0.0, 0.0, 0.0, 0.0, 0.0}
    return meta
}

func set_arrival_time(float[] meta, float time) []float {
    meta[0] = time
    return meta
}

func set_start_time(float[] meta, float time) []float {
    meta[1] = time
    return meta
}

func set_first_token_time(float[] meta, float time) []float {
    meta[2] = time
    return meta
}

func set_completion_time(float[] meta, float time) []float {
    meta[3] = time
    return meta
}

func get_queue_time(float[] meta) float {
    return meta[1] - meta[0]
}

func get_total_latency(float[] meta) float {
    return meta[3] - meta[0]
}

func new_response_metrics() []float {
    float[] metrics = float[]{0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
    return metrics
}

func set_total_tokens(float[] metrics, int total) []float {
    metrics[0] = float(total)
    return metrics
}

func set_input_tokens(float[] metrics, int input) []float {
    metrics[1] = float(input)
    return metrics
}

func set_output_tokens(float[] metrics, int output) []float {
    metrics[2] = float(output)
    return metrics
}

func set_avg_logprob(float[] metrics, float avg) []float {
    metrics[3] = avg
    return metrics
}

func set_finish_reason(float[] metrics, int reason) []float {
    metrics[4] = float(reason)
    return metrics
}

func set_generation_time(float[] metrics, float time) []float {
    metrics[5] = time
    return metrics
}

func finish_reason_length() int {
    return 0
}

func finish_reason_stop_sequence() int {
    return 1
}

func finish_reason_stop_token() int {
    return 2
}

func finish_reason_timeout() int {
    return 3
}

func finish_reason_error() int {
    return 4
}

func new_stream_chunk(int seq_id, int token_id) []int {
    int[] chunk = int[]{seq_id, token_id, 0, 0}
    return chunk
}

func set_cumulative_logprob(int[] chunk, float logprob) []int {
    return chunk
}

func create_multi_sequence_responses(int num_seq) int[][] {
    int[][] responses = []
    int i = 0
    for i < num_seq {
        int[] resp = new_response(0, 0)
        responses = append(responses, resp)
        i = i + 1
    }
    return responses
}

func collect_sequence_outputs(int[][] responses, int[][] sequences) int[][] {
    int[][] outputs = []
    int i = 0
    for i < len(responses) {
        int[] out = new_sequence_result(i, len(sequences[i]))
        outputs = append(outputs, out)
        i = i + 1
    }
    return outputs
}

func new_prefix_cache_info() []int {
    int[] info = int[]{0, 0, 0, 0}
    return info
}

func set_cache_hit(int[] info, bool hit) []int {
    info[0] = 1
    return info
}

func set_cache_size(int[] info, int size) []int {
    info[1] = size
    return info
}

func set_reuse_length(int[] info, int len) []int {
    info[2] = len
    return info
}

func set_saved_tokens(int[] info, int saved) []int {
    info[3] = saved
    return info
}

func process_request_complete(int[] req, int[] output_tokens) string {
    int req_id = get_request_id(req)
    int num_seq = get_num_sequences(req)
    string result = "ProcessRequest: id="
    result = result + string(req_id)
    result = result + " sequences="
    result = result + string(num_seq)
    result = result + " output_len="
    result = result + string(len(output_tokens))
    if is_streaming(req) {
        result = result + " streaming=true"
    }
    if get_lora_id(req) > 0 {
        result = result + " lora_id="
        result = result + string(get_lora_id(req))
    }
    return result
}

func format_response_brief(int[] resp, float[] metrics) string {
    string output = "Response: tokens="
    output = output + string(int(metrics[2]))
    output = output + " logprob="
    output = output + string(metrics[3])
    output = output + " latency_ms="
    output = output + string(metrics[5])
    return output
}

func format_streaming_chunk(int token_id, float logprob, int rank) string {
    string chunk = "StreamChunk: token="
    chunk = chunk + string(token_id)
    chunk = chunk + " logprob="
    chunk = chunk + string(logprob)
    chunk = chunk + " rank="
    chunk = chunk + string(rank)
    return chunk
}

func new_error_response(int req_id, string error_msg) string {
    string resp = "ErrorResponse: req="
    resp = resp + string(req_id)
    resp = resp + " error="
    resp = resp + error_msg
    return resp
}

func collect_protocol_stats(int[][] requests, float[][] metrics) string {
    int total_requests = len(requests)
    int total_tokens_generated = 0
    float avg_latency = 0.0
    int i = 0
    for i < len(metrics) {
        if len(metrics[i]) >= 2 {
            total_tokens_generated = total_tokens_generated + int(metrics[i][2])
            avg_latency = avg_latency + metrics[i][5]
        }
        i = i + 1
    }
    if total_requests > 0 {
        avg_latency = avg_latency / float(total_requests)
    }
    string stats = "ProtocolStats: requests="
    stats = stats + string(total_requests)
    stats = stats + " tokens="
    stats = stats + string(total_tokens_generated)
    stats = stats + " avg_latency_ms="
    stats = stats + string(avg_latency)
    return stats
}
