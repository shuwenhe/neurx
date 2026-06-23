package neurx.workflows.llm.pretrain.run.pipeline_runner

use neurx.pretrain.llm.gpt_large_pretrain.{new_gpt_large_pretrain_state, new_gpt_large_pretrain_state_with_params, new_gpt_large_pretrain_state_with_params_and_output, gpt_large_pretrain_run, gpt_large_pretrain_run_and_save, gpt_large_pretrain_state}

// A small persistent runner that can be imported by temporary mains.
func run_pretrain_steps(int steps) int {
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state()
    state = gpt_large_pretrain_run_and_save(state, steps)
    0
}

// Run pretrain with explicit workflow params.
func run_pretrain_with_params(int micro_batch, int seq_len, float lr, int steps, int log_interval, int eval_interval, int save_interval) int {
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state_with_params(micro_batch, seq_len, steps, lr, log_interval, eval_interval, save_interval)
    state = gpt_large_pretrain_run_and_save(state, steps)
    0
}

// Run pretrain with explicit workflow config fields.
func run_pretrain_with_config(int micro_batch, int seq_len, float lr, int steps, int warmup_steps, float min_lr, float weight_decay, int log_interval, int eval_interval, int save_interval, string dataset_manifest, string output_dir) int {
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state_with_params_and_output(micro_batch, seq_len, steps, lr, warmup_steps, min_lr, weight_decay, log_interval, eval_interval, save_interval, dataset_manifest, output_dir)
    state = gpt_large_pretrain_run_and_save(state, steps)
    0
}
