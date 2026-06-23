# LLM Pretrain Workflow

This workflow wires together:

- config presets
- pipeline stages
- launch scripts
- dataset manifests

Launch:

- `workflows/llm/pretrain/run/launch.sh`
- or `workflows/llm/pretrain/run/run_with_config.sh --config workflows/llm/pretrain/config/sample.yaml`

Supported config keys:

- `dataset_manifest`
- `output_dir`
- `micro_batch_size`
- `seq_len`
- `max_steps`
- `lr`
- `min_lr`
- `warmup_steps`
- `weight_decay`
- `log_interval`
- `eval_interval`
- `save_interval`

The runner compiles a temporary S entrypoint and passes those config values into the pretrain workflow state.
The canonical model implementation should be called from `model/llm/`.
