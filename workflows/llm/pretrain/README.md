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
- `hidden_dim`
- `num_layers`
- `num_attention_heads`
- `num_kv_heads`
- `intermediate_dim`
- `vocab_size`

The runner compiles a temporary S entrypoint and passes those config values into the pretrain workflow state.
The current workflow entrypoint now drives `neurx.distributed.two_t_runtime`, which:

- loads real text data through the shared dataloader path
- writes rank-specific TP checkpoint shards
- restores optimizer, loader, and RNG metadata from the workflow checkpoint sidecar

The canonical model implementation is still shared from `model/llm/`, but the workflow launcher now targets the 2T runtime / checkpoint stack.

Presets:

- `config/sample.yaml`: small debug run
- `config/gpt55_reference.yaml`: reference-only modern GPT-style dense LLM preset, not an official GPT-5.5 spec
