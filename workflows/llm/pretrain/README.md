LLM pretraining workflows.

Structure:
- config/: run manifests and hyperparameters
- pipeline/: pipeline definitions (stages and IO contracts)
- run/: launch scripts that call the runtime API
- dataset/: dataset manifests and tokenizer helpers

Design: Workflows should call into `runtime/` and `train/` primitives rather than directly invoking kernels.