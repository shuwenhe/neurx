package neurx.posttrain.sft.examples
use neurx.posttrain.sft.sft_trainer
use neurx.model.llm.neurx
use neurx.tokenizer.neurx
use std.io.println
func create_sft_example_config() sft_train_config {
    sft_train_config {
        method: "sft",
        batch_size: 8,
        gradient_accum_steps: 1,
        learning_rate: 2e-5,
        lr_warmup_ratio: 0.05,
        lr_schedule_type: "cosine",
        total_training_steps: 100,
        num_epochs: 2,
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        weight_decay: 0.01,
        max_grad_norm: 1.0,
        max_seq_len: 1024,
        padding_side: "right",
        pad_to_multiple_of_8: true,
        instruction_format: "alpaca",
        include_input_in_output: false,
        precision: "bf16",
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        save_interval: 25,
        eval_interval: 10,
        log_interval: 5,
        checkpoint_dir: "./checkpoints/sft/",
        num_workers: 2,
        pin_memory: true,
        eval_split_ratio: 0.1,
        output_dir: "./outputs/sft/",
    }
}
func create_sft_example_dataset() sft_dataset {
    create_sft_dataset("./data/sft/instruction_data.jsonl")
}
func create_sft_example_trainer(
    neurx_model model,
    tokenizer_state tokenizer,
    sft_train_config config,
    sft_dataset dataset,
    int global_rank,
    int world_size
) sft_trainer_state {
    neurx.posttrain.sft.sft_trainer.create_sft_trainer(model, tokenizer, config, dataset, global_rank, world_size)
}
func example_basic_sft_training() {
    neurx_model model = load_pretrained_sft_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_sft()
    sft_train_config config = create_sft_example_config()
    sft_dataset dataset = create_sft_example_dataset()
    sft_trainer_state trainer = create_sft_example_trainer(model, tokenizer, config, dataset, 0, 1)
    sft_train_result result = start_sft_training(trainer)
    println("SFT completed: " + fmt_float(result.final_loss, 4))
}
func main() {
    println("NEURX SFT examples")
    example_basic_sft_training()
}
func load_pretrained_sft_model(string model_name) neurx_model {
    neurx_model{}
}
func load_tokenizer_sft() tokenizer_state {
    tokenizer_state{}
}
