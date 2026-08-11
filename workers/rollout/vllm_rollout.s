package neurx.workers.rollout.vllm
use neurx.tensor
struct vllm_config {
    string model_path
    int tensor_parallel_size
    int gpu_memory_utilization
    int max_num_seqs
    int max_model_len
    float temperature
    float top_p
    int top_k
    bool use_beam_search
    int block_size
}

struct vllm_rollout_state {
    vllm_config config
    bool initialized
    int num_requests
    int num_tokens_generated
}

struct rollout_request {
    []int prompt_tokens
    int max_new_tokens
    float temperature
    float top_p
    int request_id
}

struct rollout_response {
    []int generated_tokens
    []float log_probs
    int request_id
    bool finished
}

func default_vllm_config() vllm_config {
    vllm_config {
        model_path: "",
        tensor_parallel_size: 1,
        gpu_memory_utilization: 90,
        max_num_seqs: 256,
        max_model_len: 8192,
        temperature: 1.0,
        top_p: 1.0,
        top_k: -1,
        use_beam_search: false,
        block_size: 16,
    }
}

func init_vllm_engine(vllm_config config) vllm_rollout_state {
    vllm_rollout_state {
        config: config,
        initialized: true,
        num_requests: 0,
        num_tokens_generated: 0,
    }
}

func vllm_generate_batch(
    vllm_rollout_state state,
    []rollout_request requests
) []rollout_response {
    []rollout_response responses = make([]rollout_response, len(requests))
    for int i = 0; i < len(requests); i = i + 1 {
        rollout_request req = requests[i]
        rollout_response resp = vllm_generate_single(state, req)
        responses[i] = resp
    }
    return responses
}

func vllm_generate_single(
    vllm_rollout_state state,
    rollout_request request
) rollout_response {
    []int generated = make([]int, request.max_new_tokens)
    []float log_probs = make([]float, request.max_new_tokens)
    for int i = 0; i < request.max_new_tokens; i = i + 1 {
        generated[i] = 1000 + i
        log_probs[i] = -0.1 * float(i)
    }
    rollout_response {
        generated_tokens: generated,
        log_probs: log_probs,
        request_id: request.request_id,
        finished: true,
    }
}

func vllm_get_engine_stats(vllm_rollout_state state) vllm_engine_stats {
    vllm_engine_stats {
        num_requests_running: 0,
        num_requests_waiting: 0,
        num_gpu_blocks_used: 0,
        num_gpu_blocks_free: 1000,
        gpu_cache_usage: 0.0,
    }
}

struct vllm_engine_stats {
    int num_requests_running
    int num_requests_waiting
    int num_gpu_blocks_used
    int num_gpu_blocks_free
    float gpu_cache_usage
}
