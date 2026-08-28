package neurx.training.api.contracts
struct training_job_config {
    string job_id
    string mode
    string model
    string backend
    string dataset
    int world_size
    int max_steps
    int checkpoint_interval
}
struct training_validation_result {
    bool valid
    string error_code
    string error_message
}
func valid_training_job() training_validation_result {
    training_validation_result { valid: true, error_code: "", error_message: "" }
}
func invalid_training_job(string code, string message) training_validation_result {
    training_validation_result { valid: false, error_code: code, error_message: message }
}
func validate_training_job(training_job_config config) training_validation_result {
    if config.job_id == "" {
        return invalid_training_job("missing_job_id", "job_id is required")
    }
    if config.mode != "pretrain" && config.mode != "posttrain" {
        return invalid_training_job("invalid_mode", "mode must be pretrain or posttrain")
    }
    if config.model == "" || config.dataset == "" {
        return invalid_training_job("missing_input", "model and dataset are required")
    }
    if config.backend != "cpu" && config.backend != "cuda" && config.backend != "cann" {
        return invalid_training_job("invalid_backend", "backend must be cpu, cuda, or cann")
    }
    if config.world_size <= 0 || config.max_steps <= 0 {
        return invalid_training_job("invalid_capacity", "world_size and max_steps must be positive")
    }
    if config.checkpoint_interval <= 0 || config.checkpoint_interval > config.max_steps {
        return invalid_training_job("invalid_checkpoint_interval", "checkpoint interval is outside the job range")
    }
    valid_training_job()
}
