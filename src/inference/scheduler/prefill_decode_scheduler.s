package neurx.inference.prefill_decode_scheduler
use std.slices
    fcfs,
    priority,
    min_latency,
    max_throughput,
    balanced
}
    low,
    normal,
    high
}

struct request_metrics {
    int request_id
    int arrival_time_ms
    int tokens_prefilled
    int tokens_generated
    int total_tokens_needed
    request_priority priority
    float estimated_latency_ms
    bool is_preemptible
}

struct scheduler_config {
    scheduling_strategy strategy
    int max_prefill_batch_size
    int max_decode_batch_size
    int max_token_per_iteration
    bool enable_preemption
    float preemption_threshold
    bool enable_priority
}

struct scheduling_decision {
    int[] prefill_request_ids
    int[] decode_request_ids
    int[] preempt_request_ids
    int iteration_number
    int total_token_budget_used
}

struct scheduler_state {
    scheduler_config config
    []request_metrics pending_metrics
    []request_metrics running_metrics
    []request_metrics completed_metrics
    int current_iteration
    long total_tokens_processed
}

func new_scheduler_state(scheduler_config config) scheduler_state {
    scheduler_state {
        config: config,
        pending_metrics: request_metrics[](cap: 1024),
        running_metrics: request_metrics[](cap: config.max_decode_batch_size + config.max_prefill_batch_size),
        completed_metrics: request_metrics[](cap: 256),
        current_iteration: 0,
        total_tokens_processed: 0,
    }
}

func (scheduler_state* sched) add_request(request_metrics metrics) {
    sched.pending_metrics = append(sched.pending_metrics, metrics)
}

func min_latency_schedule(*scheduler_state sched) scheduling_decision {
    decision := scheduling_decision {
        prefill_request_ids: [](),
        decode_request_ids: [](),
        preempt_request_ids: [](),
        iteration_number: sched.current_iteration,
        total_token_budget_used: 0,
    }
    token_budget := sched.config.max_token_per_iteration
    for metrics in sched.running_metrics.iter() {
        if metrics.tokens_generated < metrics.total_tokens_needed {
            if len(decision.decode_request_ids) < sched.config.max_decode_batch_size {
                if token_budget >= 1 {
                    decision.decode_request_ids = append(decision.decode_request_ids, metrics.request_id)
                    token_budget -= 1
                    decision.total_token_budget_used += 1
                }
            }
        }
    }
    prefill_count := 0
    for metrics in sched.pending_metrics.iter() {
        if prefill_count >= sched.config.max_prefill_batch_size {
            break
        }
        prompt_len := metrics.total_tokens_needed
        if token_budget >= prompt_len {
            decision.prefill_request_ids = append(decision.prefill_request_ids, metrics.request_id)
            token_budget -= prompt_len
            decision.total_token_budget_used += prompt_len
            prefill_count += 1
        }
    }
    decision
}

func max_throughput_schedule(*scheduler_state sched) scheduling_decision {
    decision := scheduling_decision {
        prefill_request_ids: [](),
        decode_request_ids: [](),
        preempt_request_ids: [](),
        iteration_number: sched.current_iteration,
        total_token_budget_used: 0,
    }
    token_budget := sched.config.max_token_per_iteration
    prefill_count := 0
    for metrics in sched.pending_metrics.iter() {
        if prefill_count >= sched.config.max_prefill_batch_size {
            break
        }
        prompt_len := metrics.total_tokens_needed
        if token_budget >= prompt_len {
            decision.prefill_request_ids = append(decision.prefill_request_ids, metrics.request_id)
            token_budget -= prompt_len
            decision.total_token_budget_used += prompt_len
            prefill_count += 1
        }
    }
    for metrics in sched.running_metrics.iter() {
        if metrics.tokens_generated < metrics.total_tokens_needed {
            if len(decision.decode_request_ids) < sched.config.max_decode_batch_size {
                if token_budget >= 1 {
                    decision.decode_request_ids = append(decision.decode_request_ids, metrics.request_id)
                    token_budget -= 1
                    decision.total_token_budget_used += 1
                }
            }
        }
    }
    decision
}

func priority_schedule(*scheduler_state sched) scheduling_decision {
    decision := scheduling_decision {
        prefill_request_ids: [](),
        decode_request_ids: [](),
        preempt_request_ids: [](),
        iteration_number: sched.current_iteration,
        total_token_budget_used: 0,
    }
    token_budget := sched.config.max_token_per_iteration
    sorted_pending := sched.pending_metrics.clone()
    sorted_pending.sort_by(|a, b| {
        a_prio := priority_value(a.priority)
        b_prio := priority_value(b.priority)
        if a_prio != b_prio {
            return b_prio - a_prio
        }
        a.arrival_time_ms - b.arrival_time_ms
    })
    prefill_count := 0
    for metrics in sorted_pending.iter() {
        if prefill_count >= sched.config.max_prefill_batch_size {
            break
        }
        prompt_len := metrics.total_tokens_needed
        if token_budget >= prompt_len {
            decision.prefill_request_ids = append(decision.prefill_request_ids, metrics.request_id)
            token_budget -= prompt_len
            decision.total_token_budget_used += prompt_len
            prefill_count += 1
        }
    }
    sorted_running := sched.running_metrics.clone()
    sorted_running.sort_by(|a, b| {
        a_prio := priority_value(a.priority)
        b_prio := priority_value(b.priority)
        if a_prio != b_prio {
            return b_prio - a_prio
        }
        a.arrival_time_ms - b.arrival_time_ms
    })
    for metrics in sorted_running.iter() {
        if metrics.tokens_generated < metrics.total_tokens_needed {
            if len(decision.decode_request_ids) < sched.config.max_decode_batch_size {
                if token_budget >= 1 {
                    decision.decode_request_ids = append(decision.decode_request_ids, metrics.request_id)
                    token_budget -= 1
                    decision.total_token_budget_used += 1
                }
            }
        }
    }
    decision
}

