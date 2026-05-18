# artifacts/checkpoints

Canonical runtime checkpoint root for trained NeurX models.

Use this directory for serialized checkpoints produced by `neurx.checkpoint.save_checkpoint(...)`.

Recommended layout:

- `artifacts/checkpoints/latest.ckpt`
- `artifacts/checkpoints/pretrain/`
- `artifacts/checkpoints/posttrain/`
- `artifacts/checkpoints/llm/`
- `artifacts/checkpoints/vision/`
- `artifacts/checkpoints/diffusion/`
- `artifacts/checkpoints/robotics/`
