package neurx.workers.rollout.sglang
use neurx.tensor

struct sglang_config {
    string model_path
    int tensor_parallel_size
    int max_total_tokens
    int max_running_requests
    float temperature
    float top_p
    int top_k
    bool enable_flashinfer
    bool enable_torch_compile
}

struct sglang_rollout_state {
    sglang_config config
    bool initialized
    int requests_completed
}

struct sglang_request {
    string text
    []int input_ids
    int max_new_tokens
    int request_id
}

struct sglang_response {
    string generated_text
    []int generated_ids
    []float logprobs
    int request_id
    float generation_time
}

func default_sglang_config() sglang_config {
    sglang_config {
        model_path: "",
        tensor_parallel_size: 1,
        max_total_tokens: 16384,
        max_running_requests: 512,
        temperature: 1.0,
        top_p: 1.0,
        top_k: -1,
        enable_flashinfer: true,
        enable_torch_compile: false,
    }
}

func init_sglang_engine(sglang_config config) sglang_rollout_state {
    sglang_rollout_state {
        config: config,
        initialized: true,
        requests_completed: 0,
    }
}

func sglang_generate_batch(
    sglang_rollout_state state,
    []sglang_request requests
) []sglang_response {
    []sglang_response responses = make([]sglang_response, len(requests))
    for int i = 0; i < len(requests); i = i + 1 {
        sglang_request req = requests[i]
        []int gen_ids = make([]int, req.max_new_tokens)
        []float logprobs = make([]float, req.max_new_tokens)
        for int j = 0; j < req.max_new_tokens; j = j + 1 {
            gen_ids[j] = 3000 + j
            logprobs[j] = -0.08 * float(j)
        }
        sglang_response resp = sglang_response {
            generated_text: "",
            generated_ids: gen_ids,
            logprobs: logprobs,
            request_id: req.request_id,
            generation_time: 0.1,
        }
        responses[i] = resp
    }
    return responses
}

func sglang_update_weights(sglang_rollout_state state, string new_model_path) {
}