func balanced_schedule(*scheduler_state sched) scheduling_decision {
    decision := scheduling_decision {
        prefill_request_ids: [](),
        decode_request_ids: [](),
        preempt_request_ids: [](),
        iteration_number: sched.current_iteration,
        total_token_budget_used: 0,
    }
    total_budget := sched.config.max_token_per_iteration
    prefill_budget := (total_budget * 50) / 100
    decode_budget := total_budget - prefill_budget
    prefill_used := 0
    decode_used := 0
    prefill_count := 0
    for metrics in sched.pending_metrics.iter() {
        if prefill_count >= sched.config.max_prefill_batch_size {
            break
        }
        prompt_len := metrics.total_tokens_needed
        if prefill_used + prompt_len <= prefill_budget {
            decision.prefill_request_ids = append(decision.prefill_request_ids, metrics.request_id)
            prefill_used += prompt_len
            prefill_count += 1
        }
    }
    for metrics in sched.running_metrics.iter() {
        if metrics.tokens_generated < metrics.total_tokens_needed {
            if len(decision.decode_request_ids) < sched.config.max_decode_batch_size {
                if decode_used < decode_budget {
                    decision.decode_request_ids = append(decision.decode_request_ids, metrics.request_id)
                    decode_used += 1
                }
            }
        }
    }
    decision.total_token_budget_used = prefill_used + decode_used
    decision
}

func check_and_apply_preemption(
    sched: *scheduler_state,
    *scheduling_decision decision
) {
    if !sched.config.enable_preemption {
        return
    }
    high_priority_waiting := sched.pending_metrics.iter().any(|m| m.priority == request_priority.high)
    if high_priority_waiting && len(decision.decode_request_ids) > 0 {
        min_idx := 0
        min_priority := 999
        for i in len(0..decision.decode_request_ids) {
            req_id := decision.decode_request_ids[i]
            metrics_opt := sched.running_metrics.iter().find(|m| m.request_id == req_id)
            match metrics_opt {
                Some(metrics) => {
                    prio := priority_value(metrics.priority)
                    if prio < min_priority {
                        min_priority = prio
                        min_idx = i
                    }
                }
                None => {}
            }
        }
        if min_priority < 2 {
            preempted_id := decision.decode_request_ids[min_idx]
            decision.preempt_request_ids = append(decision.preempt_request_ids, preempted_id)
            decision.decode_request_ids.remove(min_idx)
        }
    }
}

func (scheduler_state* sched) make_decision() scheduling_decision {
    decision := match sched.config.strategy {
        scheduling_strategy.min_latency => min_latency_schedule(sched),
        scheduling_strategy.max_throughput => max_throughput_schedule(sched),
        scheduling_strategy.priority => priority_schedule(sched),
        scheduling_strategy.balanced => balanced_schedule(sched),
        _ => min_latency_schedule(sched),
    }
    check_and_apply_preemption(sched, *decision)
    sched.current_iteration += 1
    decision
}

func priority_value(request_priority prio) int {
    match prio {
        request_priority.low => 0,
        request_priority.normal => 1,
        request_priority.high => 2,
    }
}

struct scheduler_stats {
    int total_iterations
    int total_prefilled
    int total_decoded
    float avg_prefill_batch_size
    float avg_decode_batch_size
    float total_throughput
}

func (scheduler_state* sched) get_stats() scheduler_stats {
    total_requests := len(sched.completed_metrics)
    scheduler_stats {
        total_iterations: sched.current_iteration,
        total_prefilled: sched.completed_metrics.iter().map(|m| m.tokens_prefilled).sum(),
        total_decoded: sched.completed_metrics.iter().map(|m| m.tokens_generated).sum(),
        avg_prefill_batch_size: 0.0,
        avg_decode_batch_size: 0.0,
        total_throughput: 0.0,
    }
}

func main() {
    println("🎯 Prefill/Decode high级调度策略")
    println("================================")
    config := scheduler_config {
        strategy: scheduling_strategy.balanced,
        max_prefill_batch_size: 8,
        max_decode_batch_size: 32,
        max_token_per_iteration: 2048,
        enable_preemption: true,
        preemption_threshold: 0.8,
        enable_priority: true,
    }
    sched := new_scheduler_state(config)
    for i in 0..6 {
        metrics := request_metrics {
            request_id: i,
            arrival_time_ms: (i as i32) * 100,
            tokens_prefilled: 0,
            tokens_generated: 0,
            total_tokens_needed: 32,
            priority: if i % 3 == 0 { request_priority.high } else { request_priority.normal },
            estimated_latency_ms: 0.0,
            is_preemptible: true,
        }
        sched.add_request(metrics)
    }
    for iter in 0..3 {
        decision := sched.make_decision()
        println(f"Iteration {iter + 1}:")
        println(f"  Prefill: {len(decision.prefill_request_ids)} requests")
        println(f"  Decode: {len(decision.decode_request_ids)} requests")
        println(f"  Token Budget Used: {decision.total_token_budget_used}")
        println("")
    }
    println("✅ 调度策略alreadythen绪")
}
