package v1

type request_status string

const (
    status_pending      request_status = "pending"
    status_running      request_status = "running"
    status_completed    request_status = "completed"
    status_aborted      request_status = "aborted"
    status_failed       request_status = "failed"
)

type sampling_method string

const (
    method_greedy       sampling_method = "greedy"
    method_top_k        sampling_method = "top_k"
    method_top_p        sampling_method = "top_p"
    method_temperature  sampling_method = "temperature"
    method_beam_search  sampling_method = "beam_search"
)

struct sampling_params {
    sampling_method method
    float32 temperature
    int32 top_k
    float32 top_p
    float32 frequency_penalty
    float32 presence_penalty
    float32 repetition_penalty
    int32 max_tokens
    bool ignore_eos
    vec[int32] stop_token_ids
    string stop_str
    bool skip_special_tokens
}

struct request_output {
    string request_id
    vec[string] output_texts
    vec[int32] output_token_ids
    int32 finish_reason
    bool is_finished
    map[string]interface{} metadata
}

struct v1_request {
    string request_id
    string prompt
    vec[int32] prompt_token_ids

    int32 arrival_time
    int32 start_time
    int32 finish_time

    request_status status

    sampling_params* sampling

    int32 max_tokens
    float32 timeout_seconds

    bool stream
    bool echo_prompt

    vec[string] output_texts
    vec[int32] output_token_ids

    int32 num_completed_tokens
    int32 num_total_tokens

    map[string]interface{} extra_params
}

func create_v1_request(string request_id, string prompt) v1_request* {
    req := &v1_request{
        request_id: request_id,
        prompt: prompt,
        prompt_token_ids: make(vec[int32]),
        arrival_time: 0,
        start_time: 0,
        finish_time: 0,
        status: status_pending,
        sampling: *sampling_params{
            method: method_greedy,
            temperature: 0.8,
            top_k: 50,
            top_p: 0.9,
            frequency_penalty: 0.0,
            presence_penalty: 0.0,
            repetition_penalty: 1.0,
            max_tokens: 512,
            ignore_eos: false,
            stop_token_ids: make(vec[int32]),
            stop_str: "",
            skip_special_tokens: false,
        },
        max_tokens: 512,
        timeout_seconds: 60.0,
        stream: false,
        echo_prompt: false,
        output_texts: make(vec[string]),
        output_token_ids: make(vec[int32]),
        num_completed_tokens: 0,
        num_total_tokens: 0,
        extra_params: make(map[string]interface{}),
    }
    return req
}

func (v1_request* req) set_status(request_status status) {
    req.status = status
}

func (v1_request* req) get_status() request_status {
    return req.status
}

func (v1_request* req) is_finished() bool {
    return req.status == status_completed || req.status == status_failed || req.status == status_aborted
}

func (v1_request* req) get_output() request_output {
    return request_output{
        request_id: req.request_id,
        output_texts: req.output_texts,
        output_token_ids: req.output_token_ids,
        finish_reason: 0,
        is_finished: req.is_finished(),
        metadata: req.extra_params,
    }
}

func (v1_request* req) add_output_token(int32 token_id) {
    req.output_token_ids = append(req.output_token_ids, token_id)
    req.num_completed_tokens = req.num_completed_tokens + 1
}

func (v1_request* req) add_output_text(string text) {
    req.output_texts = append(req.output_texts, text)
}

func (v1_request* req) get_elapsed_time() int32 {
    if req.start_time == 0 {
        return 0
    }
    if req.finish_time == 0 {
        return 0
    }
    return req.finish_time - req.start_time
}
