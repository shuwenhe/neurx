package neurx.examples.production_training
use neurx.trainer.production.*
func example_single_gpu_training() {
    println("=== Example 1: Single GPU Training ===\n")
    training_system_config cfg = new_training_system_config()
    cfg.model_name = "neurx-small"
    cfg.vocab_size = 32000
    cfg.hidden_dim = 512
    cfg.num_layers = 6
    cfg.num_heads = 8
    cfg.ffn_dim = 2048
    cfg.max_seq_len = 512
    cfg.batch_size = 32
    cfg.gradient_accumulation_steps = 4
    cfg.max_steps = 1000
    cfg.learning_rate = 0.0003
    cfg.weight_decay = 0.01
    cfg.max_grad_norm = 1.0
    cfg.enable_ddp = false
    cfg.enable_zero = false
    cfg.enable_checkpointing = true
    cfg.checkpoint_dir = "./checkpoints/single_gpu"
    cfg.save_interval_steps = 100
    cfg.enable_logging = true
    cfg.log_interval_steps = 10
    training_loop(cfg)
}
func example_ddp_training() {
    println("=== Example 2: DDP Multi-GPU Training ===\n")
    training_system_config cfg = new_training_system_config()
    cfg.model_name = "neurx-medium"
    cfg.vocab_size = 32000
    cfg.hidden_dim = 1024
    cfg.num_layers = 12
    cfg.num_heads = 16
    cfg.ffn_dim = 4096
    cfg.max_seq_len = 1024
    cfg.batch_size = 16
    cfg.gradient_accumulation_steps = 8
    cfg.max_steps = 5000
    cfg.learning_rate = 0.0001
    cfg.weight_decay = 0.01
    cfg.max_grad_norm = 1.0
    cfg.enable_ddp = true
    cfg.world_size = 4
    cfg.rank = 0
    cfg.enable_zero = false
    cfg.enable_checkpointing = true
    cfg.checkpoint_dir = "./checkpoints/ddp"
    cfg.save_interval_steps = 500
    cfg.enable_logging = true
    cfg.log_interval_steps = 50
    training_loop(cfg)
}
func example_zero_stage1_training() {
    println("=== Example 3: ZeRO Stage 1 Training ===\n")
    training_system_config cfg = new_training_system_config()
    cfg.model_name = "neurx-large"
    cfg.vocab_size = 32000
    cfg.hidden_dim = 2048
    cfg.num_layers = 24
    cfg.num_heads = 32
    cfg.ffn_dim = 8192
    cfg.max_seq_len = 2048
    cfg.batch_size = 8
    cfg.gradient_accumulation_steps = 16
    cfg.max_steps = 10000
    cfg.learning_rate = 0.00008
    cfg.weight_decay = 0.01
    cfg.max_grad_norm = 1.0
    cfg.enable_ddp = true
    cfg.world_size = 8
    cfg.rank = 0
    cfg.enable_zero = true
    cfg.zero_stage = 1
    cfg.enable_checkpointing = true
    cfg.checkpoint_dir = "./checkpoints/zero1"
    cfg.save_interval_steps = 1000
    cfg.keep_last_n_checkpoints = 3
    cfg.enable_logging = true
    cfg.log_interval_steps = 100
    training_loop(cfg)
}
func example_zero_stage2_training() {
    println("=== Example 4: ZeRO Stage 2 Training ===\n")
    training_system_config cfg = new_training_system_config()
    cfg.model_name = "neurx-xlarge"
    cfg.vocab_size = 32000
    cfg.hidden_dim = 4096
    cfg.num_layers = 32
    cfg.num_heads = 64
    cfg.ffn_dim = 16384
    cfg.max_seq_len = 2048
    cfg.batch_size = 4
    cfg.gradient_accumulation_steps = 32
    cfg.max_steps = 20000
    cfg.learning_rate = 0.00006
    cfg.weight_decay = 0.01
    cfg.max_grad_norm = 1.0
    cfg.warmup_ratio = 0.1
    cfg.enable_ddp = true
    cfg.world_size = 16
    cfg.rank = 0
    cfg.enable_zero = true
    cfg.zero_stage = 2
    cfg.enable_checkpointing = true
    cfg.checkpoint_dir = "./checkpoints/zero2"
    cfg.save_interval_steps = 2000
    cfg.keep_last_n_checkpoints = 5
    cfg.enable_logging = true
    cfg.log_interval_steps = 100
    training_loop(cfg)
}
func example_resume_from_checkpoint() {
    println("=== Example 5: Resume from Checkpoint ===\n")
    training_system_config cfg = new_training_system_config()
    cfg.model_name = "neurx-medium"
    cfg.max_steps = 10000
    cfg.resume_from_checkpoint = true
    cfg.resume_checkpoint_path = "./checkpoints/zero1/checkpoint_step_5000.pt"
    cfg.enable_checkpointing = true
    cfg.checkpoint_dir = "./checkpoints/resumed"
    cfg.save_interval_steps = 500
    training_loop(cfg)
}
func example_with_full_logging() {
    println("=== Example 6: Training with Full Logging ===\n")
    training_system_config cfg = new_training_system_config()
    cfg.model_name = "neurx-debug"
    cfg.vocab_size = 10000
    cfg.hidden_dim = 256
    cfg.num_layers = 4
    cfg.num_heads = 4
    cfg.ffn_dim = 1024
    cfg.max_seq_len = 256
    cfg.batch_size = 64
    cfg.gradient_accumulation_steps = 1
    cfg.max_steps = 100
    cfg.learning_rate = 0.001
    cfg.enable_logging = true
    cfg.log_interval_steps = 1
    cfg.log_dir = "./logs/debug"
    cfg.enable_checkpointing = true
    cfg.checkpoint_dir = "./checkpoints/debug"
    cfg.save_interval_steps = 20
    training_loop(cfg)
}
func main() {
    println("\n" + "="*80)
    println("NeurX Production Training System - Examples")
    println("="*80 + "\n")
    int example_choice = 1
    if example_choice == 1 {
        example_single_gpu_training()
    } else if example_choice == 2 {
        example_ddp_training()
    } else if example_choice == 3 {
        example_zero_stage1_training()
    } else if example_choice == 4 {
        example_zero_stage2_training()
    } else if example_choice == 5 {
        example_resume_from_checkpoint()
    } else if example_choice == 6 {
        example_with_full_logging()
    }
    println("\n" + "="*80)
    println("Training Complete!")
    println("="*80 + "\n")
}
