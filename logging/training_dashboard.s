package neurx.logging

struct training_metrics {
    float current_loss
    []float recent_losses
    float avg_loss
    float samples_per_second
    float tokens_per_second
    float avg_step_time
    float current_lr
    float gpu_memory_used_gb
    float gpu_memory_total_gb
    float cpu_percent
    float memory_used_gb
    int global_step
    int steps_in_epoch
    int total_steps
    int epoch
    int total_epochs
    float validation_loss
    float accuracy
    float perplexity
    float best_validation_loss
    int best_step
}

func new_training_metrics() training_metrics {
    training_metrics {
        current_loss: 0.0,
        recent_losses: [],
        avg_loss: 0.0,
        samples_per_second: 0.0,
        tokens_per_second: 0.0,
        avg_step_time: 0.0,
        current_lr: 0.0,
        gpu_memory_used_gb: 0.0,
        gpu_memory_total_gb: 0.0,
        cpu_percent: 0.0,
        memory_used_gb: 0.0,
        global_step: 0,
        steps_in_epoch: 0,
        total_steps: 10000,
        epoch: 0,
        total_epochs: 10,
        validation_loss: 99999.9,
        accuracy: 0.0,
        perplexity: 99999.9,
        best_validation_loss: 99999.9,
        best_step: -1,
    }
}

