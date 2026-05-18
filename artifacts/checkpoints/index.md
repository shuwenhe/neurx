# Checkpoint Index

Current NeurX checkpoint snapshots stored under `artifacts/checkpoints/`.

## Run snapshots

- `run_20260518_001/step_0001000/latest/gpt_large_pretrain.neurx`
- `run_20260518_001/step_0002000/latest/gpt_large_pretrain.neurx`
- `run_20260518_001/step_0003000/latest/gpt_large_pretrain.neurx`

## Model-family snapshots

- `llama3_8b/llama3_8b_base.neurx`
- `qwen3/qwen3_base.neurx`

## Storage convention

- `run_*/` groups a training run.
- `step_*/` groups a saved step within a run.
- `latest/` is the mutable alias for the most recent snapshot.
- Family namespaces like `llama3_8b/` and `qwen3/` are for reusable long-lived checkpoints.
