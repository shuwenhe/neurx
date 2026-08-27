package neurx.worker.rollout.trtllm
use neurx.tensor

struct trtllm_config {
    string engine_dir
    int max_batch_size
    int max_input_len
    int max_output_len
    int beam_width
    bool streaming
    int top_k
    float top_p
    float temperature
}

struct trtllm_rollout_state {
    trtllm_config config
    bool initialized
    int num_requests_processed
}

struct trtllm_request {
    int[] input_ids
    int max_new_tokens
    int request_id
}

struct trtllm_response {
    int[] output_ids
    float[] output_log_probs
    int request_id
    bool success
}

func default_trtllm_config() trtllm_config {
    trtllm_config {
        engine_dir: "",
        max_batch_size: 128,
        max_input_len: 2048,
        max_output_len: 2048,
        beam_width: 1,
        streaming: false,
        top_k: 0,
        top_p: 1.0,
        temperature: 1.0,
    }
}

func init_trtllm_engine(trtllm_config config) trtllm_rollout_state {
    trtllm_rollout_state {
        config: config,
        initialized: true,
        num_requests_processed: 0,
    }
}

func trtllm_generate_batch(
    trtllm_rollout_state state,
    []trtllm_request requests
) []trtllm_response {
    []trtllm_response responses = make([]trtllm_response, len(requests))
    for int i = 0; i < len(requests); i = i + 1 {
        trtllm_request req = requests[i]
        int[] output_ids = make(int[], req.max_new_tokens)
        float[] log_probs = make(float[], req.max_new_tokens)
        for int j = 0; j < req.max_new_tokens; j = j + 1 {
            output_ids[j] = 2000 + j
            log_probs[j] = -0.05 * float(j)
        }
        trtllm_response resp = trtllm_response {
            output_ids: output_ids,
            output_log_probs: log_probs,
            request_id: req.request_id,
            success: true,
        }
        responses[i] = resp
    }
    return responses
}

func trtllm_shutdown(trtllm_rollout_state state) {
}
