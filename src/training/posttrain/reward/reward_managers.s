import "tensor/tensor.s"
import "src/training/posttrain/reward/reward_model.s"

struct batch_reward_manager_config {
    i32 batch_size
    i32 max_queue_size
    i64 timeout_ms
    i32 num_workers
    bool use_gpu
    i32 gpu_device
}

struct reward_request {
    string request_id
    tensor prompt
    tensor response
    callback: fn(f32)
}

struct batch_reward_manager {
    batch_reward_manager_config config
    *model reward_model
    request_queue: []reward_request
    mutex queue_mutex
    workers: []worker
    i64 total_requests
    i64 total_batches
    f32 avg_batch_size
}

func new_batch_reward_manager(batch_reward_manager_config config, *model model) . batch_reward_manager {
    workers := []
    for i in 0..config.num_workers {
        workers = append(workers, new_worker(i))
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

func (batch_reward_manager* manager) compute_reward_async(
    tensor prompt,
    tensor response,
    fn(f32) callback
) {
    request := reward_request{
        request_id: generate_uuid(),
        prompt: prompt,
        response: response,
        callback: callback,
    }
    manager.queue_mutex.lock()
    manager.request_queue = append(manager.request_queue, request)
    manager.total_requests += 1
    manager.queue_mutex.unlock()
    if len(manager.request_queue) >= manager.config.batch_size {
        manager.process_batch()
    }
}

func (batch_reward_manager* manager) process_batch() {
    manager.queue_mutex.lock()
    if len(manager.request_queue) == 0 {
        manager.queue_mutex.unlock()
        return
    }
    batch_size := min(manager.config.batch_size, len(manager.request_queue))
    batch_requests := manager.request_queue[..batch_size]
    manager.request_queue = manager.request_queue[batch_size..]
    manager.queue_mutex.unlock()
    prompts := []
    responses := []
    for req in batch_requests {
        prompts = append(prompts, req.prompt)
        responses = append(responses, req.response)
    }
    batched_prompts := stack_and_pad(prompts)
    batched_responses := stack_and_pad(responses)
    inputs := concat(batched_prompts, batched_responses, dim: 1)
    rewards := manager.reward_model.forward(inputs).squeeze(-1)
    for i, req in batch_requests {
        reward := rewards[i].item()
        req.callback(reward)
    }
    manager.total_batches += 1
    manager.avg_batch_size = (manager.avg_batch_size * f32(manager.total_batches - 1) +
                              f32(batch_size)) / f32(manager.total_batches)
}

func (batch_reward_manager* manager) flush() {
    for len(manager.request_queue) > 0 {
        manager.process_batch()
    }
}

struct rate_limited_reward_manager_config {
    f32 max_requests_per_second
    i32 burst_size
    bool use_token_bucket
}

struct rate_limited_reward_manager {
    rate_limited_reward_manager_config config
    *model reward_model
    f32 tokens
    i64 last_refill_time
    delayed_queue: []delayed_request
    i64 total_requests
    i64 rate_limited_count
}

struct delayed_request {
    reward_request request
    i64 scheduled_time
}

func new_rate_limited_reward_manager(
    rate_limited_reward_manager_config config,
    *model model
) . rate_limited_reward_manager {
    return rate_limited_reward_manager{
        config: config,
        reward_model: model,
        f32 tokens(config.burst_size),
        last_refill_time: get_time_ms(),
        delayed_queue: [],
        total_requests: 0,
        rate_limited_count: 0,
    }
}

func (rate_limited_reward_manager* manager) compute_reward(
    tensor prompt,
    tensor response
) . f32 {
    manager.total_requests += 1
    manager.refill_tokens()
    if manager.tokens >= 1.0 {
        manager.tokens -= 1.0
        return manager.compute_reward_internal(prompt, response)
    } else {
        manager.rate_limited_count += 1
        wait_time := 1000.0 / manager.config.max_requests_per_second
        sleep_ms(i64(wait_time))
        manager.refill_tokens()
        manager.tokens -= 1.0
        return manager.compute_reward_internal(prompt, response)
    }
}

func (rate_limited_reward_manager* manager) refill_tokens() {
    now := get_time_ms()
    elapsed := f32(now - manager.last_refill_time) / 1000.0
    tokens_to_add := elapsed * manager.config.max_requests_per_second
    manager.tokens = min(
        manager.tokens + tokens_to_add,
        f32(manager.config.burst_size)
    )
    manager.last_refill_time = now
}

func (rate_limited_reward_manager* manager) compute_reward_internal(
    tensor prompt,
    tensor response
) . f32 {
    input := concat(prompt, response)
    reward := manager.reward_model.forward(input)
    return reward.item()
}

struct dapo_reward_manager_config {
    f32 format_weight
    f32 accuracy_weight
    f32 reasoning_weight
    bool use_process_reward
    string verification_method
}

struct dapo_reward_manager {
    dapo_reward_manager_config config
    *format_checker format_checker
    *answer_verifier accuracy_verifier
    *reasoning_scorer reasoning_scorer
}

func new_dapo_reward_manager(dapo_reward_manager_config config) . dapo_reward_manager {
    return dapo_reward_manager{
        config: config,
        format_checker: new_format_checker(),
        accuracy_verifier: new_answer_verifier(config.verification_method),
        reasoning_scorer: new_reasoning_scorer(),
    }
}

func (dapo_reward_manager* manager) compute_reward(
    tensor prompt,
    tensor response,
    string ground_truth
) . (f32, map[string]f32) {
    response_text := decode_tokens(response)
    format_score := manager.format_checker.check(response_text)
    accuracy_score := manager.accuracy_verifier.verify(response_text, ground_truth)
    reasoning_score := manager.reasoning_scorer.score(response_text)
    total_reward := (
        manager.config.format_weight * format_score +
        manager.config.accuracy_weight * accuracy_score +
        manager.config.reasoning_weight * reasoning_score
    )
    weight_sum := manager.config.format_weight +
                     manager.config.accuracy_weight +
                     manager.config.reasoning_weight
    total_reward /= weight_sum
    breakdown := {
        "format": format_score,
        "accuracy": accuracy_score,
        "reasoning": reasoning_score,
        "total": total_reward,
    }
    return total_reward, breakdown
}

struct prime_reward_manager_config {
    i32 num_steps
    f32 step_reward_weight
    f32 final_reward_weight
    bool use_step_verification
}

struct prime_reward_manager {
    prime_reward_manager_config config
    *model step_reward_model
    *model final_reward_model
}

func new_prime_reward_manager(
    prime_reward_manager_config config,
    *model step_model,
    *model final_model
) . prime_reward_manager {
    return prime_reward_manager{
        config: config,
        step_reward_model: step_model,
        final_reward_model: final_model,
    }
}

func (prime_reward_manager* manager) compute_reward(
    tensor prompt,
    tensor response,
    string[] steps
) . (f32, []f32) {
    step_rewards := []
    for step_text in steps {
        step_tokens := encode_text(step_text)
        step_input := concat(prompt, step_tokens)
        step_reward := manager.step_reward_model.forward(step_input).item()
        step_rewards = append(step_rewards, step_reward)
    }
    final_input := concat(prompt, response)
    final_reward := manager.final_reward_model.forward(final_input).item()
    avg_step_reward := compute_mean(step_rewards)
    total_reward := (
        manager.config.step_reward_weight * avg_step_reward +
        manager.config.final_reward_weight * final_reward
    )
    return total_reward, step_rewards
}

func stack_and_pad([]tensor tensors) . tensor {
    max_len := 0
    for t in tensors {
        if t.shape[0] > max_len {
            max_len = t.shape[0]
        }
    }
    padded := []
    for t in tensors {
        if t.shape[0] < max_len {
            padding := tensor_zeros([max_len - t.shape[0]])
            padded = append(padded, concat(t, padding))
        } else {
            padded = append(padded, t)
        }
    }
    return stack(padded)
}

func generate_uuid() . string {
    return f"{random_int(0, 999999)}-{get_time_ms()}"
}

func get_time_ms() . i64 {
    return 0
}

func sleep_ms(i64 duration) {
}

func compute_mean([]f32 values) . f32 {
    if len(values) == 0 {
        return 0.0
    }
    sum := 0.0
    for v in values {
        sum += v
    }
    return sum / f32(len(values))
}

struct format_checker {}

struct answer_verifier { method: string }

struct reasoning_scorer {}

struct worker { id: i32 }

struct mutex {}

func new_format_checker() . *format_checker { return null }

func new_answer_verifier(string method) . *answer_verifier { return null }

func new_reasoning_scorer() . *reasoning_scorer { return null }

func new_worker(i32 id) . worker { return worker{ id id } }

func mutex_new() . mutex { return mutex{} }

func (mutex* m) lock() {}

func (mutex* m) unlock() {}

func decode_tokens(tensor t) . string { return "" }

func encode_text(string s) . tensor { return tensor_zeros([1]) }
