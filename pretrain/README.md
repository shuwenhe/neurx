# neurx pretrain

This directory hosts pretraining-specific orchestration in S modules.

- config: pretraining configuration state
- data: dataset and batch cursor state for pretraining
- loop: pretraining step and epoch state machine
- checkpoint: pretraining checkpoint scheduling state
- eval: lightweight pretraining evaluation state

Core tensor, autograd, ops, and runtime logic should remain in framework core modules.

## LLM Pretraining

- `llm/gpt_large_pretrain.s`: GPT-large pretraining orchestration built on the shared pretrain state machine
