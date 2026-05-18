package neurx.workflows.llm.pretrain.run.pipeline_runner

use neurx.pretrain.llm.gpt_large_pretrain.{new_gpt_large_pretrain_state, gpt_large_pretrain_run, gpt_large_pretrain_state, gpt_large_pretrain_documents}
use neurx.model.llm.gpt_large_train.{new_gpt_large_training_config, new_gpt_large_training_state, gpt_large_training_config, gpt_large_training_state}

// A small persistent runner that can be imported by temporary mains.
func run_pretrain_steps(int steps) int {
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state()
    state = gpt_large_pretrain_run(state, steps)
    0
}

// Run pretrain with explicit training params (micro_batch, seq_len, lr, steps).
func run_pretrain_with_params(int micro_batch, int seq_len, float lr, int steps) int {
    gpt_large_pretrain_state base = new_gpt_large_pretrain_state()
    []string docs = gpt_large_pretrain_documents()
    gpt_large_training_config tcfg = new_gpt_large_training_config(micro_batch, seq_len, steps, lr)
    gpt_large_training_state training = new_gpt_large_training_state(docs, tcfg)

    gpt_large_pretrain_state new_state = gpt_large_pretrain_state {
        cfg: base.cfg,
        data: base.data,
        loop: base.loop,
        checkpoint: base.checkpoint,
        eval: base.eval,
        training: training,
    }

    new_state = gpt_large_pretrain_run(new_state, steps)
    0
}
