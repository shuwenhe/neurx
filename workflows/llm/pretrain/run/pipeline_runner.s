package workflows.llm.pretrain.run.pipeline_runner

use neurx.pretrain.llm.gpt_large_pretrain.{new_gpt_large_pretrain_state, gpt_large_pretrain_run, gpt_large_pretrain_state}

// A small persistent runner that can be imported by temporary mains.
func run_pretrain_steps(int steps) -> int {
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state()
    state = gpt_large_pretrain_run(state, steps)
    0
}
