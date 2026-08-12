package neurx.experimental.dynamic_scheduling
use neurx.tensor
struct dynamic_scheduler_config {
    int min_rollout_workers
    int max_rollout_workers
    int min_training_workers
    int max_training_workers
    float target_buffer_utilization
    float scale_up_threshold
    float scale_down_threshold
    int adjustment_interval_steps
}


struct dynamic_scheduler_state {
    dynamic_scheduler_config config
    int current_rollout_workers
    int current_training_workers
    int total_steps
    []float buffer_utilization_history
    []float throughput_history
}


struct resource_allocation {
    int num_rollout_workers
    int num_training_workers
    float estimated_throughput
    string reason
}


func default_dynamic_scheduler_config() dynamic_scheduler_config {
    dynamic_scheduler_config {
        min_rollout_workers: 1,
        max_rollout_workers: 16,
        min_training_workers: 1,
        max_training_workers: 8,
        target_buffer_utilization: 0.7,
        scale_up_threshold: 0.9,
        scale_down_threshold: 0.3,
        adjustment_interval_steps: 100,
    }
}


func init_dynamic_scheduler(dynamic_scheduler_config config) dynamic_scheduler_state {
    dynamic_scheduler_state {
        config: config,
        current_rollout_workers: config.min_rollout_workers,
        current_training_workers: config.min_training_workers,
        total_steps: 0,
        buffer_utilization_history: make([]float, 0),
        throughput_history: make([]float, 0),
    }
}


func compute_resource_allocation(
    dynamic_scheduler_state state,
    float current_buffer_utilization,
    float current_throughput
) resource_allocation {
    state.buffer_utilization_history = append(state.buffer_utilization_history, current_buffer_utilization)
    state.throughput_history = append(state.throughput_history, current_throughput)
    int new_rollout_workers = state.current_rollout_workers
    int new_training_workers = state.current_training_workers
    string reason = "no_change"
    if current_buffer_utilization > state.config.scale_up_threshold {
        if new_training_workers < state.config.max_training_workers {
            new_training_workers = new_training_workers + 1
            reason = "buffer_high_scale_up_training"
        } else if new_rollout_workers > state.config.min_rollout_workers {
            new_rollout_workers = new_rollout_workers - 1
            reason = "buffer_high_scale_down_rollout"
        }
    } else if current_buffer_utilization < state.config.scale_down_threshold {
        if new_rollout_workers < state.config.max_rollout_workers {
            new_rollout_workers = new_rollout_workers + 1
            reason = "buffer_low_scale_up_rollout"
        } else if new_training_workers > state.config.min_training_workers {
            new_training_workers = new_training_workers - 1
            reason = "buffer_low_scale_down_training"
        }
    }
    state.current_rollout_workers = new_rollout_workers
    state.current_training_workers = new_training_workers
    state.total_steps = state.total_steps + 1
    float estimated_throughput = estimate_throughput(new_rollout_workers, new_training_workers)
    resource_allocation {
        num_rollout_workers: new_rollout_workers,
        num_training_workers: new_training_workers,
        estimated_throughput: estimated_throughput,
        reason: reason,
    }
}


func estimate_throughput(int rollout_workers, int training_workers) float {
    float rollout_rate = float(rollout_workers) * 100.0
    float training_rate = float(training_workers) * 50.0
    if rollout_rate < training_rate {
        return rollout_rate
    }
    return training_rate
}


func get_scheduler_stats(dynamic_scheduler_state state) scheduler_stats {
    float avg_buffer_util = 0.0
    if len(state.buffer_utilization_history) > 0 {
        for int i = 0; i < len(state.buffer_utilization_history); i = i + 1 {
            avg_buffer_util = avg_buffer_util + state.buffer_utilization_history[i]
        }
        avg_buffer_util = avg_buffer_util / float(len(state.buffer_utilization_history))
    }
    scheduler_stats {
        current_rollout_workers: state.current_rollout_workers,
        current_training_workers: state.current_training_workers,
        total_steps: state.total_steps,
        avg_buffer_utilization: avg_buffer_util,
    }
}


struct scheduler_stats {
    int current_rollout_workers
    int current_training_workers
    int total_steps
    float avg_buffer_utilization
}

