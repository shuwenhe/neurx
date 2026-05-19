# neurx pretrain

This directory hosts pretraining-specific orchestration in S modules.

- config: pretraining configuration state
- data: dataset and batch cursor state for pretraining
- loop: pretraining step and epoch state machine
- checkpoint: pretraining checkpoint scheduling state
- eval: lightweight pretraining evaluation state

Checkpoint scheduling state lives here; persistence and serialization should stay in the shared checkpoint/runtime layers.

Checkpoint artifacts are written under:

- `artifacts/checkpoints/`
- example file: `artifacts/checkpoints/run_20260518_001/step_0001000/latest/gpt_large_pretrain.neurx`

Core tensor, autograd, ops, and runtime logic should remain in framework core modules.

## LLM Pretraining

- `llm/gpt_large_pretrain.s`: GPT-large pretraining orchestration built on the shared pretrain state machine
