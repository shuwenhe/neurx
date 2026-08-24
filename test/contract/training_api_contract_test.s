package main
use neurx.training.api.contracts.{training_job_config, training_validation_result, validate_training_job}

func main() {
    training_job_config config = training_job_config {
        job_id: "contract-training-1",
        mode: "pretrain",
        model: "fixture-model",
        backend: "cpu",
        dataset: "fixture-dataset",
        world_size: 1,
        max_steps: 10,
        checkpoint_interval: 5,
    }
    training_validation_result result = validate_training_job(config)
    if !result.valid {
        println("FAIL training API contract: " + result.error_code)
        return 1
    }
    config.world_size = 0
    result = validate_training_job(config)
    if result.valid || result.error_code != "invalid_capacity" {
        println("FAIL training API rejected-invalid contract")
        return 1
    }
    println("PASS training API contract")
    0
}
