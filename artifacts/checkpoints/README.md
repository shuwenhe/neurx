# artifacts/checkpoints

Canonical runtime checkpoint root for trained NeurX models.

Use this directory for serialized checkpoints produced by `neurx.checkpoint.save_checkpoint(...)`.

Recommended layout:

```text
artifacts/checkpoints/
    run_20260518_001/
        step_0001000/
            latest/
        step_0002000/
            latest/
```

Notes:

- `run_YYYYMMDD_NNN/` groups one training run.
- `step_0001000/` groups a specific saved step snapshot.
- `latest/` is the mutable alias for the newest checkpoint in that run.
- The serialized checkpoint payload is written as a `.neurx` file inside these namespaces.

Example artifact path:

- `artifacts/checkpoints/run_20260518_001/step_0001000/latest/gpt_large_pretrain.neurx`

See also:

- [artifacts/checkpoints/index.md](/home/shuwen/shuwen/neurx/artifacts/checkpoints/index.md)
