import "tensor/tensor.s"
import "posttrain/reward/reward_model.s"
struct batch_reward_manager_config {
    batch_size: i32
    max_queue_size: i32
    timeout_ms: i64
    num_workers: i32
    use_gpu: bool
    gpu_device: i32
}

struct reward_request {
    request_id: string
    prompt: tensor
    response: tensor
    callback: fn(f32)
}

struct batch_reward_manager {
    config: batch_reward_manager_config
    reward_model: *Model
    request_queue: []reward_request
    queue_mutex: mutex
    workers: []worker
    total_requests: i64
    total_batches: i64
    avg_batch_size: f32
}
func new_batch_reward_manager(config: batch_reward_manager_config, model: *Model) -> batch_reward_manager {
    let workers: []worker = []
    for i in 0..config.num_workers {
        workers.push(new_worker(i))
    }
    return batch_reward_manager{
        config: config,
        reward_model: model,
        request_queue: [],
        queue_mutex: mutex_new(),
        workers: workers,
        total_requests: 0,
        total_batches: 0,
        avg_batch_size: 0.0,
    }
}

func (manager: *batch_reward_manager) compute_reward_async(
    prompt: tensor,
    response: tensor,
    callback: fn(f32)
) {
    let request = reward_request{
        request_id: generate_uuid(),
        prompt: prompt,
        response: response,
        callback: callback,
    }
    manager.queue_mutex.lock()
    manager.request_queue.push(request)
    manager.total_requests += 1
    manager.queue_mutex.unlock()
    if manager.request_queue.len() >= manager.config.batch_size {
        manager.process_batch()
    }
}

func (manager: *batch_reward_manager) process_batch() {
    manager.queue_mutex.lock()
    if manager.request_queue.len() == 0 {
        manager.queue_mutex.unlock()
        return
    }
    let batch_size = min(manager.config.batch_size, manager.request_queue.len())
    let batch_requests = manager.request_queue[..batch_size]
    manager.request_queue = manager.request_queue[batch_size..]
    manager.queue_mutex.unlock()
    let prompts: []tensor = []
    let responses: []tensor = []
    for req in batch_requests {
        prompts.push(req.prompt)
        responses.push(req.response)
    }
    let batched_prompts = stack_and_pad(prompts)
    let batched_responses = stack_and_pad(responses)
    let inputs = concat(batched_prompts, batched_responses, dim: 1)
    let rewards = manager.reward_model.forward(inputs).squeeze(-1)
    for i, req in batch_requests {
        let reward = rewards[i].item()
        req.callback(reward)
    }
    manager.total_batches += 1
    manager.avg_batch_size = (manager.avg_batch_size * f32(manager.total_batches - 1) +
                              f32(batch_size)) / f32(manager.total_batches)
}

func (manager: *batch_reward_manager) flush() {
    while manager.request_queue.len() > 0 {
        manager.process_batch()
    }
}

struct rate_limited_reward_manager_config {
    max_requests_per_second: f32
    burst_size: i32
    use_token_bucket: bool
}

struct rate_limited_reward_manager {
    config: rate_limited_reward_manager_config
    reward_model: *Model
    tokens: f32
    last_refill_time: i64
    delayed_queue: []delayed_request
    total_requests: i64
    rate_limited_count: i64
}

struct delayed_request {
    request: reward_request
    scheduled_time: i64
}

func new_rate_limited_reward_manager(
    config: rate_limited_reward_manager_config,
    model: *Model
) -> rate_limited_reward_manager {
    return rate_limited_reward_manager{
        config: config,
        reward_model: model,
        tokens: f32(config.burst_size),
        last_refill_time: get_time_ms(),
        delayed_queue: [],
        total_requests: 0,
        rate_limited_count: 0,
    }
}

func (manager: *rate_limited_reward_manager) compute_reward(
    prompt: tensor,
    response: tensor
) -> f32 {
    manager.total_requests += 1
    manager.refill_tokens()
    if manager.tokens >= 1.0 {
        manager.tokens -= 1.0
        return manager.compute_reward_internal(prompt, response)
    } else {
        manager.rate_limited_count += 1
        let wait_time = 1000.0 / manager.config.max_requests_per_second
        sleep_ms(i64(wait_time))
        manager.refill_tokens()
        manager.tokens -= 1.0
        return manager.compute_reward_internal(prompt, response)
    }
}

func (manager: *rate_limited_reward_manager) refill_tokens() {
    let now = get_time_ms()
    let elapsed = f32(now - manager.last_refill_time) / 1000.0
    let tokens_to_add = elapsed * manager.config.max_requests_per_second
    manager.tokens = min(
        manager.tokens + tokens_to_add,
        f32(manager.config.burst_size)
    )
    manager.last_refill_time = now
}

