package neurx.protocol
import "core"
type request_status int32
const (
    request_status_pending   request_status = iota
    request_status_running
    request_status_completed
    request_status_failed
    request_status_cancelled
    request_status_aborted
)
type finish_reason string
const (
    finish_reason_length    finish_reason = "length"
    finish_reason_stop      finish_reason = "stop"
    finish_reason_error     finish_reason = "error"
    finish_reason_abort     finish_reason = "abort"
    finish_reason_prefix    finish_reason = "prefix"
)
type usage_log_probs = float[]32
struct sampling_params {
    temperature             float32
    top_p                   float32
    top_k                   int32
    top_n_tokens            int32
    max_tokens              int32
    min_tokens              int32
    repetition_penalty      float32
    frequency_penalty       float32
    presence_penalty        float32
    length_penalty          float32
    early_stop              bool
    stop                    string[]
    skip_special_tokens     bool
    spaces_between_special  bool
    seed                    int64
    best_of                 int32
    use_beam_search         bool
    top_n_tokens_per_prompt int32
}

struct log_prob_result {
    token_id        int32
    token_str       string
    logprob         float32
    rank            int32
}

struct usage_log_probs_result {
    prompt_log_probs    []log_prob_result
    output_log_probs    []log_prob_result
}

struct request_output {
    request_id              string
    prompt                  string
    prompt_tokens           int32
    text                    string[]
    token_ids               int[][]32
    cumulative              bool
    finish_reason           finish_reason
    finish_reason_length    int32
    error_message           string
    output_tokens           int32
    total_tokens            int32
    lm_probs                int[]erface{}
    usage_log_probs         usage_log_probs_result
    created_time            int64
    latency_ms              float32
    priority                int32
}

struct request_metadata {
    request_id              string
    prompt_tokens           int32
    total_tokens            int32
    estimated_latency_ms    float32
    arrival_time            int64
}

struct request {
    request_id              string
    prompt                  string
    tokens                  int[]32
    sampling_params         sampling_params
    priority                int32
    status                  request_status
    arrival_time            int64
    start_time              int64
    created_time            int64
    updated_time            int64
    finished_time           int64
    abort_time              int64
    output_tokens           int[]32
    error                   string
    num_scheduled_tokens    int32
    num_computed_tokens     int32
    lora_request            interface{}
    guided_decode_params    interface{}
    stream_interval         int32
}

struct protocol_version {
    major                   int32
    minor                   int32
    patch                   int32
    version_string          string
}

func get_protocol_version() protocol_version {
    return protocol_version{
        major: 1,
        minor: 0,
        patch: 0,
        version_string: "1.0.0",
    }
}

func new_sampling_params() sampling_params {
    return sampling_params{
        temperature: 0.7,
        top_p: 1.0,
        top_k: -1,
        top_n_tokens: 5,
        max_tokens: 1024,
        min_tokens: 0,
        repetition_penalty: 1.0,
        frequency_penalty: 0.0,
        presence_penalty: 0.0,
        length_penalty: 1.0,
        early_stop: false,
        stop: string[]{},
        skip_special_tokens: false,
        spaces_between_special: false,
        seed: 0,
        best_of: 1,
        use_beam_search: false,
        top_n_tokens_per_prompt: 5,
    }
}

func new_request_output(request_id string) request_output {
    return request_output{
        request_id: request_id,
        prompt: "",
        prompt_tokens: 0,
        text: string[]{},
        token_ids: int[][]32{},
        cumulative: false,
        finish_reason: finish_reason_length,
        finish_reason_length: 0,
        error_message: "",
        output_tokens: 0,
        total_tokens: 0,
        lm_probs: int[]erface{}{},
        usage_log_probs: usage_log_probs_result{
            prompt_log_probs: []log_prob_result{},
            output_log_probs: []log_prob_result{},
        },
        created_time: 0,
        latency_ms: 0.0,
        priority: 0,
    }
}

func new_request(request_id string, prompt string) request {
    return request{
        request_id: request_id,
        prompt: prompt,
        tokens: int[]32{},
        sampling_params: new_sampling_params(),
        priority: 0,
        status: request_status_pending,
        arrival_time: 0,
        start_time: 0,
        created_time: 0,
        updated_time: 0,
        finished_time: 0,
        abort_time: 0,
        output_tokens: int[]32{},
        error: "",
        num_scheduled_tokens: 0,
        num_computed_tokens: 0,
        lora_request: nil,
        guided_decode_params: nil,
        stream_interval: 0,
    }
}

func new_request_metadata(request_id string) request_metadata {
    return request_metadata{
        request_id: request_id,
        prompt_tokens: 0,
        total_tokens: 0,
        estimated_latency_ms: 0.0,
        arrival_time: 0,
    }
}

func new_log_prob_result(token_id int32, token_str string, logprob float32, rank int32) log_prob_result {
    return log_prob_result{
        token_id: token_id,
        token_str: token_str,
        logprob: logprob,
        rank: rank,
    }
}

func new_usage_log_probs_result() usage_log_probs_result {
    return usage_log_probs_result{
        prompt_log_probs: []log_prob_result{},
        output_log_probs: []log_prob_result{},
    }
}

func is_request_completed(request* req) bool {
    return req.status == request_status_completed ||
           req.status == request_status_failed ||
           req.status == request_status_cancelled ||
           req.status == request_status_aborted
}

func is_request_running(request* req) bool {
    return req.status == request_status_running
}

func is_request_pending(request* req) bool {
    return req.status == request_status_pending
}

func get_request_status_name(status request_status) string {
    switch status {
        case request_status_pending: return "pending"
        case request_status_running: return "running"
        case request_status_completed: return "completed"
        case request_status_failed: return "failed"
        case request_status_cancelled: return "cancelled"
        case request_status_aborted: return "aborted"
        default: return "unknown"
    }
}

func get_finish_reason_name(reason finish_reason) string {
    if reason == finish_reason_length {
        return "length"
    } else if reason == finish_reason_stop {
        return "stop_token"
    } else if reason == finish_reason_error {
        return "error"
    } else if reason == finish_reason_abort {
        return "abort"
    } else if reason == finish_reason_prefix {
        return "prefix"
    }
    return "unknown"
}

func validate_sampling_params(sampling_params* params) error {
    if params.temperature < 0.0 {
        return "temperature must be >= 0"
    }
    if params.top_p < 0.0 || params.top_p > 1.0 {
        return "top_p must be in range [0, 1]"
    }
    if params.top_k < -1 {
        return "top_k must be >= -1"
    }
    if params.max_tokens < 0 {
        return "max_tokens must be >= 0"
    }
    if params.min_tokens < 0 {
        return "min_tokens must be >= 0"
    }
    if params.min_tokens > params.max_tokens {
        return "min_tokens must be <= max_tokens"
    }
    if params.repetition_penalty < 0.0 {
        return "repetition_penalty must be >= 0"
    }
    nil
}

func request_output_to_string(request_output* output) string {
    result := ""
    result = result + "RequestOutput("
    result = result + "request_id=" + output.request_id + ", "
    result = result + "finish_reason=" + string(output.finish_reason) + ", "
    result = result + "output_tokens=" + string(output.output_tokens) + ", "
    result = result + "total_tokens=" + string(output.total_tokens)
    result = result + ")"
    return result
}

func protocol_info() string {
    version := get_protocol_version()
    info := "NeuRx LLM Protocol v" + version.version_string + "\n"
    info = info + "Request/Response Protocol Definition\n"
    info = info + "Supports: streaming, priority scheduling, log probabilities\n"
    return info
}
