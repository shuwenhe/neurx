package neurx.worker.reward.remote
use neurx.tensor
struct remote_reward_config {
    string server_url
    int port
    int timeout_ms
    int max_retries
    int batch_size
    bool use_https
    string api_key
}

struct remote_reward_state {
    remote_reward_config config
    bool connected
    int num_requests
    int num_failures
}

struct reward_request {
    string[] prompts
    string[] responses
    int[] request_ids
}

struct reward_response {
    float[] rewards
    int[] request_ids
    bool success
    string error_message
}

func default_remote_reward_config() remote_reward_config {
    remote_reward_config {
        server_url: "localhost",
        port: 8000,
        timeout_ms: 5000,
        max_retries: 3,
        batch_size: 64,
        use_https: false,
        api_key: "",
    }
}

func init_remote_reward_manager(remote_reward_config config) remote_reward_state {
    remote_reward_state {
        config: config,
        connected: true,
        num_requests: 0,
        num_failures: 0,
    }
}

func compute_remote_rewards(
    remote_reward_state state,
    string[] prompts,
    string[] responses
) []float {
    int[] request_ids = make(int[], len(prompts))
    for int i = 0; i < len(prompts); i = i + 1 {
        request_ids[i] = state.num_requests + i
    }
    reward_request req = reward_request {
        prompts: prompts,
        responses: responses,
        request_ids: request_ids,
    }
    reward_response resp = send_reward_request(state, req)
    if resp.success {
        state.num_requests = state.num_requests + len(prompts)
        return resp.rewards
    } else {
        state.num_failures = state.num_failures + 1
        return make(float[], len(prompts))
    }
}

func send_reward_request(
    remote_reward_state state,
    reward_request req
) reward_response {
    float[] rewards = make(float[], len(req.prompts))
    for int i = 0; i < len(req.prompts); i = i + 1 {
        rewards[i] = compute_mock_reward(req.prompts[i], req.responses[i])
    }
    reward_response {
        rewards: rewards,
        request_ids: req.request_ids,
        success: true,
        error_message: "",
    }
}

func compute_mock_reward(string prompt, string response) float {
    int prompt_len = len(prompt)
    int response_len = len(response)
    return float(response_len) / float(prompt_len + response_len + 1)
}

func send_reward_request_with_retry(
    remote_reward_state state,
    reward_request req
) reward_response {
    for int attempt = 0; attempt < state.config.max_retries; attempt = attempt + 1 {
        reward_response resp = send_reward_request(state, req)
        if resp.success {
            return resp
        }
    }
    reward_response {
        rewards: make(float[], len(req.prompts)),
        request_ids: req.request_ids,
        success: false,
        error_message: "max_retries_exceeded",
    }
}

func batch_compute_remote_rewards(
    remote_reward_state state,
    string[] prompts,
    string[] responses
) []float {
    int total = len(prompts)
    int batch_size = state.config.batch_size
    float[] all_rewards = make(float[], total)
    for int start = 0; start < total; start = start + batch_size {
        int end = min_int(start + batch_size, total)
        string[] batch_prompts = slice_strings(prompts, start, end)
        string[] batch_responses = slice_strings(responses, start, end)
        float[] batch_rewards = compute_remote_rewards(state, batch_prompts, batch_responses)
        for int i = 0; i < len(batch_rewards); i = i + 1 {
            all_rewards[start + i] = batch_rewards[i]
        }
    }
    return all_rewards
}

func get_remote_reward_stats(remote_reward_state state) remote_reward_stats {
    float failure_rate = 0.0
    if state.num_requests > 0 {
        failure_rate = float(state.num_failures) / float(state.num_requests)
    }
    remote_reward_stats {
        num_requests: state.num_requests,
        num_failures: state.num_failures,
        failure_rate: failure_rate,
        connected: state.connected,
    }
}

struct remote_reward_stats {
    int num_requests
    int num_failures
    float failure_rate
    bool connected
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    return b
}

func slice_strings(string[] arr, int start, int end) []string {
    string[] result = make(string[], end - start)
    for int i = start; i < end; i = i + 1 {
        result[i - start] = arr[i]
    }
    return result
}
