package main
use neurx.pretrain.llm.real_main_training.{
    default_training_config,
    real_training_config,
    run_real_training_loop
}
func main() int {
    real_training_config config = default_training_config()
    run_real_training_loop(config)
    return 0
}
