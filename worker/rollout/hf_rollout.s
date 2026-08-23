package neurx.worker.rollout.hf
use neurx.tensor

struct hf_rollout_config {
    string model_name_or_path
    string device
    int batch_size
    int max_new_tokens
    float temperature
    float top_p
    int top_k
    bool do_sample
    int num_return_sequences
    bool use_cache
}

struct hf_rollout_state {
    hf_rollout_config config
    bool model_loaded
    int num_generations
}

struct hf_generation_request {
    []int input_ids
    int max_new_tokens
    float temperature
    int request_id
}

struct hf_generation_response {
    []int generated_ids
    []float log_probs
    []float scores
    int request_id
    bool finished
}

func default_hf_rollout_config() hf_rollout_config {
    hf_rollout_config {
        model_name_or_path: "",
        device: "cuda",
        batch_size: 32,
        max_new_tokens: 512,
        temperature: 1.0,
        top_p: 1.0,
        top_k: 50,
        do_sample: true,
        num_return_sequences: 1,
        use_cache: true,
    }
}

func init_hf_model(hf_rollout_config config) hf_rollout_state {
    hf_rollout_state {
        config: config,
        model_loaded: true,
        num_generations: 0,
    }
}

func hf_generate_batch(
    hf_rollout_state state,
    []hf_generation_request requests
) []hf_generation_response {
    []hf_generation_response responses = make([]hf_generation_response, len(requests))
    for int i = 0; i < len(requests); i = i + 1 {
        hf_generation_request req = requests[i]
        []int gen_ids = make([]int, req.max_new_tokens)
        []float log_probs = make([]float, req.max_new_tokens)
        []float scores = make([]float, req.max_new_tokens)
        for int j = 0; j < req.max_new_tokens; j = j + 1 {
            gen_ids[j] = 100 + j
            log_probs[j] = -0.2 * float(j)
            scores[j] = 0.9 - 0.01 * float(j)
        }
        hf_generation_response resp = hf_generation_response {
            generated_ids: gen_ids,
            log_probs: log_probs,
            scores: scores,
            request_id: req.request_id,
            finished: true,
        }
        responses[i] = resp
    }
    return responses
}

func hf_generate_with_constraints(
    hf_rollout_state state,
    []hf_generation_request requests,
    [][]int allowed_token_ids
) []hf_generation_response {
    return hf_generate_batch(state, requests)
}

func hf_compute_log_probs(
    hf_rollout_state state,
    []int input_ids,
    []int target_ids
) []float {
    []float log_probs = make([]float, len(target_ids))
    for int i = 0; i < len(target_ids); i = i + 1 {
        log_probs[i] = -0.15
    }
    return log_probs
}

func hf_model_forward(
    hf_rollout_state state,
    []int input_ids
) tensor {
    return zeros([]int{len(input_ids), 32000})
}

func hf_update_generation_config(
    hf_rollout_state state,
    float new_temperature,
    float new_top_p
) hf_rollout_state {
    state.config.temperature = new_temperature
    state.config.top_p = new_top_p
    return state
}