func (manager: *rate_limited_reward_manager) compute_reward_internal(
    prompt: tensor,
    response: tensor
) -> f32 {
    let input = concat(prompt, response)
    let reward = manager.reward_model.forward(input)
    return reward.item()
}

struct dapo_reward_manager_config {
    format_weight: f32
    accuracy_weight: f32
    reasoning_weight: f32
    use_process_reward: bool
    verification_method: string
}

struct dapo_reward_manager {
    config: dapo_reward_manager_config
    format_checker: *format_checker
    accuracy_verifier: *answer_verifier
    reasoning_scorer: *reasoning_scorer
}

func new_dapo_reward_manager(config: dapo_reward_manager_config) -> dapo_reward_manager {
    return dapo_reward_manager{
        config: config,
        format_checker: new_format_checker(),
        accuracy_verifier: new_answer_verifier(config.verification_method),
        reasoning_scorer: new_reasoning_scorer(),
    }
}

func (manager: *dapo_reward_manager) compute_reward(
    prompt: tensor,
    response: tensor,
    ground_truth: string
) -> (f32, map[string]f32) {
    let response_text = decode_tokens(response)
    let format_score = manager.format_checker.check(response_text)
    let accuracy_score = manager.accuracy_verifier.verify(response_text, ground_truth)
    let reasoning_score = manager.reasoning_scorer.score(response_text)
    let total_reward = (
        manager.config.format_weight * format_score +
        manager.config.accuracy_weight * accuracy_score +
        manager.config.reasoning_weight * reasoning_score
    )
    let weight_sum = manager.config.format_weight +
                     manager.config.accuracy_weight +
                     manager.config.reasoning_weight
    total_reward /= weight_sum
    let breakdown = {
        "format": format_score,
        "accuracy": accuracy_score,
        "reasoning": reasoning_score,
        "total": total_reward,
    }
    return total_reward, breakdown
}

struct prime_reward_manager_config {
    num_steps: i32
    step_reward_weight: f32
    final_reward_weight: f32
    use_step_verification: bool
}

struct prime_reward_manager {
    config: prime_reward_manager_config
    step_reward_model: *Model
    final_reward_model: *Model
}

func new_prime_reward_manager(
    config: prime_reward_manager_config,
    step_model: *Model,
    final_model: *Model
) -> prime_reward_manager {
    return prime_reward_manager{
        config: config,
        step_reward_model: step_model,
        final_reward_model: final_model,
    }
}

func (manager: *prime_reward_manager) compute_reward(
    prompt: tensor,
    response: tensor,
    steps: []string
) -> (f32, []f32) {
    let step_rewards: []f32 = []
    for step_text in steps {
        let step_tokens = encode_text(step_text)
        let step_input = concat(prompt, step_tokens)
        let step_reward = manager.step_reward_model.forward(step_input).item()
        step_rewards.push(step_reward)
    }
    let final_input = concat(prompt, response)
    let final_reward = manager.final_reward_model.forward(final_input).item()
    let avg_step_reward = compute_mean(step_rewards)
    let total_reward = (
        manager.config.step_reward_weight * avg_step_reward +
        manager.config.final_reward_weight * final_reward
    )
    return total_reward, step_rewards
}

func stack_and_pad(tensors: []tensor) -> tensor {
    let max_len = 0
    for t in tensors {
        if t.shape[0] > max_len {
            max_len = t.shape[0]
        }
    }
    let padded: []tensor = []
    for t in tensors {
        if t.shape[0] < max_len {
            let padding = tensor_zeros([max_len - t.shape[0]])
            padded.push(concat(t, padding))
        } else {
            padded.push(t)
        }
    }
    return stack(padded)
}

func generate_uuid() -> string {
    return f"{random_int(0, 999999)}-{get_time_ms()}"
}

func get_time_ms() -> i64 {
    return 0
}

func sleep_ms(duration: i64) {
}

func compute_mean(values: []f32) -> f32 {
    if values.len() == 0 {
        return 0.0
    }
    let sum: f32 = 0.0
    for v in values {
        sum += v
    }
    return sum / f32(values.len())
}

struct format_checker {}

struct answer_verifier { method: string }

struct reasoning_scorer {}

struct worker { id: i32 }

struct mutex {}

func new_format_checker() -> *format_checker { return null }

func new_answer_verifier(method: string) -> *answer_verifier { return null }

func new_reasoning_scorer() -> *reasoning_scorer { return null }

func new_worker(id: i32) -> worker { return worker{ id: id } }

func mutex_new() -> mutex { return mutex{} }

func (m: *mutex) lock() {}

func (m: *mutex) unlock() {}

func decode_tokens(t: tensor) -> string { return "" }

func encode_text(s: string) -> tensor { return tensor_zeros([1]) }
