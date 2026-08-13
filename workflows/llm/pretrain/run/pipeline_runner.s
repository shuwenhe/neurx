package neurx.workflows.llm.pretrain.run.pipeline_runner
use neurx.distributed.two_t_runtime.{two_t_runtime_state, new_two_t_runtime_state, two_t_runtime_load_checkpoint, two_t_runtime_train, two_t_runtime_summary, two_t_runtime_report}
use neurx.distributed.two_t_training.{two_t_training_plan, new_two_t_training_plan, two_t_training_plan_summary}
use neurx.model.model_2t_config.{model_2t_config, new_2t_model_config}
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file}
func workflow_two_t_config(int micro_batch, int seq_len, float lr, int steps, int warmup_steps, float min_lr, float weight_decay, int hidden_dim, int num_layers, int num_attention_heads, int num_kv_heads, int intermediate_dim, int vocab_size) model_2t_config {
    model_2t_config cfg = new_2t_model_config()
    cfg.hidden_dim = hidden_dim
    cfg.num_layers = num_layers
    cfg.num_attention_heads = num_attention_heads
    cfg.num_kv_heads = num_kv_heads
    cfg.intermediate_dim = intermediate_dim
    cfg.vocab_size = vocab_size
    cfg.max_seq_len = seq_len
    cfg
}
func workflow_two_t_plan(int micro_batch, int seq_len, int steps, int tp_degree, int pp_degree, int dp_degree, int sp_degree, int zero_stage) two_t_training_plan {
    int world_size = tp_degree * pp_degree * dp_degree
    if sp_degree > 1 {
        world_size = world_size * sp_degree
    }
    if world_size <= 0 {
        world_size = 1
    }
    two_t_training_plan plan = new_two_t_training_plan(world_size, 0)
    plan.batch_size = micro_batch
    plan.micro_batch_size = micro_batch
    plan.seq_len = seq_len
    plan.max_steps = steps
    plan.tensor_parallel_degree = tp_degree
    plan.pipeline_parallel_degree = pp_degree
    plan.data_parallel_degree = dp_degree
    plan.sequence_parallel_degree = sp_degree
    plan.zero_stage = zero_stage
    plan.activation_checkpointing = true
    plan.cpu_offload = false
    plan
}
func workflow_two_t_train_dir(string output_dir) string {
    if output_dir == "" {
        return "artifacts/checkpoints/two_t_pretrain"
    }
    output_dir
}
func run_pretrain_steps(int steps) int {
    run_pretrain_with_distributed_config(8, 16, 0.00015, steps, 128, 0.00003, 0.1, 8, 16, 32, "dataset/pretrain/manifest.json", "artifacts/checkpoints/two_t_pretrain", 4, 2, 1, 1, 2, 128, 4, 8, 2, 512, 4096)
}
func run_pretrain_with_params(int micro_batch, int seq_len, float lr, int steps, int log_interval, int eval_interval, int save_interval) int {
    run_pretrain_with_distributed_config(micro_batch, seq_len, lr, steps, 128, 0.00003, 0.1, log_interval, eval_interval, save_interval, "dataset/pretrain/manifest.json", "artifacts/checkpoints/two_t_pretrain", 4, 2, 1, 1, 2, 128, 4, 8, 2, 512, 4096)
}
func run_pretrain_with_config(int micro_batch, int seq_len, float lr, int steps, int warmup_steps, float min_lr, float weight_decay, int log_interval, int eval_interval, int save_interval, string dataset_manifest, string output_dir) int {
    run_pretrain_with_distributed_config(micro_batch, seq_len, lr, steps, warmup_steps, min_lr, weight_decay, log_interval, eval_interval, save_interval, dataset_manifest, output_dir, 4, 2, 1, 1, 2, 128, 4, 8, 2, 512, 4096)
}
func run_pretrain_with_distributed_config(int micro_batch, int seq_len, float lr, int steps, int warmup_steps, float min_lr, float weight_decay, int log_interval, int eval_interval, int save_interval, string dataset_manifest, string output_dir, int tp_degree, int pp_degree, int dp_degree, int sp_degree, int zero_stage, int hidden_dim, int num_layers, int num_attention_heads, int num_kv_heads, int intermediate_dim, int vocab_size) int {
    model_2t_config cfg = workflow_two_t_config(micro_batch, seq_len, lr, steps, warmup_steps, min_lr, weight_decay, hidden_dim, num_layers, num_attention_heads, num_kv_heads, intermediate_dim, vocab_size)
    two_t_training_plan plan = workflow_two_t_plan(micro_batch, seq_len, steps, tp_degree, pp_degree, dp_degree, sp_degree, zero_stage)
    string checkpoint_dir = workflow_two_t_train_dir(output_dir)
    runtime_make_dirs(checkpoint_dir)
    two_t_runtime_state state = new_two_t_runtime_state(cfg, plan, 0, plan.world_size, dataset_manifest, checkpoint_dir)
    state.checkpoint.save_every_steps = save_interval
    state.base_lr = lr
    state.min_lr = min_lr
    state.warmup_steps = warmup_steps
    state.cosine_decay_steps = steps
    state = two_t_runtime_load_checkpoint(state)
    state = two_t_runtime_train(state, steps)
    runtime_write_text_file(checkpoint_dir + "/workflow_summary.txt", two_t_training_plan_summary(plan) + "\n" + two_t_runtime_summary(state) + "\n" + two_t_runtime_report(state) + "\n")
    0
}
